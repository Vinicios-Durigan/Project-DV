extends GutTest

## Crescimento na virada do dia, nunca contínuo.
##
## Ordem dos eventos — **contrato, não detalhe**: primeiro toda a passada de
## crescimento, depois toda a passada de morte de fim de estação; dentro de
## cada passada, os plots saem linha a linha (`y`) e da esquerda para a direita
## (`x`). É essa a cascata que `game/` anima de manhã.

var _state: FarmState
var _catalog: CropCatalog
var _system: FarmSystem

func before_each() -> void:
	_state = FarmState.new()
	_catalog = CropCatalog.new()
	_catalog.register(_def("rabanete", [1, 1, 2] as Array[int]))
	_catalog.register(_def("morango", [2, 2, 4] as Array[int], true))
	_system = FarmSystem.new(_state, _catalog)

func _def(id: String, dias: Array[int], rebrota: bool = false) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.dias_por_estagio = dias
	def.colheitas_infinitas = rebrota
	return def

func _planta(crop_id: String, x: int, y: int, regada: bool = true) -> FarmState.Plot:
	var plot := _state.get_plot(x, y)
	plot.arada = true
	plot.crop_id = crop_id
	plot.regada = regada
	return plot

## Uma noite. `fim_de_estacao` liga a morte do dia 28.
func _dormir(fim_de_estacao: bool = false) -> Array[SimEvent]:
	var day := DayEndedEvent.new()
	day.cause = DayEndedEvent.Cause.SLEPT
	day.dia_encerrado = 1
	day.dia_novo = 2
	day.estacao = "primavera"
	day.fim_de_estacao = fim_de_estacao
	return _system.react(day)


func test_cultura_regada_avanca_um_estagio() -> void:
	var plot := _planta("rabanete", 1, 1)
	var events := _dormir()

	assert_eq(plot.estagio, 1)
	assert_eq(events.size(), 1)
	var event := events[0] as CropGrewEvent
	assert_not_null(event, "emite CropGrewEvent")
	assert_eq(event.crop_id, "rabanete")
	assert_eq(event.estagio_de, 0)
	assert_eq(event.estagio_para, 1)
	assert_false(event.pronta)
	assert_eq(event.plot_id, "1:1")
	assert_eq(event.dia, 2, "o evento carrega o dia que começou")
	assert_eq(event.estacao, "primavera")

func test_rega_reseta_toda_noite() -> void:
	var plot := _planta("rabanete", 1, 1)
	_dormir()
	assert_false(plot.regada, "a manhã chega com a terra seca")

func test_cultura_seca_pausa_sem_morrer() -> void:
	var plot := _planta("rabanete", 1, 1, false)
	var events := _dormir()

	assert_eq(plot.estagio, 0, "sem água, sem progresso")
	assert_eq(plot.dias_no_estagio, 0, "o dia seco não conta")
	assert_eq(events, [], "pausar não é acontecimento")
	assert_true(plot.tem_cultura(), "não regar pausa, não mata")

func test_estagio_longo_precisa_de_todas_as_noites() -> void:
	var plot := _planta("rabanete", 1, 1)
	_dormir()
	plot.regada = true
	_dormir()

	assert_eq(plot.estagio, 2, "dois estágios de 1 dia")
	plot.regada = true
	var events := _dormir()
	assert_eq(plot.estagio, 2, "o estágio 2 leva 2 dias")
	assert_eq(plot.dias_no_estagio, 1)
	assert_eq(events, [], "sem avanço, sem evento")

	plot.regada = true
	var ultimo := _dormir()
	assert_eq(plot.estagio, 3, "quarta noite: pronta")
	assert_true((ultimo[0] as CropGrewEvent).pronta, "o evento já avisa que dá para colher")

func test_cultura_pronta_nao_cresce_mais() -> void:
	var plot := _planta("rabanete", 1, 1)
	plot.estagio = 3
	assert_eq(_dormir(), [], "pronta é o fim da linha")
	assert_eq(plot.estagio, 3)

func test_dias_ate_pronta_bate_com_a_definicao() -> void:
	var plot := _planta("rabanete", 1, 1)
	for _i in 4:
		plot.regada = true
		_dormir()
	assert_eq(plot.estagio, _catalog.get_def("rabanete").estagio_pronta())
	assert_eq(_catalog.get_def("rabanete").dias_ate_pronta(), 4, "o ciclo da tabela do GAMEPLAY")

func test_tile_sem_cultura_so_perde_a_rega() -> void:
	var plot := _state.get_plot(2, 2)
	plot.arada = true
	plot.regada = true

	assert_eq(_dormir(), [], "terra molhada vazia não gera evento")
	assert_false(plot.regada)
	assert_true(plot.arada)

func test_ordem_dos_eventos_e_linha_a_linha() -> void:
	_planta("rabanete", 5, 0)
	_planta("rabanete", 0, 0)
	_planta("rabanete", 1, 1)

	var events := _dormir()

	assert_eq(events.size(), 3)
	assert_eq((events[0] as CropGrewEvent).plot_id, "0:0")
	assert_eq((events[1] as CropGrewEvent).plot_id, "5:0")
	assert_eq((events[2] as CropGrewEvent).plot_id, "1:1")

func test_fim_de_estacao_mata_o_que_esta_no_chao() -> void:
	var plot := _planta("rabanete", 3, 3)
	var events := _dormir(true)

	assert_false(plot.tem_cultura(), "o que ficou no chão não vê a estação seguinte")
	assert_true(plot.arada, "a terra continua arada")
	assert_eq(events.size(), 2, "cresceu e depois morreu — a sequência de dormir, na ordem")
	assert_not_null(events[0] as CropGrewEvent)
	var morte := events[1] as CropDiedEvent
	assert_not_null(morte, "emite CropDiedEvent")
	assert_eq(morte.crop_id, "rabanete")
	assert_eq(morte.estagio, 1, "morreu no estágio em que estava")
	assert_eq(morte.motivo, CropDiedEvent.MOTIVO_FIM_DE_ESTACAO)
	assert_eq(morte.plot_id, "3:3")

func test_fim_de_estacao_mata_ate_o_que_estava_pronto() -> void:
	var plot := _planta("rabanete", 3, 3, false)
	plot.estagio = 3
	var events := _dormir(true)

	assert_false(plot.tem_cultura(), "colher era ontem")
	assert_eq(events.size(), 1)
	assert_not_null(events[0] as CropDiedEvent)

func test_fim_de_estacao_primeiro_todo_crescimento_depois_toda_morte() -> void:
	_planta("rabanete", 0, 0)
	_planta("rabanete", 1, 0)

	var events := _dormir(true)

	assert_eq(events.size(), 4)
	assert_not_null(events[0] as CropGrewEvent, "0:0 cresceu")
	assert_not_null(events[1] as CropGrewEvent, "1:0 cresceu")
	assert_eq((events[2] as CropDiedEvent).plot_id, "0:0")
	assert_eq((events[3] as CropDiedEvent).plot_id, "1:0")

func test_rebrota_cresce_de_novo_depois_da_colheita() -> void:
	var plot := _planta("morango", 4, 4, false)
	plot.estagio = 3

	var action := HarvestCropAction.new()
	action.x = 4
	action.y = 4
	_system.handle(action)
	assert_eq(plot.estagio, 2, "voltou ao estágio anterior ao pronta")

	for _i in 4:
		plot.regada = true
		_dormir()
	assert_eq(plot.estagio, 3, "4 noites regadas e o morango está pronto de novo")

func test_dormir_de_verdade_dispara_o_crescimento() -> void:
	var world := SimWorld.new()
	var time := TimeSystem.new()
	world.register_system(_system)
	world.register_system(time)
	_planta("rabanete", 1, 1)

	var events := world.handle(SleepAction.new())

	assert_eq(events.size(), 2, "o dia virou e a cultura cresceu")
	assert_not_null(events[0] as DayEndedEvent, "primeiro o fato: o dia acabou")
	assert_not_null(events[1] as CropGrewEvent, "depois a consequência: a cascata da manhã")
	assert_eq(time.get_state().dia, 2)

func test_colapso_as_duas_da_manha_tambem_faz_crescer() -> void:
	var world := SimWorld.new()
	var time := TimeSystem.new()
	time.get_state().minuto = TimeSystem.MINUTO_COLAPSO - 1
	world.register_system(_system)
	world.register_system(time)
	_planta("rabanete", 1, 1)

	var events := world.advance(1)

	var cresceu := false
	for event in events:
		if event is CropGrewEvent:
			cresceu = true
	assert_true(cresceu, "desmaiar no campo não impede a plantação de crescer")
