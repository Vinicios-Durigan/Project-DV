class_name DayEndedEvent
extends SimEvent

## O dia acabou. `cause` distingue dormir de colapso às 02:00.
##
## Hoje ninguém trata COLLAPSED; amanhã fadiga/morte/hospital escutam a causa
## que sempre existiu, sem refatorar nada.

enum Cause {
	SLEPT,
	COLLAPSED,
}

var cause: Cause = Cause.SLEPT
var dia_encerrado: int = TimeState.DIA_DEFAULT
var dia_novo: int = TimeState.DIA_DEFAULT
var estacao: String = TimeState.ESTACAO_DEFAULT
## Verdadeiro quando o dia encerrado era o último da estação (dia 28).
var fim_de_estacao: bool = false
