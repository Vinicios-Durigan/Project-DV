extends GutTest

## Fonte única de preço: quem paga é o `ItemDef`, nunca a cultura.
##
## O caixote vende **itens** — peixe e minério futuros entram por aqui sem que
## ninguém mexa no sistema. A cultura só diz qual item a colheita vira; quanto
## esse item vale é assunto do item.
##
## Este teste roda em cima dos `.tres` de verdade (`data/items/`, `data/crops/`):
## é ele que percebe cultura nova entrando sem item, ou item ficando sem preço.

## Metade do preço de compra, como no gênero: errar a compra dói pela metade,
## e revender semente nunca vira torneira de dinheiro.
const DIVISOR_REVENDA_SEMENTE: int = 2

var _items: ItemCatalog
var _crops: CropCatalog


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.load_from_dir()
	_crops = CropCatalog.new()
	_crops.load_from_dir()


func test_catalogo_de_itens_carrega_do_disco() -> void:
	assert_eq(_items.size(), 8, "4 colheitas + 4 sementes em data/items/")

func test_toda_cultura_tem_item_de_colheita_com_preco() -> void:
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		var def := _items.get_def(crop.item_colheita_id())
		assert_not_null(def, "%s: a colheita tem ItemDef" % crop_id)
		assert_gt(def.preco_venda, 0, "%s: colheita sem preço é cultura sem sentido" % crop_id)

func test_toda_cultura_tem_item_de_semente_com_preco() -> void:
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		var def := _items.get_def(crop.item_semente_id())
		assert_not_null(def, "%s: a semente tem ItemDef" % crop_id)
		assert_gt(def.preco_venda, 0, "%s: semente sobrando volta dinheiro" % crop_id)

func test_todo_item_tem_nome_para_a_tela() -> void:
	for item_id in _items.ids():
		assert_false(_items.get_def(item_id).nome.is_empty(), "%s: sem nome não dá para mostrar" % item_id)

func test_precos_de_colheita_batem_com_a_tabela_do_gameplay() -> void:
	assert_eq(_items.get_def("rabanete").preco_venda, 35, "rápida")
	assert_eq(_items.get_def("cenoura").preco_venda, 65, "média")
	assert_eq(_items.get_def("abobora").preco_venda, 180, "lenta")
	assert_eq(_items.get_def("morango").preco_venda, 45, "rebrota")

func test_semente_revende_pela_metade_do_que_custou() -> void:
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		var def := _items.get_def(crop.item_semente_id())
		assert_eq(def.preco_venda, crop.preco_semente / DIVISOR_REVENDA_SEMENTE,
			"%s: revenda é metade da compra" % crop_id)

func test_semente_nunca_vale_mais_que_a_colheita() -> void:
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		var semente := _items.get_def(crop.item_semente_id())
		var colheita := _items.get_def(crop.item_colheita_id())
		assert_lt(semente.preco_venda, colheita.preco_venda,
			"%s: plantar tem que pagar melhor que revender" % crop_id)

func test_ids_do_catalogo_sao_exatamente_os_das_culturas() -> void:
	var esperados: Array[String] = []
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		esperados.append(crop.item_colheita_id())
		esperados.append(crop.item_semente_id())
	esperados.sort()
	assert_eq(_items.ids(), esperados, "nenhum item órfão, nenhuma cultura sem item")

func test_preco_de_venda_nao_mora_mais_na_cultura() -> void:
	var campos: Array[String] = []
	for prop: Dictionary in CropDef.new().get_property_list():
		campos.append(String(prop["name"]))
	assert_does_not_have(campos, "preco_venda",
		"fonte única: quem tem preço de venda é o item, não a cultura")
	assert_has(campos, "preco_semente", "o custo da semente continua sendo da cultura")
