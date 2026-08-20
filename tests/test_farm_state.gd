extends GutTest

## Estado da fazenda: plots por "x:y", defaults e round-trip do save.

var _state: FarmState

func before_each() -> void:
	_state = FarmState.new()


func test_plot_nasce_com_defaults_seguros() -> void:
	var plot := _state.get_plot(3, 7)
	assert_eq(plot.x, 3)
	assert_eq(plot.y, 7)
	assert_false(plot.arada, "chão intocado é grama")
	assert_false(plot.regada)
	assert_eq(plot.crop_id, "")
	assert_eq(plot.estagio, 0)
	assert_eq(plot.dias_no_estagio, 0)
	assert_false(plot.tem_cultura())

func test_get_plot_cria_uma_vez_e_devolve_o_mesmo() -> void:
	_state.get_plot(1, 1).arada = true
	assert_true(_state.has_plot(1, 1))
	assert_true(_state.get_plot(1, 1).arada, "é o mesmo plot, não uma cópia")
	assert_eq(_state.plot_ids().size(), 1)

func test_peek_nao_cria_plot() -> void:
	var plot := _state.peek_plot(9, 9)
	assert_false(plot.arada, "consulta devolve os defaults")
	assert_false(_state.has_plot(9, 9), "consultar o retículo não suja o save")
	assert_eq(_state.plot_ids().size(), 0)

func test_plot_id_e_x_por_y() -> void:
	assert_eq(FarmState.plot_id(12, 7), "12:7")
	assert_eq(FarmState.plot_id(-1, 0), "-1:0")

func test_ordem_dos_plots_e_por_linha_depois_coluna() -> void:
	_state.get_plot(2, 1)
	_state.get_plot(0, 0)
	_state.get_plot(1, 1)
	_state.get_plot(5, 0)
	assert_eq(_state.plot_ids(), ["0:0", "5:0", "1:1", "2:1"],
		"a manhã anima linha a linha, da esquerda para a direita — a ordem é contrato")

func test_limpa_cultura_mantem_o_tile_arado() -> void:
	var plot := _state.get_plot(1, 1)
	plot.arada = true
	plot.crop_id = "rabanete"
	plot.estagio = 3
	plot.dias_no_estagio = 2

	plot.limpa_cultura()

	assert_false(plot.tem_cultura())
	assert_eq(plot.estagio, 0)
	assert_eq(plot.dias_no_estagio, 0)
	assert_true(plot.arada, "a terra continua arada depois da colheita")

func test_save_ida_e_volta() -> void:
	var plot := _state.get_plot(12, 7)
	plot.arada = true
	plot.regada = true
	plot.crop_id = "rabanete"
	plot.estagio = 2
	plot.dias_no_estagio = 1

	var outro := FarmState.new()
	outro.from_dict(_state.to_dict())

	var carregado := outro.get_plot(12, 7)
	assert_true(carregado.arada)
	assert_true(carregado.regada)
	assert_eq(carregado.crop_id, "rabanete")
	assert_eq(carregado.estagio, 2)
	assert_eq(carregado.dias_no_estagio, 1)
	assert_eq(carregado.x, 12, "as coordenadas voltam da chave")
	assert_eq(carregado.y, 7)

func test_plot_intocado_nao_entra_no_save() -> void:
	_state.get_plot(0, 0)
	_state.get_plot(1, 0).arada = true
	var plots: Dictionary = _state.to_dict()["plots"]
	assert_eq(plots.size(), 1, "só o que mudou ocupa espaço no save")
	assert_true(plots.has("1:0"))

func test_campo_ausente_cai_no_default() -> void:
	var outro := FarmState.new()
	outro.from_dict({"plots": {"4:5": {"arada": true}}})
	var plot := outro.get_plot(4, 5)
	assert_true(plot.arada)
	assert_false(plot.regada, "campo novo entra sem migração")
	assert_eq(plot.crop_id, "")

func test_save_vazio_nao_quebra() -> void:
	var outro := FarmState.new()
	outro.from_dict({})
	assert_eq(outro.plot_ids(), [], "fazenda intocada")

func test_from_dict_substitui_o_que_estava_em_memoria() -> void:
	_state.get_plot(1, 1).arada = true
	_state.from_dict({"plots": {"2:2": {"arada": true}}})
	assert_false(_state.has_plot(1, 1), "carregar save não mistura com a partida anterior")
	assert_true(_state.has_plot(2, 2))
