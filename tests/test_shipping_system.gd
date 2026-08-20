extends GutTest

## Depositar e retirar do caixote.
##
## Depositar é gastar o item: a `ShipItemAction` é uma `RemoveItemAction`, então
## o InventorySystem (primeiro da ordem fixa) cobra ou rejeita antes do caixote
## encostar em qualquer coisa.
##
## Retirar é o caminho de volta: o caixote valida e emite `ItemWithdrawnEvent`,
## que é um `ItemGrantedEvent` — a mochila reage sozinha, sem saber que existe
## caixote. Venda só concretiza ao dormir, então arrepender-se é permitido.

var _world: SimWorld
var _items: ItemCatalog
var _inventory: InventorySystem
var _shipping: ShippingSystem

func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_item_def("rabanete", 35))
	_items.register(_item_def("cenoura", 65))
	_inventory = InventorySystem.new(InventoryState.new(), _items)
	_shipping = ShippingSystem.new(ShippingState.new(), _items)
	# Ordem fixa: Inventory → Shipping. É ela que cobra o item antes de depositar.
	_world = SimWorld.new()
	_world.register_system(_inventory)
	_world.register_system(_shipping)

func _item_def(id: String, preco_venda: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.preco_venda = preco_venda
	return def

func _dar(item_id: String, qtd: int) -> void:
	var action := AddItemAction.new()
	action.item_id = item_id
	action.qtd = qtd
	_world.handle(action)

func _depositar(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := ShipItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _world.handle(action)

func _retirar(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := WithdrawItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _world.handle(action)

func _mochila() -> InventoryState.PlayerInventory:
	return _inventory.get_state().get_player(0)

func _caixote() -> ShippingState:
	return _shipping.get_state()

func _do_tipo(events: Array[SimEvent], tipo: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event in events:
		if event.get_script().get_global_name() == tipo:
			out.append(event)
	return out


func test_depositar_tira_da_mochila_e_poe_no_caixote() -> void:
	_dar("rabanete", 5)

	var events := _depositar("rabanete", 3)

	assert_eq(_mochila().count("rabanete"), 2, "saiu da mochila")
	assert_eq(_caixote().count("rabanete"), 3, "entrou no caixote")
	assert_eq(events.size(), 2, "a remoção e o depósito")
	assert_not_null(events[0] as ItemRemovedEvent, "primeiro quem cobra")
	assert_not_null(events[1] as ItemShippedEvent, "depois quem executa")

func test_evento_de_deposito_carrega_o_caixote_inteiro() -> void:
	_dar("rabanete", 5)
	_depositar("rabanete", 2)

	var events := _depositar("rabanete", 3, 0)
	var event := (_do_tipo(events, "ItemShippedEvent")[0]) as ItemShippedEvent

	assert_eq(event.player_id, 0)
	assert_eq(event.item_id, "rabanete")
	assert_eq(event.qtd, 3, "quanto entrou agora")
	assert_eq(event.total_apos, 5, "quanto o caixote tem — game/ não pergunta ao state")

func test_depositar_sem_ter_o_item_e_barrado_antes_do_caixote() -> void:
	var events := _depositar("rabanete", 1)

	assert_true(_caixote().is_empty(), "quem valida vem antes de quem executa")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "rejeição da cadeia")
	assert_eq(event.motivo, InventorySystem.MOTIVO_ITEM_INSUFICIENTE)

func test_depositar_parcialmente_nao_existe() -> void:
	_dar("rabanete", 2)

	_depositar("rabanete", 5)

	assert_eq(_mochila().count("rabanete"), 2, "tudo ou nada: a mochila não encolheu")
	assert_true(_caixote().is_empty())

func test_depositar_quantidade_invalida_nao_faz_nada() -> void:
	_dar("rabanete", 5)

	assert_eq(_depositar("rabanete", 0), [], "zero não é depósito")
	assert_true(_caixote().is_empty())
	assert_eq(_mochila().count("rabanete"), 5)

func test_dois_itens_diferentes_convivem_no_caixote() -> void:
	_dar("rabanete", 2)
	_dar("cenoura", 1)

	_depositar("rabanete", 2)
	_depositar("cenoura", 1)

	assert_eq(_caixote().item_ids(), ["cenoura", "rabanete"])
	assert_eq(_caixote().total_itens(), 3)

func test_retirar_devolve_o_item_para_a_mochila() -> void:
	_dar("rabanete", 5)
	_depositar("rabanete", 5)

	var events := _retirar("rabanete", 2)

	assert_eq(_caixote().count("rabanete"), 3, "saiu do caixote")
	assert_eq(_mochila().count("rabanete"), 2, "a mochila reagiu sozinha")
	assert_eq(events.size(), 2, "a retirada e a reação do inventário")
	assert_not_null(events[0] as ItemWithdrawnEvent, "primeiro o fato do caixote")
	assert_not_null(events[1] as ItemAddedEvent, "depois a reação da mochila")

func test_retirada_e_um_item_concedido() -> void:
	_dar("rabanete", 3)
	_depositar("rabanete", 3)

	var events := _retirar("rabanete", 3)
	var event := events[0] as ItemWithdrawnEvent

	assert_not_null(event as ItemGrantedEvent,
		"é um ItemGrantedEvent — a mochila não conhece o caixote")
	assert_eq(event.player_id, 0)
	assert_eq(event.item_id, "rabanete")
	assert_eq(event.qtd, 3)
	assert_eq(event.total_apos, 0, "o caixote ficou vazio")

func test_retirar_o_que_nao_esta_no_caixote_e_rejeitado() -> void:
	var events := _retirar("rabanete", 1)

	assert_eq(_mochila().count("rabanete"), 0, "nada apareceu do nada")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event)
	assert_eq(event.acao, "WithdrawItemAction")
	assert_eq(event.motivo, ShippingSystem.MOTIVO_ITEM_INSUFICIENTE)

func test_retirar_mais_do_que_tem_nao_leva_nada() -> void:
	_dar("rabanete", 2)
	_depositar("rabanete", 2)

	_retirar("rabanete", 5)

	assert_eq(_caixote().count("rabanete"), 2, "tudo ou nada também na volta")
	assert_eq(_mochila().count("rabanete"), 0)

func test_depositar_e_arrepender_volta_ao_ponto_de_partida() -> void:
	_dar("rabanete", 4)

	_depositar("rabanete", 4)
	_retirar("rabanete", 4)

	assert_eq(_mochila().count("rabanete"), 4, "a venda só concretiza ao dormir")
	assert_true(_caixote().is_empty())

func test_acao_ja_rejeitada_nao_chega_no_caixote() -> void:
	var action := ShipItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 1
	action.rejeitada = true

	assert_eq(_shipping.handle(action), [], "sistema seguinte ignora ação rejeitada")
	assert_true(_caixote().is_empty())

func test_acao_desconhecida_nao_move_o_caixote() -> void:
	assert_eq(_shipping.handle(TillPlotAction.new()), [], "quem não reconhece devolve []")

func test_caixote_nao_faz_nada_no_tick() -> void:
	assert_eq(_shipping.tick(), [], "vender é na virada do dia, não a cada minuto")
