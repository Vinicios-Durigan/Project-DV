extends GutTest

## Ações formais de inventário: stack, capacity, item perdido, dinheiro e a
## validação em cadeia.

var _state: InventoryState
var _catalog: ItemCatalog
var _system: InventorySystem

func before_each() -> void:
	_state = InventoryState.new()
	_catalog = ItemCatalog.new()
	_catalog.register(_def("rabanete", 999))
	_catalog.register(_def("enxada", 1))
	_system = InventorySystem.new(_state, _catalog)

func _def(id: String, stack_max: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.stack_max = stack_max
	return def

func _add(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := AddItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _system.handle(action)

func _remove(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := RemoveItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _system.handle(action)

func _money(valor: int, player_id: int = 0) -> Array[SimEvent]:
	var action := AddMoneyAction.new()
	action.player_id = player_id
	action.valor = valor
	return _system.handle(action)

func _inv(player_id: int = 0) -> InventoryState.PlayerInventory:
	return _state.get_player(player_id)


func test_ganhar_item_abre_slot_e_avisa() -> void:
	var events := _add("rabanete", 3)

	assert_eq(_inv().count("rabanete"), 3, "o item entrou")
	assert_eq(_inv().slots.size(), 1, "um stack só")
	assert_eq(events.size(), 1)
	var event := events[0] as ItemAddedEvent
	assert_not_null(event, "emite ItemAddedEvent")
	assert_eq(event.item_id, "rabanete")
	assert_eq(event.qtd, 3, "quanto entrou")
	assert_eq(event.total_apos, 3, "quanto o jogador tem agora — game/ não precisa perguntar")
	assert_eq(event.player_id, 0)

func test_item_repetido_empilha_no_slot_existente() -> void:
	_add("rabanete", 3)
	_add("rabanete", 4)
	assert_eq(_inv().slots.size(), 1, "não abre slot novo à toa")
	assert_eq(_inv().count("rabanete"), 7)

func test_passar_do_stack_max_abre_outro_slot() -> void:
	_add("enxada", 2)
	assert_eq(_inv().slots.size(), 2, "ferramenta é stack 1: dois slots")
	assert_eq(_inv().count("enxada"), 2)

func test_stack_max_desconhecido_cai_no_padrao() -> void:
	_add("dragao", 999)
	assert_eq(_inv().slots.size(), 1, "sem definição no catálogo, stack padrão 999")

func test_ganhar_quantidade_invalida_nao_faz_nada() -> void:
	assert_eq(_add("rabanete", 0), [], "sem mudança, sem evento")
	assert_eq(_add("rabanete", -5), [], "quantidade negativa é ignorada")
	assert_eq(_inv().slots.size(), 0)

func test_inventario_cheio_perde_a_sobra() -> void:
	_inv().capacity = 1
	_add("rabanete", 995)

	var events := _add("rabanete", 10)

	assert_eq(_inv().count("rabanete"), 999, "encheu o stack até o limite")
	assert_eq(events.size(), 2, "o que coube entrou, o resto se perdeu")
	assert_eq((events[0] as ItemAddedEvent).qtd, 4)
	var perdido := events[1] as ItemLostEvent
	assert_not_null(perdido, "emite ItemLostEvent")
	assert_eq(perdido.qtd, 6, "a sobra que não coube")
	assert_eq(perdido.item_id, "rabanete")

func test_sem_espaco_nenhum_o_item_todo_se_perde() -> void:
	_inv().capacity = 1
	_add("rabanete", 999)

	var events := _add("rabanete", 5)

	assert_eq(events.size(), 1, "nada entrou: só o aviso de perda")
	assert_not_null(events[0] as ItemLostEvent)
	assert_eq((events[0] as ItemLostEvent).qtd, 5)

func test_perder_item_nao_rejeita_a_acao() -> void:
	_inv().capacity = 1
	_add("rabanete", 999)
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5
	_system.handle(action)
	assert_false(action.rejeitada, "o item se perdeu, mas a ação aconteceu")

func test_gastar_item_tira_e_avisa() -> void:
	_add("rabanete", 10)

	var events := _remove("rabanete", 4)

	assert_eq(_inv().count("rabanete"), 6)
	var event := events[0] as ItemRemovedEvent
	assert_not_null(event, "emite ItemRemovedEvent")
	assert_eq(event.qtd, 4)
	assert_eq(event.total_apos, 6)

func test_gastar_consome_varios_slots_e_limpa_os_vazios() -> void:
	_add("enxada", 3)
	assert_eq(_inv().slots.size(), 3)

	_remove("enxada", 2)

	assert_eq(_inv().count("enxada"), 1)
	assert_eq(_inv().slots.size(), 1, "slot vazio não fica ocupando lugar")

func test_gastar_o_que_nao_tem_rejeita_a_acao() -> void:
	_add("rabanete", 2)
	var action := RemoveItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5

	var events := _system.handle(action)

	assert_true(action.rejeitada, "quem detecta a impossibilidade marca a flag")
	assert_eq(_inv().count("rabanete"), 2, "nada foi tirado — ninguém desfaz nada")
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "emite ActionRejectedEvent")
	assert_eq(event.motivo, InventorySystem.MOTIVO_ITEM_INSUFICIENTE)
	assert_eq(event.acao, "RemoveItemAction", "o evento diz qual ação caiu")

func test_ganhar_dinheiro_avisa_a_transicao() -> void:
	var events := _money(250)

	assert_eq(_inv().dinheiro, 750)
	var event := events[0] as MoneyChangedEvent
	assert_not_null(event, "emite MoneyChangedEvent")
	assert_eq(event.de, 500)
	assert_eq(event.para, 750)
	assert_eq(event.delta, 250)

func test_gastar_dinheiro_e_a_mesma_acao_com_valor_negativo() -> void:
	var events := _money(-200)
	assert_eq(_inv().dinheiro, 300)
	assert_eq((events[0] as MoneyChangedEvent).delta, -200)

func test_gastar_mais_do_que_tem_rejeita_a_acao() -> void:
	var action := AddMoneyAction.new()
	action.valor = -501

	var events := _system.handle(action)

	assert_true(action.rejeitada)
	assert_eq(_inv().dinheiro, 500, "dinheiro intacto")
	assert_eq((events[0] as ActionRejectedEvent).motivo, InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE)

func test_gastar_tudo_e_permitido() -> void:
	_money(-500)
	assert_eq(_inv().dinheiro, 0, "zerar pode; negativo não")

func test_valor_zero_nao_faz_nada() -> void:
	assert_eq(_money(0), [], "sem mudança, sem evento")

func test_acao_ja_rejeitada_e_ignorada() -> void:
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5
	action.rejeitada = true

	assert_eq(_system.handle(action), [], "sistema seguinte ignora ação rejeitada")
	assert_eq(_inv().count("rabanete"), 0, "e não mexe no state")

func test_acao_desconhecida_e_ignorada() -> void:
	assert_eq(_system.handle(SimAction.new()), [], "quem não reconhece devolve []")

func test_cada_player_mexe_no_proprio_inventario() -> void:
	_add("rabanete", 5, 1)
	assert_eq(_inv(1).count("rabanete"), 5)
	assert_eq(_inv(0).count("rabanete"), 0, "co-op: ação carrega o dono")

func test_sistema_nasce_com_state_e_catalogo_proprios() -> void:
	var solo := InventorySystem.new()
	assert_eq(solo.get_state().get_player(0).dinheiro, 500, "sem state injetado, cria o próprio")

func test_roda_dentro_do_sim_world() -> void:
	var world := SimWorld.new()
	world.register_system(_system)
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 2

	var events := world.handle(action)

	assert_eq(events.size(), 1, "o evento sai pela fila do mundo")
	assert_not_null(events[0] as ItemAddedEvent)
