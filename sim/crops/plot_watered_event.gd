class_name PlotWateredEvent
extends SimEvent

## A terra do tile foi molhada. `crop_id` vazio quando o tile está arado e sem
## planta — a terra comunica rega, a planta comunica estágio.

var player_id: int = 0
var plot_id: String = ""
var x: int = 0
var y: int = 0
var crop_id: String = ""
