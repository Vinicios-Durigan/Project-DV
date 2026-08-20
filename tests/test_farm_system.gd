extends GutTest

## As 4 ações de fazenda: arar, plantar, regar, colher.
##
## Ação inválida não muda nada e não emite nada — exceto quando a cadeia já
## cobrou o preço (plantar consome a semente antes do FarmSystem olhar o tile):
## aí sai `ActionRejectedEvent` para `game/` ter o que dizer ao jogador.

var _state: FarmState
var _catalog: CropCatalog
var _system: FarmSystem

func before_each() -> void:
	_state = FarmState.new()
	_catalog = CropCatalog.new()
	_catalog.register(_def("rabanete", [1, 1, 2] as Array[int]))
	_catalog.register(_def("morango", [2, 2, 4] as Array[int], true, 1))
	_system = FarmSystem.new(_state, _catalog)

func _def(id: String, dias: Array[int], rebrota: bool = false, rende: int = 1) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.dias_por_estagio = dias
	def.colheitas_infinitas = rebrota
	def.rende_por_colheita = rende
	return def

func _arar(x: int, y: int) -> Array[SimEvent]:
	var action := TillPlotAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _plantar(crop_id: String, x: int, y: int) -> Array[SimEvent]:
	var action := PlantCropAction.new()
	action.crop_id = crop_id
	action.item_id = "semente_%s" % crop_id
	action.x = x
	action.y = y
	return _system.handle(action)

func _regar(x: int, y: int) -> Array[SimEvent]:
	var action := WaterPlotAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _colher(x: int, y: int) -> Array[SimEvent]:
	var action := HarvestCropAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _madura(crop_id: String, x: int, y: int) -> void:
	var plot := _state.get_plot(x, y)
	plot.arada = true
	plot.crop_id = crop_id
	plot.estagio = _catalog.get_def(crop_id).estagio_pronta()


func test_arar_grama_revira_a_terra() -> void:
	var events := _arar(1, 1)

	assert_true(_state.get_plot(1, 1).arada)
	assert_eq(events.size(), 1)
	var event := events[0] as PlotTilledEvent
	assert_not_null(event, "emite PlotTilledEvent")
	assert_eq(event.x, 1)
	assert_eq(event.y, 1)
	assert_eq(event.plot_id, "1:1")
	assert_eq(event.player_id, 0)

func test_arar_de_novo_nao_faz_nada() -> void:
	_arar(1, 1)
	assert_eq(_regar(1, 1).size(), 1, "sanidade: o tile existe e é regável")
	assert_eq(_arar(1, 1), [], "tile já arado: sem mudança, sem evento")

func test_arar_tile_com_cultura_nao_faz_nada() -> void:
	_madura("rabanete", 1, 1)
	assert_eq(_arar(1, 1), [], "a enxada não passa por cima da plantação")
	assert_true(_state.get_plot(1, 1).tem_cultura())

func test_plantar_em_terra_arada() -> void:
	_arar(2, 3)
	var events := _plantar("rabanete", 2, 3)

	var plot := _state.get_plot(2, 3)
	assert_eq(plot.crop_id, "rabanete")
	assert_eq(plot.estagio, 0, "nasce no primeiro estágio")
	assert_eq(plot.dias_no_estagio, 0)
	assert_eq(events.size(), 1)
	var event := events[0] as CropPlantedEvent
	assert_not_null(event, "emite CropPlantedEvent")
	assert_eq(event.crop_id, "rabanete")
	assert_eq(event.x, 2)
	assert_eq(event.y, 3)
	assert_eq(event.estagio_pronta, 3, "game/ já sabe quantos estágios animar")

func test_plantar_em_grama_e_rejeitado() -> void:
	var events := _plantar("rabanete", 2, 3)

	assert_false(_state.peek_plot(2, 3).tem_cultura(), "semente não pega em grama")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "a semente já foi cobrada: game/ precisa saber que falhou")
	assert_eq(event.motivo, FarmSystem.MOTIVO_TILE_NAO_ARADO)
	assert_eq(event.acao, "PlantCropAction")

func test_plantar_em_tile_ocupado_e_rejeitado() -> void:
	_arar(2, 3)
	_plantar("rabanete", 2, 3)
	var events := _plantar("morango", 2, 3)

	assert_eq(_state.get_plot(2, 3).crop_id, "rabanete", "a primeira cultura fica")
	assert_eq((events[0] as ActionRejectedEvent).motivo, FarmSystem.MOTIVO_TILE_OCUPADO)

func test_plantar_cultura_desconhecida_e_rejeitado() -> void:
	_arar(2, 3)
	var events := _plantar("dragao", 2, 3)

	assert_false(_state.get_plot(2, 3).tem_cultura())
	assert_eq((events[0] as ActionRejectedEvent).motivo, FarmSystem.MOTIVO_CULTURA_DESCONHECIDA)

func test_acao_ja_rejeitada_nao_encosta_no_tile() -> void:
	_arar(2, 3)
	var action := PlantCropAction.new()
	action.crop_id = "rabanete"
	action.item_id = "semente_rabanete"
	action.x = 2
	action.y = 3
	action.rejeitada = true

	assert_eq(_system.handle(action), [], "quem valida vem antes de quem executa")
	assert_false(_state.get_plot(2, 3).tem_cultura(), "sem semente, sem plantio")

func test_regar_escurece_a_terra() -> void:
	_arar(4, 4)
	var events := _regar(4, 4)

	assert_true(_state.get_plot(4, 4).regada)
	var event := events[0] as PlotWateredEvent
	assert_not_null(event, "emite PlotWateredEvent")
	assert_eq(event.x, 4)
	assert_eq(event.y, 4)
	assert_eq(event.crop_id, "", "tile arado sem planta também molha")

func test_regar_de_novo_nao_faz_nada() -> void:
	_arar(4, 4)
	_regar(4, 4)
	assert_eq(_regar(4, 4), [], "já estava molhado")

func test_regar_grama_nao_faz_nada() -> void:
	assert_eq(_regar(4, 4), [], "água em grama não vira nada")
	assert_false(_state.has_plot(4, 4), "e nem cria plot no save")

func test_colher_cultura_pronta() -> void:
	_madura("rabanete", 5, 5)
	var events := _colher(5, 5)

	var plot := _state.get_plot(5, 5)
	assert_false(plot.tem_cultura(), "cultura sem rebrota sai do tile")
	assert_true(plot.arada, "a terra continua arada")
	assert_eq(events.size(), 1)
	var event := events[0] as CropHarvestedEvent
	assert_not_null(event, "emite CropHarvestedEvent")
	assert_eq(event.crop_id, "rabanete")
	assert_eq(event.item_id, "rabanete", "o que entra na mochila é o item, não a cultura")
	assert_eq(event.qtd, 1)
	assert_false(event.rebrota)

func test_colher_cultura_verde_nao_faz_nada() -> void:
	_arar(5, 5)
	_plantar("rabanete", 5, 5)
	assert_eq(_colher(5, 5), [], "cultura verde não vem na mão")
	assert_true(_state.get_plot(5, 5).tem_cultura())

func test_colher_um_estagio_antes_da_pronta_nao_faz_nada() -> void:
	_madura("rabanete", 5, 5)
	_state.get_plot(5, 5).estagio -= 1
	assert_eq(_colher(5, 5), [], "falta um estágio")

func test_colher_tile_vazio_nao_faz_nada() -> void:
	_arar(5, 5)
	assert_eq(_colher(5, 5), [])

func test_colher_rebrota_volta_ao_estagio_anterior() -> void:
	_madura("morango", 6, 6)
	var events := _colher(6, 6)

	var plot := _state.get_plot(6, 6)
	assert_eq(plot.crop_id, "morango", "a planta fica no chão")
	assert_eq(plot.estagio, 2, "volta ao estágio anterior ao pronta")
	assert_eq(plot.dias_no_estagio, 0, "e recomeça a contagem")
	assert_true((events[0] as CropHarvestedEvent).rebrota)

func test_rende_mais_de_uma_unidade() -> void:
	_catalog.register(_def("abobora", [4, 4, 5] as Array[int], false, 3))
	_madura("abobora", 7, 7)
	assert_eq((_colher(7, 7)[0] as CropHarvestedEvent).qtd, 3)

func test_consultas_do_reticulo_nao_mudam_nada() -> void:
	assert_true(_system.pode_arar(1, 1))
	assert_false(_system.pode_plantar("rabanete", 1, 1))
	assert_false(_system.pode_regar(1, 1))
	assert_false(_system.pode_colher(1, 1))
	assert_false(_state.has_plot(1, 1), "consultar o retículo não cria plot")

	_arar(1, 1)
	assert_false(_system.pode_arar(1, 1))
	assert_true(_system.pode_plantar("rabanete", 1, 1))
	assert_true(_system.pode_regar(1, 1))
	assert_false(_system.pode_colher(1, 1))

	_plantar("rabanete", 1, 1)
	assert_false(_system.pode_plantar("rabanete", 1, 1))
	assert_false(_system.pode_colher(1, 1), "ainda verde")
	_state.get_plot(1, 1).estagio = 3
	assert_true(_system.pode_colher(1, 1))
