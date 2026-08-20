class_name CropPlantedEvent
extends SimEvent

## A semente entrou na terra, no estágio 0.
##
## `estagio_pronta` viaja junto para `game/` saber quantos estágios existem sem
## abrir o catálogo.

var player_id: int = 0
var plot_id: String = ""
var x: int = 0
var y: int = 0
var crop_id: String = ""
var estagio_pronta: int = 0
