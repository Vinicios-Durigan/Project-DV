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
	assert_eq(_items.size(), 14,
		"5 colheitas + 5 sementes + farinha e pão + enxada e regador")

## Ferramenta é item, e não um resource paralelo (GAMEPLAY §4: "ferramentas e
## sementes ocupam slots"). O que a distingue é um campo: o que ela faz quando
## usada. O `ToolDef` previsto no §10 morreu nesta wave — ele duplicaria id,
## nome e ícone para acrescentar essa única linha.
func test_ferramenta_e_item_com_acao_de_uso() -> void:
	for id in ["enxada", "regador"]:
		var def := _items.get_def(id)
		assert_not_null(def, "%s: ferramenta sem ItemDef não cabe na mochila" % id)
		assert_false(def.acao_de_uso.is_empty(), "%s: ferramenta que não faz nada" % id)
		assert_eq(def.stack_max, 1, "%s: ferramenta não empilha" % id)

func test_a_enxada_ara_e_o_regador_rega() -> void:
	assert_eq(_items.get_def("enxada").acao_de_uso, ItemDef.ACAO_ARAR)
	assert_eq(_items.get_def("regador").acao_de_uso, ItemDef.ACAO_REGAR)

func test_ferramenta_nao_se_vende() -> void:
	# Preço 0 é "item que não se vende". Ferramenta no caixote virando dinheiro
	# seria uma torneira: elas são de graça na entrega inicial.
	for id in ["enxada", "regador"]:
		assert_eq(_items.get_def(id).preco_venda, 0,
			"%s: ferramenta com preço vira torneira de dinheiro" % id)

func test_item_comum_nao_faz_nada_ao_ser_usado() -> void:
	# O default preserva todo `.tres` que já existia: semente e colheita não
	# ganharam comportamento nenhum de carona.
	for id in ["rabanete", "semente_rabanete", "farinha"]:
		assert_eq(_items.get_def(id).acao_de_uso, ItemDef.ACAO_NENHUMA,
			"%s: item comum não é ferramenta" % id)

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

## Nenhuma cultura sem item. O caminho contrário — item sem cultura — deixou de
## ser erro na wave 12: farinha e pão não vêm de semente nenhuma, a cidade os
## fabrica. Quem guarda esse lado agora é `test_cadeia_trigo.gd`, que sabe
## quais itens a cidade tem direito de criar.
func test_toda_cultura_tem_os_dois_itens_no_catalogo() -> void:
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		assert_true(_items.has(crop.item_colheita_id()),
			"%s: colheita sem item não entra na mochila" % crop_id)
		assert_true(_items.has(crop.item_semente_id()),
			"%s: semente sem item não se compra" % crop_id)

func test_preco_de_venda_nao_mora_mais_na_cultura() -> void:
	var campos: Array[String] = []
	for prop: Dictionary in CropDef.new().get_property_list():
		campos.append(String(prop["name"]))
	assert_does_not_have(campos, "preco_venda",
		"fonte única: quem tem preço de venda é o item, não a cultura")
	assert_has(campos, "preco_semente", "o custo da semente continua sendo da cultura")

## Ferramenta tem onde pendurar arte tanto quanto cultura tem. Antes deste
## campo, `regador.tres` e `enxada.tres` não tinham linha nenhuma de ícone: a
## cultura levava sprite no `CropDef` e o item ficava sem.
func test_todo_item_tem_campo_de_sprite() -> void:
	var campos: Array[String] = []
	for prop: Dictionary in ItemDef.new().get_property_list():
		campos.append(String(prop["name"]))
	assert_has(campos, "sprite", "item sem campo de ícone não chega na hotbar")

## O default vazio é o que mantém todo `.tres` de antes válido sem edição.
func test_sprite_nasce_vazio_e_nao_quebra_tres_antigo() -> void:
	assert_eq(ItemDef.new().sprite, "", "campo novo não pode exigir edição do que já existia")
	for item_id in _items.ids():
		assert_not_null(_items.get_def(item_id), "%s: o .tres continua carregando" % item_id)

## Sprite preenchido aponta para arquivo que existe. Enquanto a arte não entra
## todos estão vazios e o teste passa de graça — quando entrar, ele é quem
## percebe caminho errado no `.tres`.
##
## Aceita `res://` e `uid://`: arrastar o PNG do FileSystem — que é o jeito que
## o `@export_file` habilitou e o que o artista de fato faz — grava um UID, não
## um caminho. Exigir `res://` reprovaria justamente o fluxo certo.
func test_sprite_preenchido_aponta_para_arquivo_existente() -> void:
	var quebrados: Array[String] = []
	for item_id in _items.ids():
		var caminho: String = _items.get_def(item_id).sprite
		if caminho.is_empty():
			continue
		var forma_valida: bool = caminho.begins_with("res://") or caminho.begins_with("uid://")
		if not forma_valida or not ResourceLoader.exists(caminho):
			quebrados.append("%s -> %s" % [item_id, caminho])
	assert_eq(quebrados, [] as Array[String], "sprite apontando para arquivo que não existe")

## O campo de sprite é `String`, e não `Texture2D`, porque `sim/` não conhece
## tipo de engine. Mas `@export_file` faz o inspector aceitar o PNG **arrastado
## do FileSystem**, em vez de exigir o caminho digitado à mão.
##
## Digitar caminho é o jeito mais comum de o sprite não aparecer no jogo — uma
## letra errada e o erro só se vê rodando. Se alguém trocar o `@export_file` por
## um `@export` simples num refactor, o artista volta a digitar sem perceber.
func test_o_campo_de_sprite_aceita_arrastar_do_filesystem() -> void:
	for prop: Dictionary in ItemDef.new().get_property_list():
		if String(prop["name"]) == "sprite":
			assert_eq(prop["hint"], PROPERTY_HINT_FILE, "sprite: seletor de arquivo, não texto solto")
			assert_eq(prop["type"], TYPE_STRING, "e o valor continua String — sim/ sem engine")
			assert_string_contains(String(prop["hint_string"]), "png")
			return
	fail_test("ItemDef não tem mais o campo sprite")
