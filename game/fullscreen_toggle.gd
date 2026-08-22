class_name FullscreenToggle
extends Node

## Liga e desliga a tela cheia (F11 e Alt+Enter, ação `toggle_fullscreen` do
## InputMap).
##
## Apresentação pura: não despacha ação, não lê estado da sim, não decide nada
## de jogo. O único assunto aqui é o modo da janela do sistema operacional.
##
## Mora fora da `SimBridge` de propósito. A bridge já tem dono e escopo
## documentados — ela é o relógio da sim e o cano dos eventos — e tamanho de
## janela não é assunto dela. Nó separado em `game/`, sem `setup`, é ignorado
## pela injeção da bridge e continua funcionando sozinho.

## Ligar/desligar tela cheia funciona mesmo com a árvore pausada: menu de pausa
## aberto não é motivo para o jogador ficar preso na janela.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_fullscreen"):
		return
	get_viewport().set_input_as_handled()
	_alterna()

## Qualquer um dos dois modos de tela cheia conta como "está cheia"; a volta é
## sempre `WINDOWED`, que devolve o tamanho que a janela tinha antes.
##
## O `MAIN_WINDOW_ID` é explícito de propósito: em debug existe uma segunda
## janela na tela (o playground de `game/dev/`), e tela cheia é sempre da janela
## do jogo, nunca da que estiver em foco. É o mesmo valor que o `DisplayServer`
## usaria por omissão — escrito à mão para que ninguém precise lembrar disso.
func _alterna() -> void:
	var modo: DisplayServer.WindowMode = DisplayServer.window_get_mode(
		DisplayServer.MAIN_WINDOW_ID
	)
	var cheia: bool = (
		modo == DisplayServer.WINDOW_MODE_FULLSCREEN
		or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	var destino: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	DisplayServer.window_set_mode(destino, DisplayServer.MAIN_WINDOW_ID)
