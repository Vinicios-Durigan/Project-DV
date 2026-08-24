class_name MedidorEstamina
extends HBoxContainer

## Quanto corpo ainda resta hoje, na barra de status — ao lado do relógio e do
## dinheiro, sempre visível.
##
## ## Por que aqui em cima, e não numa aba
##
## Estamina que só aparece dentro do Tab não pressiona ninguém. A decisão que a
## mecânica existe para criar — "rego mais um canteiro ou volto para a cama?" —
## é tomada no meio do canteiro, e é lá que o número precisa estar no canto do
## olho. Os outros dois limitadores do dia (o relógio e o dinheiro) já moram
## nesta faixa; o terceiro senta ao lado deles.
##
## ## A tela não faz a conta
##
## Os dois números saem do `snapshot()`, a mesma foto que o save grava, e são
## lidos **na hora** — este nó não guarda cópia de estamina nenhuma. Quem
## desconta é o `SistemaCorpo`; se a barra e a sim discordarem, quem errou é
## este arquivo.
##
## ## A cor é decisão de tela
##
## Onde a barra fica dourada e onde ela fica vermelha é escolha de apresentação:
## a sim não tem opinião sobre "perto do fim". O que é pergunta de regra —
## **quantas ações ainda cabem** — quem responde é o sistema, e isso aparece na
## aba Corpo, não aqui. Aqui a cor é o susto; lá está a conta.

## Os três estados da barra. São ids, e não cores: a cor sai da paleta, e é o
## `nivel` que os testes leem.
const INTEIRO: String = "inteiro"
const ATENCAO: String = "atencao"
const BEIRA: String = "beira"

## Onde a cor troca. Chute de tela, calibrável junto com o teto de estamina: com
## metade do corpo ainda dá para um ciclo inteiro de canteiro; com um quinto, o
## próximo golpe caro derruba.
const LIMITE_ATENCAO: float = 0.5
const LIMITE_BEIRA: float = 0.2

## O tamanho da barra na faixa, em pixels (múltiplos de 4).
const LARGURA: float = 96.0
const ALTURA: float = 12.0


## A barra desenhada: trilho e preenchimento, dois `draw_rect` e nada mais.
##
## Desenhada à mão em vez de `ProgressBar` porque a cor é o recado principal, e
## pintar o preenchimento de um `ProgressBar` exigiria `add_theme_color_override`
## — que é pintar na mão com outro nome (`playground.gd`).
class Barra extends Control:
	var fracao: float = 1.0
	var cor: Color = Paleta.VERDE

	func mostra(nova_fracao: float, nova_cor: Color) -> void:
		fracao = nova_fracao
		cor = nova_cor
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Paleta.PAINEL_3)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fracao, size.y)), cor)
		draw_rect(Rect2(Vector2.ZERO, size), Paleta.CONTORNO, false, 1.0)


var _bridge: SimBridge
var _barra: Barra
var _numero: Label


func _ready() -> void:
	add_theme_constant_override("separation", Paleta.ESPACO_ITEM)

	var titulo := Label.new()
	titulo.text = "CORPO"
	titulo.theme_type_variation = &"Micro"
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(titulo)

	_barra = Barra.new()
	_barra.custom_minimum_size = Vector2(LARGURA, ALTURA)
	_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_barra)

	_numero = Label.new()
	_numero.theme_type_variation = &"Dado"
	add_child(_numero)

## Padrão 3: recebe o fio e escuta. Quem entrega é a casca do playground, que
## monta esta faixa — o medidor nasce dentro do `_monta_barra`.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza()


# --- Leitura: tudo sai do snapshot, na hora ---

func estamina() -> int:
	return int(_jogador().get("estamina", EstadoCorpo.ESTAMINA_PADRAO))

func maxima() -> int:
	return int(_jogador().get("maxima", EstadoCorpo.ESTAMINA_PADRAO))

## Quanto do corpo resta, de 0 a 1. Corpo sem teto não divide por zero.
func fracao() -> float:
	var teto := maxima()
	if teto <= 0:
		return 0.0
	return clampf(float(estamina()) / float(teto), 0.0, 1.0)

## O número cru, do jeito que a sim o tem. Sem porcentagem: o jogador conta
## golpes, não fatias.
func texto() -> String:
	return "%d/%d" % [estamina(), maxima()]

## Em que faixa a barra está agora.
func nivel() -> String:
	var quanto := fracao()
	if quanto <= LIMITE_BEIRA:
		return BEIRA
	if quanto <= LIMITE_ATENCAO:
		return ATENCAO
	return INTEIRO

## A cor da faixa de agora. Sai da paleta do design system — nenhuma cor é
## escrita à mão neste arquivo.
func cor() -> Color:
	match nivel():
		BEIRA:
			return Paleta.ALERTA
		ATENCAO:
			return Paleta.OURO
		_:
			return Paleta.VERDE

## O que está desenhado, para o teste ler o que o jogador lê.
func rotulo_na_tela() -> String:
	return _numero.text

func barra_na_tela() -> float:
	return _barra.fracao


# --- Evento vira tela ---

## O minuto que passa não mexe no corpo: estamina anda por trabalho feito e pela
## virada do dia, nunca pelo relógio. Ignorar o tick é o que deixa esta barra de
## graça em ×60.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	_atualiza()

func _atualiza() -> void:
	if _bridge == null:
		return
	_numero.text = texto()
	_barra.mostra(fracao(), cor())

## O bloco `corpo` deste jogador no snapshot. Jogador que ainda não trabalhou
## não tem entrada — e o dicionário vazio cai nos defaults, que é exatamente o
## corpo inteiro que ele tem.
func _jogador() -> Dictionary:
	if _bridge == null:
		return {}
	var bloco: Variant = _bridge.get_world().snapshot().get(SimFactory.CHAVE_CORPO, {})
	if not bloco is Dictionary:
		return {}
	var jogadores: Variant = (bloco as Dictionary).get("jogadores", {})
	if not jogadores is Dictionary:
		return {}
	var jogador: Variant = (jogadores as Dictionary).get(str(SimFactory.PLAYER_PADRAO), {})
	return jogador if jogador is Dictionary else {}
