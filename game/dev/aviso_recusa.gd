class_name AvisoRecusa
extends Control

## O toast de recusa: quando a sim barra uma ação, o motivo aparece por cima do
## mundo e some sozinho.
##
## ## A decisão que este arquivo implementa
##
## **Toda recusa diz o porquê** (design system v1). "Não deu" não existe neste
## projeto: o `ActionRejectedEvent` carrega um `motivo`, e o motivo vira frase.
## Se um dia faltar frase, o toast mostra o id cru — feio de propósito, para
## alguém corrigir, e nunca silencioso.
##
## ## A divisão de trabalho, de novo
##
## `motivo` é **id de máquina** (`fora_do_local`), decidido em `sim/`. A frase é
## de `game/`, porque falar com o jogador é apresentação. É por isso que a
## tabela mora aqui e não lá — e é por isso que traduzir para outra língua um
## dia não vai encostar em regra nenhuma.
##
## Este nó não julga nada: ele não sabe se a ação era possível, só repete o que
## a sim respondeu.
##
## ---
##
## ## Padrão 3 — escutar avisos
##
## Um `connect` no fio, um filtro por tipo, e o resto ignorado em silêncio.

## Motivo → frase. Cada linha explica **o que aconteceu**, não o que falhou.
const FRASES: Dictionary = {
	"fora_do_local": "Você não está na fazenda — a ação foi recusada",
	"ja_no_local": "Você já está nesse lugar",
	"destino_desconhecido": "Esse destino não existe no mapa",
	"tile_nao_arado": "O canteiro não foi arado ainda — passe a enxada antes",
	"tile_ocupado": "Já tem cultura nesse canteiro",
	"cultura_desconhecida": "Essa cultura não está no catálogo",
	"item_insuficiente": "Você não tem esse item na mochila",
	"dinheiro_insuficiente": "Dinheiro insuficiente para essa compra",
}

## Quanto o toast fica de pé antes de começar a sumir, e quanto leva sumindo.
const SEGUNDOS_DE_PE: float = 2.2
const SEGUNDOS_SUMINDO: float = 0.5

## Distância do toast até a base do mundo, em pixels (múltiplo de 4).
const ALTURA_DO_CHAO: float = 16.0

var _bridge: SimBridge
var _caixa: PanelContainer
var _rotulo: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# O toast não intercepta clique: quem está agindo no mundo continua agindo
	# enquanto ele está na tela.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_caixa = PanelContainer.new()
	_caixa.theme_type_variation = &"Toast"
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.modulate = Paleta.INVISIVEL
	# Ancorado no rodapé do mundo, e não posicionado à mão: com âncora, arrastar
	# a borda da janela leva o toast junto. Sem ela, ele fica onde estava quando
	# apareceu — e some para fora da tela no primeiro redimensionamento.
	_caixa.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(_caixa)

	_rotulo = Label.new()
	_rotulo.theme_type_variation = &"Recusa"
	_caixa.add_child(_rotulo)

## Padrão 3: recebe o fio e escuta. Não existe passo três.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)


## A frase que o jogador lê. Pública porque é a parte que apodrece — motivo novo
## em `sim/` sem frase aqui é o que o teste pega.
func frase_de(evento: ActionRejectedEvent) -> String:
	if FRASES.has(evento.motivo):
		return String(FRASES[evento.motivo])
	# Sem frase, o id cru aparece. Um toast que some seria pior que um toast
	# feio: o jogador ficaria sem saber que a sim respondeu.
	return "Recusado (%s)" % evento.motivo


func _on_sim_event(event: SimEvent) -> void:
	var recusa := event as ActionRejectedEvent
	if recusa == null:
		return
	mostra(frase_de(recusa))

## Mostra o toast e agenda o sumiço. Recusa nova durante o sumiço reinicia a
## contagem: o jogador que insiste no botão errado vê o motivo o tempo todo, e
## não um piscar.
func mostra(texto: String) -> void:
	_rotulo.text = "✕  %s" % texto
	_posiciona.call_deferred()

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_caixa.modulate = Paleta.VISIVEL
	# `Tween` e não `Timer`: a resposta começa no mesmo frame do evento
	# (GAMEPLAY §6, ≤2 frames) e o sumiço é o único tempo desenhado.
	_tween = create_tween()
	_tween.tween_interval(SEGUNDOS_DE_PE)
	_tween.tween_property(_caixa, "modulate:a", 0.0, SEGUNDOS_SUMINDO)

## Rodapé do mundo, centralizado — o mesmo lugar do mock. Espera um frame
## porque o tamanho da caixa só existe depois do passe de layout: o texto acabou
## de mudar e a largura ainda é a da frase anterior.
##
## A âncora já resolve *onde* é o rodapé do meio; aqui só se acerta o tamanho e
## o recuo a partir dela.
##
## Quem chama pode ter sumido da árvore no meio da espera (a janela de dev fecha
## a qualquer momento) — daí as duas checagens.
func _posiciona() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var caixa := _caixa.get_combined_minimum_size()
	_caixa.size = caixa
	_caixa.position = Vector2(
		floorf(-caixa.x * 0.5),
		-caixa.y - ALTURA_DO_CHAO)
