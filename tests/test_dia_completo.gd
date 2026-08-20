extends GutTest

## O loop econômico inteiro numa sim só, com as culturas de verdade
## (`data/crops/*.tres`): comprar semente → arar → plantar → regar → dormir →
## colher → depositar → dormir → dinheiro na conta.
##
## É a prova da ordem fixa **Inventory → Shipping → Farm → Time**:
##
## - Inventory antes de tudo: cobra a semente e o preço da compra, ou rejeita.
## - Shipping antes de Farm e Time: vender vem antes de crescer, que vem antes
##   do calendário virar (GAMEPLAY §3).
##
## Preço de venda é do `ItemDef` — fonte única. O `CropDef` diz qual item a
## colheita vira; quanto esse item vale é assunto do item. Aqui os `ItemDef`
## nascem do catálogo de culturas, que é o que o `data/items/` vai gravar.

var _world: SimWorld
var _crops: CropCatalog
var _items: ItemCatalog
var _inventory: InventorySystem
var _shipping: ShippingSystem
var _farm: FarmSystem
var _time: TimeSystem

func before_each() -> void:
	_crops = CropCatalog.new()
	_crops.load_from_dir()
	_items = ItemCatalog.new()
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		_items.register(_item_def(crop.item_colheita_id(), crop.preco_venda))
		_items.register(_item_def(crop.item_semente_id(), 0))

	_inventory = InventorySystem.new(InventoryState.new(), _items, _crops)
	_shipping = ShippingSystem.new(ShippingState.new(), _items)
	_farm = FarmSystem.new(FarmState.new(), _crops)
	_time = TimeSystem.new()
	# A ordem é regra de jogo: validar → vender → crescer → virar o dia.
	_world = SimWorld.new()
	_world.register_system(_inventory)
	_world.register_system(_shipping)
	_world.register_system(_farm)
	_world.register_system(_time)

func _item_def(id: String, preco_venda: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.preco_venda = preco_venda
	return def

func _comprar(crop_id: String, qtd: int) -> Array[SimEvent]:
	var action := BuySeedAction.new()
	action.crop_id = crop_id
	action.qtd = qtd
	return _world.handle(action)

func _arar(x: int, y: int) -> void:
	var action := TillPlotAction.new()
	action.x = x
	action.y = y
	_world.handle(action)

func _plantar(crop_id: String, x: int, y: int) -> void:
	var action := PlantCropAction.new()
	action.crop_id = crop_id
	action.item_id = _crops.get_def(crop_id).item_semente_id()
	action.x = x
	action.y = y
	_world.handle(action)

func _regar(x: int, y: int) -> void:
	var action := WaterPlotAction.new()
	action.x = x
	action.y = y
	_world.handle(action)

func _colher(x: int, y: int) -> void:
	var action := HarvestCropAction.new()
	action.x = x
	action.y = y
	_world.handle(action)

func _depositar(item_id: String, qtd: int) -> Array[SimEvent]:
	var action := ShipItemAction.new()
	action.item_id = item_id
	action.qtd = qtd
	return _world.handle(action)

func _retirar(item_id: String, qtd: int) -> Array[SimEvent]:
	var action := WithdrawItemAction.new()
	action.item_id = item_id
	action.qtd = qtd
	return _world.handle(action)

func _dormir() -> Array[SimEvent]:
	return _world.handle(SleepAction.new())

## Rega e dorme `dias` vezes seguidas.
func _cuidar(x: int, y: int, dias: int) -> void:
	for _i in dias:
		_regar(x, y)
		_dormir()

func _mochila() -> InventoryState.PlayerInventory:
	return _inventory.get_state().get_player(0)

func _dinheiro() -> int:
	return _mochila().dinheiro

func _venda(events: Array[SimEvent]) -> ItemsSoldEvent:
	for event in events:
		if event is ItemsSoldEvent:
			return event as ItemsSoldEvent
	return null


func test_um_rabanete_do_zero_ao_dinheiro() -> void:
	assert_eq(_dinheiro(), 500, "500g de início, GAMEPLAY §5")

	_comprar("rabanete", 1)
	assert_eq(_dinheiro(), 480, "a semente custou 20")

	_arar(2, 2)
	_plantar("rabanete", 2, 2)
	assert_eq(_mochila().count("semente_rabanete"), 0, "plantar cobra a semente na hora")

	_cuidar(2, 2, 4)
	_colher(2, 2)
	assert_eq(_mochila().count("rabanete"), 1, "a colheita entrou sozinha na mochila")

	_depositar("rabanete", 1)
	assert_eq(_mochila().count("rabanete"), 0, "saiu da mochila")
	assert_eq(_dinheiro(), 480, "depositar não é vender — o dinheiro não mudou")

	_dormir()
	assert_eq(_dinheiro(), 515, "480 + 35: o lucro do ciclo é venda − semente")
	assert_eq(_time.get_state().dia, 6, "4 noites de cuidado + a noite da venda")

## Uma noite que faz as três coisas de uma vez: vende um rabanete colhido e
## ainda deixa uma cenoura crescendo no tile ao lado.
func test_a_ordem_da_sequencia_de_dormir_sai_no_evento() -> void:
	_mochila().dinheiro = 1000
	_comprar("rabanete", 1)
	_comprar("cenoura", 1)
	_arar(1, 1)
	_arar(2, 1)
	_plantar("rabanete", 1, 1)
	_plantar("cenoura", 2, 1)

	for _i in 5:
		_regar(1, 1)
		_regar(2, 1)
		_dormir()
	_colher(1, 1)
	_depositar("rabanete", 1)
	_regar(2, 1)

	var events := _dormir()

	assert_not_null(events[0] as ItemsSoldEvent, "1. o caixote vende, antes de tudo")

	var indice_dia := -1
	var indice_cresceu := -1
	for i in events.size():
		if events[i] is DayEndedEvent:
			indice_dia = i
		if events[i] is CropGrewEvent and indice_cresceu < 0:
			indice_cresceu = i
	assert_gt(indice_dia, 0, "3. o calendário avança depois da venda")
	assert_gt(indice_cresceu, indice_dia,
		"2. a cascata da manhã é reação da virada do dia")

func test_o_dinheiro_da_venda_chega_por_reacao() -> void:
	_comprar("rabanete", 1)
	_arar(1, 1)
	_plantar("rabanete", 1, 1)
	_cuidar(1, 1, 4)
	_colher(1, 1)
	_depositar("rabanete", 1)

	var events := _dormir()
	var venda := _venda(events)
	var recebeu: MoneyChangedEvent = null
	for event in events:
		if event is MoneyChangedEvent:
			recebeu = event as MoneyChangedEvent

	assert_eq(venda.total, 35)
	assert_not_null(recebeu, "a carteira reage ao fato do caixote")
	assert_eq(recebeu.delta, venda.total, "o total do resumo é exatamente o que entrou")
	assert_eq(recebeu.para, _dinheiro())

func test_resumo_do_dia_tem_uma_linha_por_cultura() -> void:
	_mochila().dinheiro = 1000
	_comprar("rabanete", 1)
	_comprar("cenoura", 1)
	_arar(1, 1)
	_arar(2, 1)
	_plantar("rabanete", 1, 1)
	_plantar("cenoura", 2, 1)

	for _i in 6:
		_regar(1, 1)
		_regar(2, 1)
		_dormir()
	_colher(1, 1)
	_colher(2, 1)
	_depositar("rabanete", 1)
	_depositar("cenoura", 1)

	var venda := _venda(_dormir())

	assert_eq(venda.linhas.size(), 2, "uma linha por item")
	assert_eq(venda.linhas[0].item_id, "cenoura", "linhas em ordem alfabética")
	assert_eq(venda.linhas[0].subtotal, 65)
	assert_eq(venda.linhas[1].item_id, "rabanete")
	assert_eq(venda.linhas[1].subtotal, 35)
	assert_eq(venda.total, 100, "o total do resumo")
	assert_eq(venda.total_itens, 2)

func test_arrependeu_antes_de_dormir_e_nao_perde_nada() -> void:
	_comprar("rabanete", 1)
	_arar(3, 3)
	_plantar("rabanete", 3, 3)
	_cuidar(3, 3, 4)
	_colher(3, 3)

	_depositar("rabanete", 1)
	_retirar("rabanete", 1)
	_dormir()

	assert_eq(_dinheiro(), 480, "nada foi vendido")
	assert_eq(_mochila().count("rabanete"), 1, "o rabanete voltou para a mochila")

func test_comprar_sem_dinheiro_nao_derruba_o_loop() -> void:
	_mochila().dinheiro = 10

	var events := _comprar("abobora", 1)
	_arar(4, 4)
	_plantar("abobora", 4, 4)

	assert_eq((events[0] as ActionRejectedEvent).motivo,
		InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE)
	assert_eq(_dinheiro(), 10, "o saldo não mexeu")
	assert_false(_farm.get_state().get_plot(4, 4).tem_cultura(),
		"sem semente comprada, sem plantio")

func test_reinvestir_o_lucro_faz_a_fazenda_crescer() -> void:
	_comprar("rabanete", 5)
	assert_eq(_dinheiro(), 400, "500 − 5×20")

	for i in 5:
		_arar(i, 5)
		_plantar("rabanete", i, 5)
	for _dia in 4:
		for i in 5:
			_regar(i, 5)
		_dormir()
	for i in 5:
		_colher(i, 5)
	_depositar("rabanete", 5)

	var venda := _venda(_dormir())

	assert_eq(venda.linhas[0].qtd, 5, "os 5 na mesma linha")
	assert_eq(venda.total, 175, "5 × 35")
	assert_eq(_dinheiro(), 575, "400 + 175 — o lucro de 15 por tile, cinco vezes")

func test_o_morango_paga_a_semente_uma_vez_e_rende_duas() -> void:
	_comprar("morango", 1)
	assert_eq(_dinheiro(), 440, "500 − 60")

	_arar(6, 6)
	_plantar("morango", 6, 6)
	_cuidar(6, 6, 8)
	_colher(6, 6)
	_depositar("morango", 1)
	_dormir()
	assert_eq(_dinheiro(), 485, "440 + 45: ainda no prejuízo de 15")

	_cuidar(6, 6, 4)
	_colher(6, 6)
	_depositar("morango", 1)
	_dormir()

	assert_eq(_dinheiro(), 530, "a rebrota do quarto dia virou lucro sem semente nova")
	assert_eq(_mochila().count("semente_morango"), 0, "uma semente só")

func test_caixote_atravessa_a_noite_vazio_sem_reclamar() -> void:
	_comprar("rabanete", 1)
	_arar(2, 2)
	_plantar("rabanete", 2, 2)

	_regar(2, 2)
	var events := _dormir()

	assert_null(_venda(events), "noite sem depósito não gera resumo de venda")
	assert_eq(_dinheiro(), 480)
