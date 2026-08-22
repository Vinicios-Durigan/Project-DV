extends GutTest

## O loop inteiro em cima das 4 culturas de verdade (`data/crops/*.tres`):
## arar → plantar → regar → dormir → colher, com o inventário na cadeia.
##
## Os números vêm da tabela do GAMEPLAY §5 e a fórmula-mestre é
## `lucro_por_dia = (venda × rende − semente) / dias_de_ciclo`.

var _world: SimWorld
var _crops: CropCatalog
var _items: ItemCatalog
var _inventory: InventorySystem
var _farm: FarmSystem
var _time: TimeSystem

func before_each() -> void:
	_crops = CropCatalog.new()
	_crops.load_from_dir()
	_items = ItemCatalog.new()
	_items.load_from_dir()
	_inventory = InventorySystem.new(InventoryState.new(), _items, _crops)
	_farm = FarmSystem.new(FarmState.new(), _crops)
	_time = TimeSystem.new()
	# Ordem fixa do tick: Inventory → Farm → Time. É ela que cobra a semente
	# antes de plantar e faz crescer antes do calendário virar.
	_world = SimWorld.new()
	_world.register_system(_inventory)
	_world.register_system(_farm)
	_world.register_system(_time)

## Quanto a colheita da cultura vale — o preço mora no `ItemDef`, nunca na cultura.
func _preco_venda(crop_id: String) -> int:
	return _items.get_def(_crops.get_def(crop_id).item_colheita_id()).preco_venda

func _lucro_por_dia(crop_id: String) -> float:
	var def := _crops.get_def(crop_id)
	return float(_preco_venda(crop_id) * def.rende_por_colheita - def.preco_semente) / float(def.dias_ate_pronta())

func _dar(item_id: String, qtd: int) -> void:
	var action := AddItemAction.new()
	action.item_id = item_id
	action.qtd = qtd
	_world.handle(action)

func _arar(x: int, y: int) -> Array[SimEvent]:
	var action := TillPlotAction.new()
	action.x = x
	action.y = y
	return _world.handle(action)

func _plantar(crop_id: String, x: int, y: int) -> Array[SimEvent]:
	var action := PlantCropAction.new()
	action.crop_id = crop_id
	action.item_id = _crops.get_def(crop_id).item_semente_id()
	action.x = x
	action.y = y
	return _world.handle(action)

func _regar(x: int, y: int) -> Array[SimEvent]:
	var action := WaterPlotAction.new()
	action.x = x
	action.y = y
	return _world.handle(action)

func _colher(x: int, y: int) -> Array[SimEvent]:
	var action := HarvestCropAction.new()
	action.x = x
	action.y = y
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


## O trigo entrou na wave 12: ele não é cultura de fazenda, é matéria-prima da
## cidade. O ciclo dele é testado em `test_cadeia_trigo.gd`, junto com a escada
## de valor que justifica a existência dele.
func test_as_culturas_do_slice_estao_no_catalogo() -> void:
	assert_eq(_crops.ids(), ["abobora", "cenoura", "morango", "rabanete", "trigo"],
		"as 4 culturas do slice + o trigo da cidade, carregadas de data/crops/")

func test_numeros_batem_com_a_tabela_do_gameplay() -> void:
	assert_eq(_crops.get_def("rabanete").dias_ate_pronta(), 4)
	assert_eq(_crops.get_def("rabanete").preco_semente, 20)
	assert_eq(_preco_venda("rabanete"), 35)

	assert_eq(_crops.get_def("cenoura").dias_ate_pronta(), 6)
	assert_eq(_crops.get_def("cenoura").preco_semente, 30)
	assert_eq(_preco_venda("cenoura"), 65)

	assert_eq(_crops.get_def("abobora").dias_ate_pronta(), 13)
	assert_eq(_crops.get_def("abobora").preco_semente, 80)
	assert_eq(_preco_venda("abobora"), 180)

	assert_eq(_crops.get_def("morango").dias_ate_pronta(), 8)
	assert_eq(_crops.get_def("morango").preco_semente, 60)
	assert_eq(_preco_venda("morango"), 45)
	assert_true(_crops.get_def("morango").colheitas_infinitas, "o morango rebrota")

func test_todas_tem_quatro_estagios_e_sprite_por_estagio() -> void:
	for id in _crops.ids():
		var def := _crops.get_def(id)
		assert_eq(def.total_estagios(), 4, "%s: semente, broto, crescendo, pronta" % id)
		assert_eq(def.sprites_estagios.size(), def.total_estagios(),
			"%s: um sprite por estágio na lista do artista" % id)
		assert_false(def.bloqueia_movimento, "%s: as 4 iniciais não bloqueiam passagem" % id)

func test_lucro_por_dia_bate_com_a_formula() -> void:
	assert_almost_eq(_lucro_por_dia("rabanete"), 3.75, 0.01, "rápida")
	assert_almost_eq(_lucro_por_dia("cenoura"), 5.83, 0.01, "média")
	assert_almost_eq(_lucro_por_dia("abobora"), 7.69, 0.01, "lenta")

func test_a_lenta_rende_o_dobro_da_rapida_por_dia() -> void:
	var razao := _lucro_por_dia("abobora") / _lucro_por_dia("rabanete")
	assert_almost_eq(razao, 2.0, 0.15, "regra de balanceamento: lenta ≈ 2× a rápida")

func test_ciclo_completo_do_rabanete() -> void:
	_dar("semente_rabanete", 5)

	_arar(2, 2)
	_plantar("rabanete", 2, 2)
	assert_eq(_mochila().count("semente_rabanete"), 4, "plantar cobra a semente na hora")

	_cuidar(2, 2, 3)
	assert_eq(_colher(2, 2), [], "no terceiro dia ainda está verde")

	_regar(2, 2)
	_dormir()
	var events := _colher(2, 2)

	assert_eq(_mochila().count("rabanete"), 1, "a colheita entrou na mochila sozinha")
	assert_eq(events.size(), 2, "colheita e entrada no inventário")
	assert_not_null(events[0] as CropHarvestedEvent, "primeiro o fato da fazenda")
	assert_not_null(events[1] as ItemAddedEvent, "depois a reação do inventário")
	assert_eq(_time.get_state().dia, 5, "4 noites de cuidado")

func test_plantar_sem_semente_e_barrado_antes_de_tocar_a_terra() -> void:
	_arar(2, 2)
	var events := _plantar("rabanete", 2, 2)

	assert_false(_farm.get_state().get_plot(2, 2).tem_cultura(), "sem semente, sem plantio")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "quem valida vem antes de quem executa")
	assert_eq(event.motivo, InventorySystem.MOTIVO_ITEM_INSUFICIENTE)

func test_esquecer_de_regar_atrasa_exatamente_um_dia() -> void:
	_dar("semente_rabanete", 1)
	_arar(2, 2)
	_plantar("rabanete", 2, 2)

	_dormir()
	_cuidar(2, 2, 4)

	assert_eq(_colher(2, 2).size(), 2, "o dia seco só empurrou a colheita para frente")
	assert_eq(_mochila().count("rabanete"), 1)

func test_morango_rebrota_a_cada_quatro_dias() -> void:
	_dar("semente_morango", 1)
	_arar(3, 3)
	_plantar("morango", 3, 3)

	_cuidar(3, 3, 8)
	var primeira := _colher(3, 3)
	assert_eq(_mochila().count("morango"), 1, "primeira colheita no oitavo dia")
	assert_true((primeira[0] as CropHarvestedEvent).rebrota)
	assert_true(_farm.get_state().get_plot(3, 3).tem_cultura(), "a planta fica no chão")

	_cuidar(3, 3, 3)
	assert_eq(_colher(3, 3), [], "três dias não bastam")

	_cuidar(3, 3, 1)
	_colher(3, 3)
	assert_eq(_mochila().count("morango"), 2, "segunda colheita quatro dias depois")

	assert_eq(_mochila().count("semente_morango"), 0, "uma semente só, duas colheitas")

func test_lucro_do_morango_cresce_quanto_antes_planta() -> void:
	var def := _crops.get_def("morango")
	var doze_dias := float(_preco_venda("morango") * 2 - def.preco_semente) / 12.0
	var vinte_dias := float(_preco_venda("morango") * 4 - def.preco_semente) / 20.0
	assert_true(vinte_dias > doze_dias, "cada rebrota dilui o custo da semente")

func test_fim_de_estacao_limpa_o_que_ficou_no_chao() -> void:
	_dar("semente_abobora", 1)
	_arar(4, 4)
	_plantar("abobora", 4, 4)
	_time.get_state().dia = 28

	_regar(4, 4)
	var events := _dormir()

	var morreu := false
	for event in events:
		if event is CropDiedEvent:
			morreu = true
			assert_eq((event as CropDiedEvent).crop_id, "abobora")
	assert_true(morreu, "abóbora de 13 dias não atravessa a virada da estação")
	assert_false(_farm.get_state().get_plot(4, 4).tem_cultura())
	assert_true(_farm.get_state().get_plot(4, 4).arada, "a terra continua arada para a estação nova")
	assert_eq(_time.get_state().dia, 1, "estação nova começa no dia 1")
