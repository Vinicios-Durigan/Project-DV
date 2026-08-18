extends GutTest

## State do tempo: defaults e round-trip do save v1.

func test_defaults_do_state() -> void:
	var state := TimeState.new()
	assert_eq(state.dia, 1, "o jogo começa no dia 1")
	assert_eq(state.minuto, 360, "06:00 é a hora de acordar")
	assert_eq(state.estacao, "primavera", "estação fixa no slice")

func test_to_dict_tem_o_formato_do_save() -> void:
	var state := TimeState.new()
	state.dia = 3
	state.minuto = 720
	assert_eq(state.to_dict(), {"dia": 3, "minuto": 720, "estacao": "primavera"})

func test_from_dict_carrega_tudo() -> void:
	var state := TimeState.new()
	state.from_dict({"dia": 12, "minuto": 90, "estacao": "verao"})
	assert_eq(state.dia, 12)
	assert_eq(state.minuto, 90)
	assert_eq(state.estacao, "verao")

func test_from_dict_vazio_mantem_defaults() -> void:
	var state := TimeState.new()
	state.dia = 9
	state.from_dict({})
	assert_eq(state.dia, 1, "campo ausente cai no default")
	assert_eq(state.minuto, 360)
	assert_eq(state.estacao, "primavera")

func test_from_dict_parcial_usa_default_no_que_falta() -> void:
	var state := TimeState.new()
	state.from_dict({"dia": 7})
	assert_eq(state.dia, 7, "o que veio no save vale")
	assert_eq(state.minuto, 360, "o que não veio cai no default — campo novo entra sem migração")

func test_round_trip_preserva_o_state() -> void:
	var original := TimeState.new()
	original.dia = 28
	original.minuto = 119
	original.estacao = "outono"

	var carregado := TimeState.new()
	carregado.from_dict(original.to_dict())

	assert_eq(carregado.to_dict(), original.to_dict(), "salvar e carregar não perde nada")
