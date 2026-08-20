class_name CropGrewEvent
extends SimEvent

## A cultura avançou de estágio na virada do dia. Um evento por planta que
## cresceu, na ordem dos plots (linha a linha) — é essa a cascata que `game/`
## anima de manhã.
##
## Campos `de`/`para` porque descreve transição; `pronta` evita `game/` ter que
## comparar com o catálogo para saber se já pode colher.

var plot_id: String = ""
var x: int = 0
var y: int = 0
var crop_id: String = ""
var estagio_de: int = 0
var estagio_para: int = 0
var pronta: bool = false
var dia: int = TimeState.DIA_DEFAULT
var estacao: String = TimeState.ESTACAO_DEFAULT
