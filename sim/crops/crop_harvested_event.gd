class_name CropHarvestedEvent
extends ItemGrantedEvent

## A cultura foi colhida. É um `ItemGrantedEvent`: o inventário reage
## adicionando `item_id` × `qtd` sem saber que existe agricultura.
##
## `rebrota` true = a planta ficou no chão e volta a produzir; false = o tile
## ficou vazio (e arado).

var plot_id: String = ""
var x: int = 0
var y: int = 0
var crop_id: String = ""
var rebrota: bool = false
