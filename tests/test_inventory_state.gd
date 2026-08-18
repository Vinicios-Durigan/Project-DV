extends GutTest

## Inventário por player_id: slots, capacity, dinheiro e o bloco do save.

func _slot(item_id: String, qtd: int) -> InventoryState.Slot:
	return InventoryState.Slot.new(item_id, qtd)


func test_player_nasce_com_os_defaults_do_slice() -> void:
	var inv := InventoryState.new().get_player(0)
	assert_eq(inv.slots, [], "mochila vazia")
	assert_eq(inv.capacity, 24, "24 slots")
	assert_eq(inv.dinheiro, 500, "começa com 500g")

func test_get_player_devolve_sempre_o_mesmo_inventario() -> void:
	var state := InventoryState.new()
	state.get_player(0).dinheiro = 120
	assert_eq(state.get_player(0).dinheiro, 120, "o inventário é criado uma vez só")

func test_players_sao_independentes() -> void:
	var state := InventoryState.new()
	state.get_player(0).dinheiro = 0
	assert_eq(state.get_player(1).dinheiro, 500, "co-op: cada player tem o próprio inventário")

func test_player_ids_sai_em_ordem_deterministica() -> void:
	var state := InventoryState.new()
	state.get_player(2)
	state.get_player(0)
	assert_eq(state.player_ids(), [0, 2], "ordem não depende de quem chegou primeiro")

func test_count_soma_os_stacks_do_mesmo_item() -> void:
	var inv := InventoryState.new().get_player(0)
	inv.slots.append(_slot("rabanete", 999))
	inv.slots.append(_slot("cenoura", 3))
	inv.slots.append(_slot("rabanete", 5))
	assert_eq(inv.count("rabanete"), 1004, "item espalhado em vários slots conta junto")

func test_count_de_item_ausente_e_zero() -> void:
	assert_eq(InventoryState.new().get_player(0).count("dragao"), 0)

func test_to_dict_tem_o_formato_do_save() -> void:
	var state := InventoryState.new()
	var inv := state.get_player(0)
	inv.slots.append(_slot("rabanete", 5))
	inv.dinheiro = 500

	var esperado := {
		"0": {
			"slots": [{"item_id": "rabanete", "qtd": 5}],
			"capacity": 24,
			"dinheiro": 500,
		}
	}
	assert_eq(state.to_dict(), esperado, "bate com o bloco inventory do GAMEPLAY.md")

func test_from_dict_carrega_tudo() -> void:
	var state := InventoryState.new()
	state.from_dict({
		"0": {"slots": [{"item_id": "cenoura", "qtd": 2}], "capacity": 8, "dinheiro": 90},
	})
	var inv := state.get_player(0)
	assert_eq(inv.slots.size(), 1)
	assert_eq(inv.slots[0].item_id, "cenoura")
	assert_eq(inv.slots[0].qtd, 2)
	assert_eq(inv.capacity, 8)
	assert_eq(inv.dinheiro, 90)

func test_from_dict_vazio_mantem_defaults() -> void:
	var state := InventoryState.new()
	state.get_player(0).dinheiro = 7
	state.from_dict({})
	assert_eq(state.player_ids(), [], "carregar save vazio limpa o que estava aí")
	assert_eq(state.get_player(0).dinheiro, 500, "e o player volta aos defaults")

func test_from_dict_parcial_usa_default_no_que_falta() -> void:
	var state := InventoryState.new()
	state.from_dict({"0": {"dinheiro": 10}})
	var inv := state.get_player(0)
	assert_eq(inv.dinheiro, 10, "o que veio no save vale")
	assert_eq(inv.capacity, 24, "campo ausente cai no default — sem migração")
	assert_eq(inv.slots, [], "sem slots no save, mochila vazia")

func test_round_trip_preserva_o_state() -> void:
	var original := InventoryState.new()
	var inv := original.get_player(0)
	inv.slots.append(_slot("rabanete", 999))
	inv.slots.append(_slot("abobora", 1))
	inv.dinheiro = 1234
	original.get_player(1).capacity = 8

	var carregado := InventoryState.new()
	carregado.from_dict(original.to_dict())

	assert_eq(carregado.to_dict(), original.to_dict(), "salvar e carregar não perde nada")
