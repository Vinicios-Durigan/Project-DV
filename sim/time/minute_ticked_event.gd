class_name MinuteTickedEvent
extends SimEvent

## Passou 1 minuto de jogo. Carrega o relógio inteiro para que o HUD nunca
## precise ler o state da sim.

var dia: int = TimeState.DIA_DEFAULT
var minuto: int = TimeState.MINUTO_DEFAULT
var estacao: String = TimeState.ESTACAO_DEFAULT
