class_name SlotEquipadoEvent
extends SimEvent

## A mão do jogador mudou de slot.
##
## Evento gordo de propósito: vem com o `item_id` que ficou na mão, para
## `game/` trocar o rótulo do retículo e destacar a hotbar sem consultar o
## estado. `item_id` vazio é mão vazia — slot sem item, ou índice além do que a
## mochila tem hoje.

var player_id: int = 0
## Índice do slot que passou a estar na mão.
var slot: int = 0
## O que está na mão agora. Vazio = mão vazia.
var item_id: String = ""
