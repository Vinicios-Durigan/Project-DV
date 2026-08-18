class_name ItemLostEvent
extends SimEvent

## O item não coube no inventário e sumiu. Drop no chão é assunto futuro: o
## evento já existe para quem for implementar.

var player_id: int = 0
var item_id: String = ""
## Quanto se perdeu.
var qtd: int = 0
