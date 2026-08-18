class_name ActionRejectedEvent
extends SimEvent

## A ação era impossível e foi barrada. Quem detectou marcou `rejeitada` na ação;
## os sistemas seguintes a ignoram. Ninguém desfaz nada.
##
## `motivo` é id de máquina (`item_insuficiente`), não texto de tela — `game/`
## decide como falar com o jogador.

var player_id: int = 0
## Nome da classe da ação barrada, ex.: "RemoveItemAction".
var acao: String = ""
var motivo: String = ""
