class_name SimBridge
extends Node

## Único dono do `SimWorld` dentro da árvore de cena. É ele que transforma
## tempo real em tick de sim e evento de sim em sinal Godot.
##
## Não decide nada de jogo: quem monta o mundo é a `SimFactory`, quem valida a
## ação é a sim, e o que aparece na tela é problema de quem escuta o sinal.
## Aqui só moram três coisas de apresentação: o relógio de parede, a velocidade
## com que ele anda e os dois rastros de debug.
##
## Nós filhos recebem a bridge por injeção — no `_ready` ela chama `setup(self)`
## em todo filho que tiver o método. Não existe autoload: quem não é filho da
## bridge não fala com a sim.
##
## 1 min de jogo = 0.75s reais (GAMEPLAY §3).
##
## Enquanto o jogo visual não existe, ela também sobe o playground de dev — veja
## `_monta_playground`.

## Todo evento que a sim emitiu, na ordem em que aconteceu — de `advance` e de
## `dispatch` pelo mesmo cano.
signal sim_event(event: SimEvent)

## A velocidade do relógio mudou. O HUD e o dev tools mostram qual é.
signal time_scale_changed(de: float, para: float)

## Segundos reais por minuto de jogo (GAMEPLAY §3). Dia útil 06:00→02:00 = 15
## minutos reais.
const SEGUNDOS_POR_MINUTO: float = 0.75

## As velocidades que o dev tools oferece: normal, rápida e "passa a estação".
const ESCALAS: Array[float] = [1.0, 10.0, 60.0]

## Teto de minutos por frame. Janela minimizada, breakpoint ou disco lento
## deixam o acumulador estourar; sem teto, o frame seguinte tentaria simular
## horas de uma vez e travaria o jogo. O tempo perdido fica perdido — o relógio
## do jogo não é o relógio de parede.
const MAX_MINUTOS_POR_FRAME: int = 240

## A janela da fazenda de botões. Constante para o `ResourceLoader.exists` e o
## `load` falarem do mesmo arquivo.
const PLAYGROUND_CENA: String = "res://game/dev/playground_window.tscn"

## Relógio parado começa parado? Não: o jogo abre andando. O dev tools é quem
## pausa.
@export var auto_tick: bool = true

var _factory: SimFactory
var _world: SimWorld
var _recorder: ActionRecorder
var _logger: EventLogger
var _time_scale: float = 1.0
var _acumulado: float = 0.0

func _ready() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	# os dois rastros compartilham o relógio da sim: toda linha sai carimbada
	# com a hora de jogo, não com a hora de parede
	_recorder = ActionRecorder.new(_factory.get_time_state())
	_logger = EventLogger.new(_factory.get_time_state())
	var debug := OS.is_debug_build()
	_recorder.set_enabled(debug)
	_logger.set_enabled(debug)
	_monta_playground()
	_injeta_nos_filhos()

func _exit_tree() -> void:
	if _logger != null:
		_logger.close()

## Acumula tempo de parede e converte em minutos de jogo. O `advance` roda uma
## vez por frame com o total de minutos, nunca um por minuto: a sim já sabe
## repetir o tick, e um laço de sinais por minuto entupiria a árvore em ×60.
func _process(delta: float) -> void:
	if not auto_tick or _time_scale <= 0.0 or _world == null:
		return
	_acumulado += delta * _time_scale
	var minutos := int(_acumulado / SEGUNDOS_POR_MINUTO)
	if minutos <= 0:
		return
	_acumulado -= minutos * SEGUNDOS_POR_MINUTO
	if minutos > MAX_MINUTOS_POR_FRAME:
		minutos = MAX_MINUTOS_POR_FRAME
		_acumulado = 0.0
	_emite(_world.advance(minutos))

# --- O que game/ usa ---

## Manda uma intenção para a sim e devolve o que ela respondeu. A resposta chega
## no mesmo frame — quem preferir escutar o sinal também recebe.
##
## Ação rejeitada não é erro: volta um `ActionRejectedEvent` como qualquer outro
## fato. Nenhum `if` de regra acontece deste lado.
func dispatch(action: SimAction) -> Array[SimEvent]:
	if action == null or _world == null:
		return []
	_recorder.record(action)
	var events := _world.handle(action)
	_emite(events)
	return events

## Avança minutos de jogo à força, sem esperar o relógio de parede. É o botão
## "adiantar" do dev tools.
func advance(minutos: int) -> Array[SimEvent]:
	if minutos <= 0 or _world == null:
		return []
	var events := _world.advance(minutos)
	_emite(events)
	return events

func get_world() -> SimWorld:
	return _world

## A fábrica fica acessível pelos catálogos: `game/` monta o botão de plantar
## lendo a definição, que é leitura livre. State alheio continua proibido.
func get_factory() -> SimFactory:
	return _factory

func get_item_catalog() -> ItemCatalog:
	return _factory.get_item_catalog()

func get_crop_catalog() -> CropCatalog:
	return _factory.get_crop_catalog()

func get_action_recorder() -> ActionRecorder:
	return _recorder

func get_event_logger() -> EventLogger:
	return _logger

# --- Velocidade do relógio ---

func get_time_scale() -> float:
	return _time_scale

## Escala nova zera o acumulador: o minuto pela metade não vale ×60 de repente.
func set_time_scale(escala: float) -> void:
	var nova: float = maxf(escala, 0.0)
	if is_equal_approx(nova, _time_scale):
		return
	var de := _time_scale
	_time_scale = nova
	_acumulado = 0.0
	time_scale_changed.emit(de, nova)

## Próxima velocidade da lista, voltando ao começo no fim — o botão único do
## dev tools.
func cycle_time_scale() -> float:
	var indice := ESCALAS.find(_time_scale)
	set_time_scale(ESCALAS[(indice + 1) % ESCALAS.size()])
	return _time_scale

# --- Playground de dev ---

## Sobe a janela da fazenda de botões como filha da bridge, para que a injeção
## do `_injeta_nos_filhos` a alcance como qualquer outro nó. O playground em si
## mora dentro dessa `Window` e recebe o fio dela — quem explica o repasse é
## `game/dev/playground_window.gd`.
##
## Só em build de debug: `game/dev/` é ferramenta de time e não entra no jogo
## final. O `ResourceLoader.exists` é o cinto de segurança do export — pasta
## fora do pacote não pode impedir o jogo de abrir.
##
## Por que aqui e não dentro de `main.tscn`: cena não tem `if`, e a condição é
## justamente o ponto. Instanciar UI de debug não é regra de jogo — nenhum
## número de jogo é decidido aqui, só o que aparece na tela, que é exatamente o
## trabalho de `game/`.
##
## Entra como último filho de propósito: quando a injeção chegar nela, o
## `SaveGateway` já leu o disco, então os painéis nascem mostrando a partida
## carregada em vez do mundo cru da fábrica.
##
## Na wave visual esta chamada sai daqui e o lugar dela passa a ser a cena de
## verdade do jogo (mapa, jogador, HUD); o playground vira atalho de debug.
func _monta_playground() -> void:
	if not OS.is_debug_build():
		return
	if not ResourceLoader.exists(PLAYGROUND_CENA):
		return
	var cena: PackedScene = load(PLAYGROUND_CENA) as PackedScene
	if cena == null:
		return
	add_child(cena.instantiate())

# --- Injeção ---

## Todo filho que souber receber a bridge recebe. Quem não tem `setup` é nó de
## enfeite e não fala com a sim.
func _injeta_nos_filhos() -> void:
	for filho in get_children():
		if filho.has_method("setup"):
			filho.call("setup", self)

## Um cano só para a saída da sim: loga e reemite, na ordem em que os eventos
## aconteceram. Falha de log nunca derruba o jogo.
func _emite(events: Array[SimEvent]) -> void:
	for event in events:
		_logger.log(event)
		sim_event.emit(event)
