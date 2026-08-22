extends GutTest

## Inventário por player_id: slots, capacity, dinheiro e o bloco do save.

func _slot(item_id: String, qtd: int) -> InventoryState.Slot:
	return InventoryState.Slot.new(item_id, qtd)


func test_player_nasce_com_os_defaults_do_slice() -> void:
	var inv := InventoryState.new().get_player(0)
	assert_eq(inv.ocupados(), 0, "mochila vazia")
	assert_eq(inv.capacity, 24, "24 slots")
	assert_eq(inv.slots.size(), 24, "e um endereço para cada um")
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
	inv.slots[0] = _slot("rabanete", 999)
	inv.slots[1] = _slot("cenoura", 3)
	inv.slots[2] = _slot("rabanete", 5)
	assert_eq(inv.count("rabanete"), 1004, "item espalhado em vários slots conta junto")

func test_count_de_item_ausente_e_zero() -> void:
	assert_eq(InventoryState.new().get_player(0).count("dragao"), 0)

## O bloco `inventory` do save. Desde a wave 11.3 ele grava **um slot por
## capacidade**, vazios inclusive: sem o buraco no arquivo, reabrir o jogo
## empurraria todo mundo para a esquerda e a mão mudaria de item sozinha.
func test_to_dict_tem_o_formato_do_save() -> void:
	# Mochila de 2 slots, montada pelo save: `garante_tamanho` só cresce, então
	# não dá para encolher uma mochila que já nasceu com 24. Encolher jogaria
	# item fora, e perder item calado é pior que uma mochila maior do que devia.
	var state := InventoryState.new()
	state.from_dict({"0": {"slots": [], "capacity": 2, "dinheiro": 500}})
	var inv := state.get_player(0)
	inv.slots[1] = _slot("rabanete", 5)

	var esperado := {
		"0": {
			"slots": [
				{"item_id": "", "qtd": 0},
				{"item_id": "rabanete", "qtd": 5},
			],
			"capacity": 2,
			"dinheiro": 500,
			"slot_na_mao": 0,
		}
	}
	# Comparação por texto: `to_dict` devolve `Array[Dictionary]` e o literal do
	# teste é `Array` solto — iguais no conteúdo, diferentes no tipo.
	assert_eq(JSON.stringify(state.to_dict()), JSON.stringify(esperado),
		"bate com o bloco inventory do GAMEPLAY.md")

# --- Slot com endereço (wave 11.3) ---

## O slot passou a ter endereço fixo. Sem isso, "pôr o morango no slot 3" não
## existe: o 3 só existiria se o 2 estivesse cheio.
func test_a_mochila_nasce_com_um_slot_por_capacidade() -> void:
	var inv := InventoryState.new().get_player(0)
	assert_eq(inv.slots.size(), inv.capacity, "um endereço por slot, desde o começo")
	for slot in inv.slots:
		assert_true(slot.vazio(), "mochila nova nasce vazia")

func test_slot_vazio_nao_conta_como_item() -> void:
	var inv := InventoryState.new().get_player(0)
	assert_eq(inv.count(""), 0, "posição vazia não é um item chamado string vazia")

## Este é o bug que a wave 11.2 criou sem ninguém ver: a mão virou um índice, e
## a lista compacta deslizava quando um stack acabava — a mão passava a segurar
## outra coisa sozinha.
func test_esvaziar_um_slot_nao_desloca_os_outros() -> void:
	var inv := InventoryState.new().get_player(0)
	inv.slots[0] = _slot("enxada", 1)
	inv.slots[1] = _slot("morango", 1)

	inv.slots[0] = _slot("", 0)

	assert_eq(inv.slots[1].item_id, "morango", "o vizinho andou de endereço")

## Save antigo tinha lista compacta e mais curta que a capacidade. Lida
## posicionalmente, ela cai nas primeiras posições — que é onde os itens
## estavam. É por isso que esta mudança não precisou de migração.
func test_save_antigo_com_lista_curta_completa_ate_a_capacidade() -> void:
	var state := InventoryState.new()
	state.from_dict({
		"0": {"slots": [{"item_id": "morango", "qtd": 5}], "capacity": 24, "dinheiro": 90},
	})
	var inv := state.get_player(0)

	assert_eq(inv.slots.size(), 24, "a lista curta foi completada")
	assert_eq(inv.slots[0].item_id, "morango", "o item continua onde estava")
	assert_true(inv.slots[1].vazio(), "o resto nasce vazio")

func test_o_save_guarda_a_posicao_vazia() -> void:
	# Sem gravar o buraco, reabrir o jogo empurraria todo mundo para a esquerda.
	var state := InventoryState.new()
	var inv := state.get_player(0)
	inv.slots[2] = _slot("morango", 5)

	var slots: Array = state.to_dict()["0"]["slots"]
	assert_eq(String(slots[0]["item_id"]), "", "o slot 0 tem que ir vazio para o arquivo")
	assert_eq(String(slots[2]["item_id"]), "morango", "e o morango no endereço dele")

func test_round_trip_preserva_os_buracos() -> void:
	var original := InventoryState.new()
	original.get_player(0).slots[5] = _slot("abobora", 2)

	var carregado := InventoryState.new()
	carregado.from_dict(original.to_dict())

	assert_eq(carregado.get_player(0).slots[5].item_id, "abobora", "o endereço não sobreviveu")


## O que está na mão é estado de jogo: decide o que a ação "usar" faz. Fora do
## save, o jogador reabriria a partida de mãos vazias sem saber por quê.
func test_o_slot_na_mao_entra_no_save() -> void:
	var state := InventoryState.new()
	state.get_player(0).slot_na_mao = 3
	assert_eq(int(state.to_dict()["0"]["slot_na_mao"]), 3)

## O default é o primeiro slot, e ele descreve corretamente o mundo antes deste
## campo existir: save antigo carrega com a mão no slot 0, que é onde a
## `SimFactory` põe a enxada.
func test_save_antigo_carrega_com_a_mao_no_primeiro_slot() -> void:
	var state := InventoryState.new()
	state.from_dict({
		"0": {"slots": [{"item_id": "cenoura", "qtd": 2}], "capacity": 24, "dinheiro": 90},
	})
	assert_eq(state.get_player(0).slot_na_mao, 0,
		"campo ausente cai no default — sem migração")

func test_from_dict_carrega_tudo() -> void:
	var state := InventoryState.new()
	state.from_dict({
		"0": {"slots": [{"item_id": "cenoura", "qtd": 2}], "capacity": 8, "dinheiro": 90},
	})
	var inv := state.get_player(0)
	assert_eq(inv.slots.size(), 8, "a lista é completada até a capacidade do save")
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
	assert_eq(inv.ocupados(), 0, "sem slots no save, mochila vazia")

func test_round_trip_preserva_o_state() -> void:
	var original := InventoryState.new()
	var inv := original.get_player(0)
	inv.slots[0] = _slot("rabanete", 999)
	inv.slots[3] = _slot("abobora", 1)
	inv.dinheiro = 1234
	original.get_player(1).capacity = 8

	var carregado := InventoryState.new()
	carregado.from_dict(original.to_dict())

	assert_eq(carregado.to_dict(), original.to_dict(), "salvar e carregar não perde nada")
