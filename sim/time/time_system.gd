class_name TimeSystem
extends SimSystem

## Relógio da simulação. Tick = 1 minuto de jogo.
##
## Dia útil 06:00 → 02:00. Dormir encerra o dia por vontade própria; chegar às
## 02:00 acordado encerra por colapso — mesma sequência, causa diferente.
## Estação de 28 dias: encerrar o dia 28 volta ao dia 1 com `fim_de_estacao`.

const MINUTOS_POR_DIA: int = 1440
const MINUTO_ACORDAR: int = 360
const MINUTO_COLAPSO: int = 120
const DIAS_POR_ESTACAO: int = 28

var _state: TimeState

func _init(state: TimeState = null) -> void:
	_state = state if state != null else TimeState.new()

func get_state() -> TimeState:
	return _state

func tick() -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	_state.minuto = (_state.minuto + 1) % MINUTOS_POR_DIA
	events.append(_minute_ticked())
	if _state.minuto == MINUTO_COLAPSO:
		events.append(_end_day(DayEndedEvent.Cause.COLLAPSED))
	return events

func handle(action: SimAction) -> Array[SimEvent]:
	if not action is SleepAction:
		return []
	var events: Array[SimEvent] = []
	events.append(_end_day(DayEndedEvent.Cause.SLEPT))
	return events

## O corpo caiu: o dia acaba por colapso, exatamente como às 02:00.
##
## É a fadiga que o `DayEndedEvent.Cause.COLLAPSED` esperava desde a wave 01 —
## a causa nasceu sem consumidor de propósito, e a wave 15 só ligou o fio. O
## `SistemaCorpo` não fecha o dia sozinho: quem é dono do calendário é este
## sistema, e é dele que a cascata da manhã depende.
func react(event: SimEvent) -> Array[SimEvent]:
	if not event is DesmaiouEvent:
		return []
	return [_end_day(DayEndedEvent.Cause.COLLAPSED)]

func _minute_ticked() -> MinuteTickedEvent:
	var event := MinuteTickedEvent.new()
	event.dia = _state.dia
	event.minuto = _state.minuto
	event.estacao = _state.estacao
	return event

## Encerra o dia: avança o calendário e acorda às 06:00.
func _end_day(cause: DayEndedEvent.Cause) -> DayEndedEvent:
	var dia_encerrado := _state.dia
	var fim_de_estacao := dia_encerrado >= DIAS_POR_ESTACAO
	_state.dia = 1 if fim_de_estacao else dia_encerrado + 1
	_state.minuto = MINUTO_ACORDAR

	var event := DayEndedEvent.new()
	event.cause = cause
	event.dia_encerrado = dia_encerrado
	event.dia_novo = _state.dia
	event.estacao = _state.estacao
	event.fim_de_estacao = fim_de_estacao
	return event
