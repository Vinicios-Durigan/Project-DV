class_name PlaygroundWindow
extends Window

## Janela de sistema operacional dedicada ao playground de dev.
##
## Por que janela separada, e não um `Control` dentro do jogo: o jogo roda num
## viewport de 640x360 com escala inteira (GAMEPLAY §2) e o playground pede
## 1328x453 de conteúdo — dentro do viewport ele nasceria cortado pela metade.
## Dev tools em janela própria é o que o GAMEPLAY §11 já previa (F1, `game/dev/`,
## só em debug), não negocia com nenhuma decisão do §2 e continua valendo depois:
## na wave visual o jogador vê o jogo em 640x360 numa janela e o dev abre o
## painel na outra, lado a lado. As alternativas (desligar o content scale ou
## encolher os painéis) morrem no dia em que a cena real do jogo chegar.
##
## Para ser janela do SO de verdade e não uma subjanela embutida (que voltaria a
## ser recortada pelo viewport de 640x360), `display/window/subwindows/
## embed_subwindows` está em `false` no project.godot. O padrão do Godot 4.7 é
## `true`.
##
## Não entra no jogo final: quem instancia é a `SimBridge`, e só em build debug.

## Nome na barra de título e na barra de tarefas — tem que dar para achar a
## janela certa entre as duas.
const TITULO: String = "Project-DV — Playground (dev)"

## Folga sobre o mínimo real do conteúdo (medido: 1344x469 com as margens).
## Sobra para o diário de eventos crescer sem empurrar as outras colunas.
const TAMANHO_INICIAL: Vector2i = Vector2i(1400, 800)

## Abre e fecha a janela (GAMEPLAY §11).
const ACAO_ALTERNAR: String = "toggle_playground"

var _playground: Playground

func _ready() -> void:
	_playground = $Playground as Playground
	title = TITULO
	size = TAMANHO_INICIAL

	# Esta janela é UI de ferramenta, não pixel art: desenha 1:1. Uma `Window`
	# nova já nasce com `CONTENT_SCALE_MODE_DISABLED` e não herda o content
	# scale da janela principal, mas fica explícito para que mexer no §2 nunca
	# vaze para cá.
	content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	content_scale_factor = 1.0

	# O playground ocupa a janela inteira, seja qual for o tamanho que o dev
	# arrastar.
	_playground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fechar a ferramenta não pode derrubar o jogo.
	close_requested.connect(_ao_fechar)

	# O mínimo sai do próprio layout, não de um número chutado: painel que
	# crescer amanhã empurra o mínimo junto e a janela nunca clipa.
	_ajusta_minimo.call_deferred()

## A `SimBridge` chama `setup` apenas em filho direto. Dentro de uma `Window` o
## playground vira neto e a injeção passaria longe dele — então a janela recebe
## o fio e o repassa à mão, numa linha explícita. Não há dependência de ordem de
## árvore nem de nó "achar" a bridge sozinho.
func setup(bridge: SimBridge) -> void:
	_playground.setup(bridge)

## F1 lido pelo singleton `Input`, e não por `_unhandled_input`, de propósito:
## evento de teclado é entregue ao viewport da janela em foco, e esta janela
## precisa abrir e fechar tanto com o jogo em foco quanto com ela própria em
## foco. `Input` é global e resolve os dois casos com uma linha.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(ACAO_ALTERNAR):
		alterna()

## Esconde ou mostra. Escondida, a janela continua na árvore com o estado
## intacto — reabrir não remonta painel nem repassa o fio.
func alterna() -> void:
	if visible:
		hide()
		return
	show()
	grab_focus()

## O "X" da janela de dev fecha só a ferramenta. Sem isso, o `close_requested`
## de uma janela filha derrubaria a partida junto.
func _ao_fechar() -> void:
	hide()

## Impede que arrastar a borda encolha a janela até cortar um painel.
##
## O mínimo espera um frame porque `get_combined_minimum_size` só tem valor
## depois do primeiro passe de layout — antes disso todo mundo mede zero.
func _ajusta_minimo() -> void:
	await get_tree().process_frame
	min_size = _minimo_do_conteudo()

## `Playground` é um `Control` solto, não um container: o mínimo dos painéis não
## sobe até ele e ele mede 0x0. O mínimo de verdade está nos filhos diretos, que
## são containers — pega o maior deles, sem depender de caminho de nó.
func _minimo_do_conteudo() -> Vector2i:
	var minimo: Vector2 = Vector2.ZERO
	for filho: Node in _playground.get_children():
		var caixa: Control = filho as Control
		if caixa == null:
			continue
		minimo = minimo.max(caixa.get_combined_minimum_size())
	return Vector2i(minimo.ceil())
