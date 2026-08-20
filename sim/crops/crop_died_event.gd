class_name CropDiedEvent
extends SimEvent

## A cultura morreu e saiu do tile. Hoje só existe um motivo — a estação virou
## com planta no chão — mas o campo já viaja para praga, geada e afins.

const MOTIVO_FIM_DE_ESTACAO: String = "fim_de_estacao"

var plot_id: String = ""
var x: int = 0
var y: int = 0
var crop_id: String = ""
## Em que estágio a planta estava quando morreu.
var estagio: int = 0
var motivo: String = MOTIVO_FIM_DE_ESTACAO
var dia: int = TimeState.DIA_DEFAULT
var estacao: String = TimeState.ESTACAO_DEFAULT
