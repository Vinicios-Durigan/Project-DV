extends GutTest

## A outra metade do loop econômico: gastar.
##
## Comprar semente é 100% InventorySystem — ele já é o dono do dinheiro e da
## mochila, e o preço mora no `CropDef`, que é leitura livre. O caixote não
## participa: a "aba de compra" do painel é só UI.
##
## E o dinheiro da venda entra por reação ao `ItemsSoldEvent`: o caixote emite
## o fato, a carteira reage. Nenhum dos dois lê o state do outro.

var _crops: CropCatalog
var _items: ItemCatalog
var _state: InventoryState
var _system: InventorySystem

func before_each() -> void:
	_crops = CropCatalog.new()
	_crops.register(_crop_def("rabanete", 20))
	_crops.register(_crop_def("abobora", 80))
	_items = ItemCatalog.new()
	_state = InventoryState.new()
	_system = InventorySystem.new(_state, _items, _crops)

func _crop_def(id: String, preco_semente: int) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.preco_semente = preco_semente
	return def

func _comprar(crop_id: String, qtd: int = 1, player_id: int = 0) -> Array[SimEvent]:
	var action := BuySeedAction.new()
	action.player_id = player_id
	action.crop_id = crop_id
	action.qtd = qtd
	return _system.handle(action)

func _vender(total: int, player_id: int = 0) -> Array[SimEvent]:
	var event := ItemsSoldEvent.new()
	event.player_id = player_id
	event.total = total
	return _system.react(event)

func _inv(player_id: int = 0) -> InventoryState.PlayerInventory:
	return _state.get_player(player_id)


func test_comprar_semente_debita_e_entrega() -> void:
	_comprar("rabanete", 1)

	assert_eq(_inv().dinheiro, 480, "500 − 20")
	assert_eq(_inv().count("semente_rabanete"), 1, "a semente entrou na mochila")

func test_compra_emite_o_fato_antes_das_consequencias() -> void:
	var events := _comprar("rabanete", 1)

	assert_eq(events.size(), 3)
	assert_not_null(events[0] as SeedBoughtEvent, "a compra é a causa")
	assert_not_null(events[1] as MoneyChangedEvent, "o dinheiro saiu")
	assert_not_null(events[2] as ItemAddedEvent, "a semente entrou")

func test_evento_de_compra_carrega_o_recibo_inteiro() -> void:
	var event := _comprar("abobora", 2, 3)[0] as SeedBoughtEvent

	assert_eq(event.player_id, 3)
	assert_eq(event.crop_id, "abobora")
	assert_eq(event.item_id, "semente_abobora", "id do item, resolvido pela convenção")
	assert_eq(event.qtd, 2)
	assert_eq(event.preco_unitario, 80)
	assert_eq(event.custo_total, 160, "2 × 80 — game/ não multiplica nada")

func test_comprar_varias_cobra_o_lote_de_uma_vez() -> void:
	_comprar("rabanete", 5)

	assert_eq(_inv().dinheiro, 400, "500 − 5×20")
	assert_eq(_inv().count("semente_rabanete"), 5)

func test_semente_de_id_explicito_no_def_manda() -> void:
	var def := _crop_def("morango", 60)
	def.item_semente = "muda_morango"
	_crops.register(def)

	_comprar("morango", 1)

	assert_eq(_inv().count("muda_morango"), 1, "a convenção é fallback, não lei")

func test_sem_dinheiro_a_compra_e_rejeitada() -> void:
	_inv().dinheiro = 19

	var events := _comprar("rabanete", 1)

	assert_eq(_inv().dinheiro, 19, "não encosta no saldo")
	assert_eq(_inv().count("semente_rabanete"), 0, "nem na mochila")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event)
	assert_eq(event.acao, "BuySeedAction")
	assert_eq(event.motivo, InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE)

func test_dinheiro_exato_compra() -> void:
	_inv().dinheiro = 20

	_comprar("rabanete", 1)

	assert_eq(_inv().dinheiro, 0, "zerar pode; ficar negativo não")
	assert_eq(_inv().count("semente_rabanete"), 1)

func test_o_lote_inteiro_ou_nada() -> void:
	_inv().dinheiro = 50

	_comprar("rabanete", 3)

	assert_eq(_inv().dinheiro, 50, "60 não cabe em 50 — não compra 2")
	assert_eq(_inv().count("semente_rabanete"), 0)

func test_cultura_desconhecida_e_rejeitada() -> void:
	var events := _comprar("kiwi", 1)

	assert_eq(_inv().dinheiro, 500)
	assert_eq(events.size(), 1)
	assert_eq((events[0] as ActionRejectedEvent).motivo,
		InventorySystem.MOTIVO_CULTURA_DESCONHECIDA)

func test_quantidade_invalida_nao_faz_nada() -> void:
	assert_eq(_comprar("rabanete", 0), [], "zero não é compra")
	assert_eq(_comprar("rabanete", -2), [])
	assert_eq(_inv().dinheiro, 500)

func test_semente_de_graca_ainda_entrega() -> void:
	_crops.register(_crop_def("brinde", 0))

	_comprar("brinde", 1)

	assert_eq(_inv().dinheiro, 500, "custo zero não mexe no saldo")
	assert_eq(_inv().count("semente_brinde"), 1, "mas a semente vem")

func test_compra_ja_rejeitada_e_ignorada() -> void:
	var action := BuySeedAction.new()
	action.crop_id = "rabanete"
	action.rejeitada = true

	assert_eq(_system.handle(action), [], "sistema seguinte ignora ação rejeitada")
	assert_eq(_inv().dinheiro, 500)

func test_venda_do_caixote_vira_dinheiro() -> void:
	var events := _vender(235)

	assert_eq(_inv().dinheiro, 735, "500 + 235")
	assert_eq(events.size(), 1)
	var event := events[0] as MoneyChangedEvent
	assert_not_null(event, "a carteira reage ao fato do caixote")
	assert_eq(event.de, 500)
	assert_eq(event.para, 735)
	assert_eq(event.delta, 235)

func test_venda_paga_quem_dormiu() -> void:
	_vender(100, 2)

	assert_eq(_state.get_player(2).dinheiro, 600, "co-op: o dinheiro tem dono")
	assert_eq(_state.get_player(0).dinheiro, 500, "e não é de todo mundo")

func test_venda_de_total_zero_nao_mexe_na_carteira() -> void:
	assert_eq(_vender(0), [], "só ferramenta no caixote não vira MoneyChangedEvent")

func test_a_carteira_nao_reage_a_evento_alheio() -> void:
	assert_eq(_system.react(DayEndedEvent.new()), [], "só ItemsSoldEvent e item concedido")

func test_comprar_e_vender_fecham_o_ciclo() -> void:
	_comprar("rabanete", 5)
	assert_eq(_inv().dinheiro, 400)

	_vender(175)

	assert_eq(_inv().dinheiro, 575, "5 rabanetes a 35 cobrem as 5 sementes a 20 com folga")
