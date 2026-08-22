extends GutTest

## A cadeia que a cidade transforma: trigo → farinha → pão.
##
## Este teste não prova código nenhum — prova **conteúdo**. Trigo, farinha e
## pão são `.tres` de `data/`, montados com `CropDef` e `ItemDef` que já
## existiam desde a wave 02. Zero código novo é o ponto: se a cadeia da cidade
## exigisse classe nova, "conteúdo é id + catálogo" teria falhado.
##
## O que ele guarda é a **escada de valor**, e ela é regra de design, não
## enfeite (PRINCIPIOS §1):
##
## - trigo cru é o **pior** negócio da fazenda. Vendido no caixote ele perde
##   para qualquer cultura — é assim que a cidade fica sendo a resposta, e não
##   uma comodidade;
## - cada degrau de beneficiamento vale mais que a matéria-prima que ele come,
##   **com folga para a taxa** que o estabelecimento cobra (wave 12.2);
## - o pão paga o dia inteiro de ida e volta e ainda bate a cultura mais
##   lucrativa do jogo. Autossuficiência é prêmio; dependência é o caminho.
##
## Os números saem da fórmula-mestre do GAMEPLAY §5:
## `lucro_por_dia_por_tile = (venda − semente) / dias_de_ciclo`.

## Quanto entra por quanto sai em cada degrau — o mesmo número que o
## `DefEstabelecimento` do moinho e da padaria carrega na 12.2. Aqui ele está
## repetido de propósito: este teste é sobre o conteúdo bater com o design,
## não sobre o `.tres` bater consigo mesmo.
const TRIGO_POR_FARINHA: int = 2
const FARINHA_POR_PAO: int = 2

## Itens que não vêm de semente nenhuma: a cidade os fabrica.
const ITENS_DE_BENEFICIAMENTO: Array[String] = ["farinha", "pao"]

var _items: ItemCatalog
var _crops: CropCatalog


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.load_from_dir()
	_crops = CropCatalog.new()
	_crops.load_from_dir()


func _venda(item_id: String) -> int:
	var def := _items.get_def(item_id)
	return def.preco_venda if def != null else 0

## Lucro por dia por tile da cultura, pela fórmula-mestre do GAMEPLAY §5.
func _lucro_por_dia(crop_id: String) -> float:
	var crop := _crops.get_def(crop_id)
	var dias := crop.dias_ate_pronta()
	if dias <= 0:
		return 0.0
	var rende := crop.rende_por_colheita
	return float(_venda(crop.item_colheita_id()) * rende - crop.preco_semente) / float(dias)

## As culturas que a fórmula-mestre mede. A rebrota fica de fora e não é
## exceção conveniente: o lucro dela não é `(venda − semente) / ciclo`, é
## `venda / dias_entre_colheitas` depois que a semente já foi paga — pela
## fórmula do primeiro ciclo o morango dá prejuízo, o que é verdade e
## irrelevante. Comparar trigo com ele seria comparar com um número que não
## descreve nada.
func _culturas_de_ciclo_unico() -> Array[String]:
	var out: Array[String] = []
	for crop_id in _crops.ids():
		if not _crops.get_def(crop_id).colheitas_infinitas:
			out.append(crop_id)
	return out


# --- A cultura ---

func test_trigo_entra_no_catalogo_como_quinta_cultura() -> void:
	assert_true(_crops.has("trigo"), "sem trigo não existe cadeia")
	assert_eq(_crops.ids(), ["abobora", "cenoura", "morango", "rabanete", "trigo"],
		"as 5 culturas de data/crops/")

func test_trigo_leva_cinco_dias_e_tem_um_sprite_por_estagio() -> void:
	var crop := _crops.get_def("trigo")
	assert_eq(crop.dias_ate_pronta(), 5, "ciclo de 5 dias regados")
	assert_eq(crop.total_estagios(), 4,
		"4 estágios como as outras quatro — é o que o ARTE.md §11 prometeu ao artista")
	assert_false(crop.colheitas_infinitas, "trigo não rebrota — quem rebrota é o morango")
	assert_eq(crop.rende_por_colheita, 1, "um pé, um trigo: a fórmula-mestre assume isso")
	assert_eq(crop.sprites_estagios.size(), crop.total_estagios(),
		"um caminho de sprite por estágio, do plantado ao pronta")

func test_trigo_usa_os_ids_de_item_da_convencao() -> void:
	var crop := _crops.get_def("trigo")
	assert_eq(crop.item_semente_id(), "semente_trigo")
	assert_eq(crop.item_colheita_id(), "trigo")


# --- Os itens ---

func test_os_quatro_itens_da_cadeia_existem_com_nome_e_preco() -> void:
	for item_id in ["trigo", "semente_trigo", "farinha", "pao"]:
		var def := _items.get_def(item_id)
		assert_not_null(def, "%s: sem ItemDef não existe no jogo" % item_id)
		assert_false(def.nome.is_empty(), "%s: sem nome não dá para mostrar" % item_id)
		assert_gt(def.preco_venda, 0, "%s: item da cadeia sempre se vende" % item_id)

## Item sem cultura por trás só tem duas desculpas: ou a cidade o fabrica, ou
## ele é ferramenta. Qualquer outro é `.tres` órfão — alguém criou e esqueceu.
func test_farinha_e_pao_sao_os_unicos_itens_que_a_cidade_fabrica() -> void:
	var de_cultura: Array[String] = []
	for crop_id in _crops.ids():
		var crop := _crops.get_def(crop_id)
		de_cultura.append(crop.item_colheita_id())
		de_cultura.append(crop.item_semente_id())

	var orfaos: Array[String] = []
	for item_id in _items.ids():
		var def := _items.get_def(item_id)
		# Ferramenta é o que **faz** alguma coisa ao ser usada. Até a wave 14
		# isso era só `acao_de_uso`; o machado e a picareta não aram nem regam —
		# elas tiram coisa do caminho, e isso também é ferramenta.
		var e_ferramenta := def.acao_de_uso != ItemDef.ACAO_NENHUMA \
			or not def.alvos_de_limpeza.is_empty()
		if de_cultura.has(item_id) or e_ferramenta:
			continue
		orfaos.append(item_id)
	assert_eq(orfaos, ITENS_DE_BENEFICIAMENTO,
		"item que não vem de semente nem é ferramenta só existe se a cidade o fabrica")


# --- A escada de valor ---

func test_trigo_cru_e_o_pior_negocio_da_fazenda() -> void:
	var trigo := _lucro_por_dia("trigo")
	for crop_id in _culturas_de_ciclo_unico():
		if crop_id == "trigo":
			continue
		assert_lt(trigo, _lucro_por_dia(crop_id),
			"trigo cru tem que perder para %s — senão a cidade vira comodidade" % crop_id)

func test_cada_degrau_vale_mais_que_a_materia_prima_que_come() -> void:
	assert_gt(_venda("farinha"), _venda("trigo") * TRIGO_POR_FARINHA,
		"moer tem que pagar mais do que vender o trigo cru")
	assert_gt(_venda("pao"), _venda("farinha") * FARINHA_POR_PAO,
		"assar tem que pagar mais do que vender a farinha")

func test_a_cadeia_inteira_bate_a_cultura_mais_lucrativa() -> void:
	var crop := _crops.get_def("trigo")
	var trigo_por_pao := TRIGO_POR_FARINHA * FARINHA_POR_PAO
	var tile_dias := trigo_por_pao * crop.dias_ate_pronta()
	var custo_sementes := crop.preco_semente * trigo_por_pao
	var lucro_do_pao := float(_venda("pao") - custo_sementes) / float(tile_dias)

	for crop_id in _culturas_de_ciclo_unico():
		assert_gt(lucro_do_pao, _lucro_por_dia(crop_id),
			"o pão paga o dia de viagem e ainda bate %s (sem contar a taxa)" % crop_id)

func test_semente_de_trigo_revende_pela_metade_como_toda_semente() -> void:
	var crop := _crops.get_def("trigo")
	@warning_ignore("integer_division")
	var metade := crop.preco_semente / 2
	assert_eq(_venda("semente_trigo"), metade,
		"revenda é metade da compra, como nas outras quatro")
	assert_lt(_venda("semente_trigo"), _venda("trigo"),
		"plantar paga melhor que revender a semente")
