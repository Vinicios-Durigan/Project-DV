extends GutTest

## Relógio: minuto a minuto, dormir, colapso às 02:00 e virada de estação.

var _state: TimeState
var _system: TimeSystem

func before_each() -> void:
	_state = TimeState.new()
	_system = TimeSystem.new(_state)


func test_tick_avanca_um_minuto() -> void:
	_system.tick()
	assert_eq(_state.minuto, 361, "tick = 1 minuto de jogo")

func test_tick_emite_minute_ticked_com_o_relogio_inteiro() -> void:
	var events := _system.tick()
	assert_eq(events.size(), 1, "minuto comum emite só o tick")
	var event := events[0] as MinuteTickedEvent
	assert_not_null(event, "o evento é MinuteTickedEvent")
	assert_eq(event.minuto, 361, "o evento traz o minuto já avançado")
	assert_eq(event.dia, 1)
	assert_eq(event.estacao, "primavera")

func test_sessenta_ticks_fecham_uma_hora() -> void:
	for _i in 60:
		_system.tick()
	assert_eq(_state.minuto, 420, "06:00 + 60 min = 07:00")

func test_meia_noite_vira_o_relogio_sem_virar_o_dia() -> void:
	_state.minuto = 1439
	var events := _system.tick()
	assert_eq(_state.minuto, 0, "23:59 → 00:00")
	assert_eq(_state.dia, 1, "o dia só vira ao dormir ou colapsar")
	assert_eq(events.size(), 1, "meia-noite não encerra o dia")

func test_dormir_encerra_o_dia() -> void:
	_state.minuto = 1320
	var events := _system.handle(SleepAction.new())

	assert_eq(events.size(), 1, "dormir emite um evento")
	var event := events[0] as DayEndedEvent
	assert_not_null(event, "o evento é DayEndedEvent")
	assert_eq(event.cause, DayEndedEvent.Cause.SLEPT, "causa é ter dormido")
	assert_eq(event.dia_encerrado, 1)
	assert_eq(event.dia_novo, 2)
	assert_false(event.fim_de_estacao, "dia 1 não fecha estação")

func test_dormir_acorda_as_seis_do_dia_seguinte() -> void:
	_state.minuto = 1320
	_system.handle(SleepAction.new())
	assert_eq(_state.dia, 2)
	assert_eq(_state.minuto, 360, "acorda 06:00")

func test_acao_desconhecida_e_ignorada() -> void:
	var events := _system.handle(SimAction.new())
	assert_eq(events, [], "sistema que não reconhece a ação devolve []")
	assert_eq(_state.dia, 1, "e não mexe no state")

func test_colapso_as_duas_da_manha() -> void:
	_state.minuto = 119
	var events := _system.tick()

	assert_eq(events.size(), 2, "o minuto do colapso emite tick + fim de dia")
	assert_true(events[0] is MinuteTickedEvent, "o minuto vem antes")
	var event := events[1] as DayEndedEvent
	assert_not_null(event, "o fim de dia vem depois")
	assert_eq(event.cause, DayEndedEvent.Cause.COLLAPSED, "acordado às 02:00 = colapso")
	assert_eq(event.dia_novo, 2)

func test_colapso_acorda_as_seis_do_dia_seguinte() -> void:
	_state.minuto = 119
	_system.tick()
	assert_eq(_state.dia, 2)
	assert_eq(_state.minuto, 360, "colapso segue a mesma sequência de dormir")

func test_dia_util_inteiro_colapsa_uma_vez_so() -> void:
	var events: Array[SimEvent] = []
	for _i in 1200:
		events.append_array(_system.tick())

	var fins := events.filter(func(e: SimEvent) -> bool: return e is DayEndedEvent)
	assert_eq(fins.size(), 1, "06:00 → 02:00 são 1200 minutos e um único fim de dia")
	assert_eq(events.size(), 1201, "1200 minutos + 1 fim de dia")
	assert_eq((fins[0] as DayEndedEvent).cause, DayEndedEvent.Cause.COLLAPSED)
	assert_eq(_state.minuto, 360, "o dia seguinte já começou às 06:00")

func test_dia_28_volta_para_o_dia_1() -> void:
	_state.dia = 28
	var events := _system.handle(SleepAction.new())
	var event := events[0] as DayEndedEvent

	assert_eq(event.dia_encerrado, 28)
	assert_eq(event.dia_novo, 1, "estação de 28 dias volta ao dia 1")
	assert_true(event.fim_de_estacao, "o evento avisa que a estação fechou")
	assert_eq(_state.dia, 1)

func test_dia_27_ainda_nao_fecha_estacao() -> void:
	_state.dia = 27
	var event := _system.handle(SleepAction.new())[0] as DayEndedEvent
	assert_eq(event.dia_novo, 28)
	assert_false(event.fim_de_estacao)

func test_sistema_nasce_com_state_proprio() -> void:
	var solo := TimeSystem.new()
	assert_eq(solo.get_state().dia, 1, "sem state injetado, cria o próprio")
