extends GutTest

## Estado do caixote: acumular, tirar, esvaziar e o snapshot do save.

var _state: ShippingState

func before_each() -> void:
	_state = ShippingState.new()


func test_caixote_nasce_vazio() -> void:
	assert_true(_state.is_empty(), "caixote novo não tem nada dentro")
	assert_eq(_state.item_ids(), [])
	assert_eq(_state.count("rabanete"), 0, "item nunca depositado conta zero")
	assert_eq(_state.total_itens(), 0)

func test_depositar_acumula_no_que_ja_esta_la() -> void:
	_state.add("rabanete", 3)
	_state.add("rabanete", 2)

	assert_eq(_state.count("rabanete"), 5, "duas idas ao caixote somam")
	assert_eq(_state.item_ids().size(), 1, "um id só, não dois stacks")
	assert_false(_state.is_empty())

func test_quantidade_invalida_nao_encosta_no_caixote() -> void:
	_state.add("rabanete", 0)
	_state.add("cenoura", -5)
	_state.add("", 3)

	assert_true(_state.is_empty(), "zero, negativo e id vazio não viram depósito")

func test_ids_saem_em_ordem_alfabetica() -> void:
	_state.add("rabanete", 1)
	_state.add("abobora", 1)
	_state.add("morango", 1)

	assert_eq(_state.item_ids(), ["abobora", "morango", "rabanete"],
		"a ordem das linhas do resumo não depende de quem foi depositado primeiro")

func test_total_soma_todas_as_quantidades() -> void:
	_state.add("rabanete", 3)
	_state.add("cenoura", 4)

	assert_eq(_state.total_itens(), 7, "unidades esperando a venda")

func test_retirar_devolve_quanto_saiu_e_zera_a_entrada() -> void:
	_state.add("rabanete", 5)

	assert_eq(_state.remove("rabanete", 2), 2)
	assert_eq(_state.count("rabanete"), 3)

	assert_eq(_state.remove("rabanete", 3), 3)
	assert_true(_state.is_empty(), "entrada zerada some do caixote")

func test_retirar_mais_do_que_tem_leva_so_o_que_existe() -> void:
	_state.add("rabanete", 2)

	assert_eq(_state.remove("rabanete", 10), 2, "o state não inventa item")
	assert_eq(_state.count("rabanete"), 0)
	assert_eq(_state.remove("cenoura", 1), 0, "id que nunca entrou não sai")

func test_esvaziar_limpa_tudo() -> void:
	_state.add("rabanete", 3)
	_state.add("cenoura", 1)

	_state.clear()

	assert_true(_state.is_empty(), "é o que a venda ao dormir faz")
	assert_eq(_state.total_itens(), 0)

func test_snapshot_do_save_sai_ordenado() -> void:
	_state.add("rabanete", 3)
	_state.add("abobora", 1)

	var data := _state.to_dict()

	assert_eq(data["itens"], [
		{"item_id": "abobora", "qtd": 1},
		{"item_id": "rabanete", "qtd": 3},
	], "bloco `shipping` do save, na ordem contratada")

func test_carregar_substitui_o_que_estava_em_memoria() -> void:
	_state.add("morango", 9)

	_state.from_dict({"itens": [{"item_id": "cenoura", "qtd": 4}]})

	assert_eq(_state.count("morango"), 0, "o save manda")
	assert_eq(_state.count("cenoura"), 4)

func test_save_vazio_cai_nos_defaults() -> void:
	_state.add("morango", 9)

	_state.from_dict({})

	assert_true(_state.is_empty(), "campo ausente cai no default — campo novo entra sem migração")

func test_entrada_corrompida_no_save_e_ignorada() -> void:
	_state.from_dict({"itens": [
		{"item_id": "", "qtd": 5},
		{"item_id": "cenoura", "qtd": 0},
		{"item_id": "rabanete", "qtd": 2},
	]})

	assert_eq(_state.item_ids(), ["rabanete"],
		"id vazio e quantidade zerada não voltam do save")

func test_ida_e_volta_pelo_save_preserva_o_caixote() -> void:
	_state.add("rabanete", 3)
	_state.add("abobora", 1)

	var outro := ShippingState.new()
	outro.from_dict(_state.to_dict())

	assert_eq(outro.to_dict(), _state.to_dict(), "snapshot fecha o ciclo")
