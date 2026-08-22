extends GutTest

## A regra do "usar": o que acontece quando o jogador age num tile depende do
## que está na mão.
##
## É o coração da wave 11.2 e o arquivo que substitui as quatro ferramentas que
## o playground tinha inventado nas teclas 1–4. Toda a decisão mora aqui, em
## `sim/` — `game/` só pergunta e despacha o que voltar.
##
## ## Por que o resolvedor devolve a ação em vez de executá-la
##
## Porque a ordem do tick é regra de jogo (Locais → Inventory → Shipping →
## Farm → Time) e `PlantCropAction` estende `RemoveItemAction`: é o
## `InventorySystem` que cobra a semente. Uma ação nascida **dentro** do
## `FarmSystem` já teria passado do Inventory, e a semente sairia de graça.
##
## Devolvendo a ação para `game/` despachar, ela entra pela porta da frente e
## percorre a fila inteira, como qualquer outra.

var _items: ItemCatalog
var _crops: CropCatalog
var _inventario: InventoryState
var _farm: FarmState
var _resolvedor: ResolvedorUso


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_ferramenta("enxada", ItemDef.ACAO_ARAR))
	_items.register(_ferramenta("regador", ItemDef.ACAO_REGAR))
	_items.register(_item("semente_rabanete"))
	_items.register(_item("rabanete"))

	_crops = CropCatalog.new()
	_crops.register(_cultura("rabanete"))

	_inventario = InventoryState.new()
	_farm = FarmState.new()
	_resolvedor = ResolvedorUso.new(_inventario, _farm, _items, _crops)


func _item(id: String) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	return def

func _ferramenta(id: String, acao: String) -> ItemDef:
	var def := _item(id)
	def.stack_max = 1
	def.acao_de_uso = acao
	return def

func _cultura(id: String) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.dias_por_estagio = [1, 1, 1]
	def.item_semente = "semente_%s" % id
	def.item_colheita = id
	return def

## Põe os itens na mochila, na ordem, e deixa a mão no slot pedido.
func _mao(itens: Array[String], slot: int = 0) -> void:
	var inv := _inventario.get_player(0)
	inv.slots.clear()
	for id in itens:
		inv.slots.append(InventoryState.Slot.new(id, 1))
	inv.slot_na_mao = slot

func _acao(x: int = 0, y: int = 0) -> SimAction:
	return _resolvedor.acao_para(0, x, y)


# --- Ferramenta na mão ---

func test_enxada_ara_o_tile() -> void:
	_mao(["enxada"])
	var acao := _acao(2, 3) as TillPlotAction
	assert_not_null(acao, "enxada tinha que arar")
	assert_eq(acao.x, 2)
	assert_eq(acao.y, 3)

func test_regador_rega_o_tile() -> void:
	_mao(["regador"])
	_farm.get_plot(0, 0).arada = true
	assert_not_null(_acao() as WaterPlotAction, "regador tinha que regar")

## O alcance é de `game/` (a sim não tem a posição do jogador), mas o resto da
## impossibilidade é da sim. Aqui ela responde `null`: não há ação que faça
## sentido, e `game/` não despacha nada.
func test_enxada_em_tile_ja_arado_nao_gera_acao() -> void:
	_mao(["enxada"])
	_farm.get_plot(0, 0).arada = true
	assert_null(_acao(), "arar o que já está arado não é ação, é nada")

func test_mao_vazia_em_tile_cru_nao_gera_acao() -> void:
	_mao([])
	assert_null(_acao(), "sem nada na mão e sem cultura pronta, não há o que fazer")


# --- Semente na mão ---

func test_semente_planta_a_cultura_dela() -> void:
	_mao(["semente_rabanete"])
	_farm.get_plot(0, 0).arada = true

	var acao := _acao() as PlantCropAction
	assert_not_null(acao, "semente na mão planta")
	assert_eq(acao.crop_id, "rabanete", "a cultura sai da semente, não de um índice cravado")
	assert_eq(acao.item_id, "semente_rabanete", "e é essa semente que vai ser cobrada")
	assert_eq(acao.qtd, 1, "uma por plantio")

## O bug que motivou a wave: com o catálogo inteiro na mochila, plantar usava
## sempre a primeira cultura. Agora é a semente da mão que manda.
func test_a_semente_da_mao_e_que_decide_a_cultura() -> void:
	_items.register(_item("semente_cenoura"))
	_crops.register(_cultura("cenoura"))
	_mao(["semente_rabanete", "semente_cenoura"], 1)
	_farm.get_plot(0, 0).arada = true

	assert_eq((_acao() as PlantCropAction).crop_id, "cenoura",
		"plantou a primeira do catálogo em vez da que está na mão")

func test_semente_em_tile_nao_arado_nao_gera_acao() -> void:
	_mao(["semente_rabanete"])
	assert_null(_acao(), "não se planta em terra crua — e a semente não pode ser cobrada à toa")

func test_colheita_na_mao_nao_planta() -> void:
	_mao(["rabanete"])
	_farm.get_plot(0, 0).arada = true
	assert_null(_acao(), "rabanete colhido não é semente")


# --- Cultura pronta tem prioridade ---

func _planta_pronta(x: int = 0, y: int = 0) -> void:
	var plot := _farm.get_plot(x, y)
	plot.arada = true
	plot.crop_id = "rabanete"
	plot.estagio = _crops.get_def("rabanete").estagio_pronta()

func test_cultura_pronta_colhe_com_qualquer_coisa_na_mao() -> void:
	# Decisão da wave: colher tem prioridade sobre a ferramenta. É o que tira um
	# passo do laço mais repetido do jogo — não se troca de item para colher.
	for item: String in ["enxada", "regador", "semente_rabanete", ""]:
		var na_mao: Array[String] = []
		if not item.is_empty():
			na_mao.append(item)
		_mao(na_mao)
		_planta_pronta()
		var acao := _acao() as HarvestCropAction
		assert_not_null(acao, "com '%s' na mão a cultura pronta tinha que ser colhida" % item)

func test_cultura_verde_nao_e_colhida() -> void:
	_mao([])
	var plot := _farm.get_plot(0, 0)
	plot.arada = true
	plot.crop_id = "rabanete"
	plot.estagio = 0
	assert_null(_acao(), "cultura verde não se colhe")

## A prioridade da colheita não pode atropelar a rega: quem rega uma cultura
## que ainda está crescendo continua regando.
func test_regar_cultura_verde_ainda_rega() -> void:
	_mao(["regador"])
	var plot := _farm.get_plot(0, 0)
	plot.arada = true
	plot.crop_id = "rabanete"
	plot.estagio = 0
	assert_not_null(_acao() as WaterPlotAction, "regador na cultura verde rega")


# --- Contrato com game/ ---

func test_a_acao_carrega_o_dono() -> void:
	_mao(["enxada"])
	assert_eq(_acao().player_id, 0, "co-op: toda ação sabe de quem é")

func test_mao_apontando_para_slot_inexistente_e_mao_vazia() -> void:
	# A mochila esvazia e o índice fica onde estava — é como toda hotbar se
	# comporta, e não pode virar erro.
	_mao([], 7)
	_planta_pronta()
	assert_not_null(_acao() as HarvestCropAction, "mão vazia ainda colhe")

func test_item_fora_do_catalogo_nao_quebra() -> void:
	_mao(["item_que_nao_existe"])
	assert_null(_acao(), "id desconhecido não faz nada, e não derruba a sim")
