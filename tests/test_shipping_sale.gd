extends GutTest

## A venda ao dormir: o caixote esvazia, vira linhas de resumo e um total.
##
## Preço é do `ItemDef` — fonte única. O `CropDef` aponta qual item a colheita
## vira; quanto esse item vale é assunto do item.
##
## O caixote roda antes de Farm e Time na ordem fixa: vender → crescer →
## calendário, a sequência do GAMEPLAY §3.

var _items: ItemCatalog
var _shipping: ShippingSystem

func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_item_def("rabanete", 35))
	_items.register(_item_def("cenoura", 65))
	_items.register(_item_def("enxada", 0))
	_shipping = ShippingSystem.new(ShippingState.new(), _items)

func _item_def(id: String, preco_venda: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.preco_venda = preco_venda
	return def

func _por_no_caixote(item_id: String, qtd: int) -> void:
	_shipping.get_state().add(item_id, qtd)

func _dormir(player_id: int = 0) -> Array[SimEvent]:
	var action := SleepAction.new()
	action.player_id = player_id
	return _shipping.handle(action)

func _venda(events: Array[SimEvent]) -> ItemsSoldEvent:
	for event in events:
		if event is ItemsSoldEvent:
			return event as ItemsSoldEvent
	return null


func test_dormir_esvazia_o_caixote() -> void:
	_por_no_caixote("rabanete", 3)
	_por_no_caixote("cenoura", 1)

	_dormir()

	assert_true(_shipping.get_state().is_empty(), "o caixote amanhece vazio")

func test_venda_gera_uma_linha_por_item() -> void:
	_por_no_caixote("rabanete", 3)
	_por_no_caixote("cenoura", 2)

	var event := _venda(_dormir())

	assert_not_null(event, "dormir com caixote cheio vende")
	assert_eq(event.linhas.size(), 2, "uma linha por item, como no resumo do dia")

func test_linha_carrega_qtd_preco_e_subtotal() -> void:
	_por_no_caixote("rabanete", 3)

	var linha := _venda(_dormir()).linhas[0]

	assert_eq(linha.item_id, "rabanete")
	assert_eq(linha.qtd, 3)
	assert_eq(linha.preco_unitario, 35, "preço do ItemDef")
	assert_eq(linha.subtotal, 105, "3 × 35 — game/ não multiplica nada")

func test_total_soma_os_subtotais() -> void:
	_por_no_caixote("rabanete", 3)
	_por_no_caixote("cenoura", 2)

	var event := _venda(_dormir())

	assert_eq(event.total, 235, "3×35 + 2×65")
	assert_eq(event.total_itens, 5, "unidades que saíram do caixote")

func test_linhas_saem_em_ordem_alfabetica() -> void:
	_por_no_caixote("rabanete", 1)
	_por_no_caixote("cenoura", 1)

	var event := _venda(_dormir())

	assert_eq(event.linhas[0].item_id, "cenoura", "a ordem do resumo é contrato")
	assert_eq(event.linhas[1].item_id, "rabanete")

func test_venda_sabe_de_quem_e_o_dinheiro() -> void:
	_por_no_caixote("rabanete", 1)

	var event := _venda(_dormir(7))

	assert_eq(event.player_id, 7, "quem dormiu recebe — co-op é problema de rede")

func test_caixote_vazio_nao_emite_venda() -> void:
	assert_eq(_dormir(), [], "sem mudança, sem evento")

func test_item_sem_definicao_ainda_aparece_no_resumo() -> void:
	_por_no_caixote("fantasma", 2)

	var event := _venda(_dormir())

	assert_eq(event.linhas.size(), 1, "o item saiu do caixote — some da tela seria pior")
	assert_eq(event.linhas[0].preco_unitario, 0, "id sem ItemDef não vale nada")
	assert_eq(event.total, 0)

func test_item_de_preco_zero_vende_por_zero() -> void:
	_por_no_caixote("enxada", 1)
	_por_no_caixote("rabanete", 1)

	var event := _venda(_dormir())

	assert_eq(event.total, 35, "ferramenta no caixote não vira dinheiro")
	assert_eq(event.linhas.size(), 2)

func test_dormir_duas_vezes_nao_vende_de_novo() -> void:
	_por_no_caixote("rabanete", 3)

	_dormir()

	assert_eq(_dormir(), [], "o que foi vendido não volta")

func test_deposito_do_dia_seguinte_vende_no_dia_seguinte() -> void:
	_por_no_caixote("rabanete", 1)
	_dormir()

	_por_no_caixote("cenoura", 1)
	var event := _venda(_dormir())

	assert_eq(event.total, 65, "cada noite vende só o que está no caixote")

func test_a_venda_vem_antes_do_dia_virar() -> void:
	var world := SimWorld.new()
	var farm := FarmSystem.new()
	var time := TimeSystem.new()
	world.register_system(_shipping)
	world.register_system(farm)
	world.register_system(time)
	_por_no_caixote("rabanete", 1)

	var events := world.handle(SleepAction.new())

	assert_not_null(events[0] as ItemsSoldEvent, "1. o caixote vende")
	assert_not_null(events[1] as DayEndedEvent, "3. o calendário avança")
