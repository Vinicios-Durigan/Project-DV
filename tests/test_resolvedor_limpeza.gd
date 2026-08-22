extends GutTest

## A enxada capina — e é o **tile** que decide, não um botão novo.
##
## Desde a wave 11.2 existe uma ação só: usar. O que ela faz depende do que está
## na mão e do que está embaixo do cursor. Limpar entra por essa mesma porta:
## enxada em terra limpa ara, enxada em mato capina. Zero slot novo na hotbar,
## zero sprite de ferramenta nova, zero tecla para o jogador decorar.
##
## ## A ordem das regras é regra de jogo
##
## Cultura pronta continua ganhando de tudo (wave 11.2): usar num tile maduro
## colhe, seja o que for que esteja na mão. Depois vem a limpeza — porque
## enquanto houver mato sobre o tile, arar não é o que o jogador quis dizer.
##
## ## Arar passou a exigir chão livre
##
## Não é detalhe de implementação: sem isso, a enxada araria por baixo da pedra
## e o jogador plantaria dentro de um matagal.

const JOGADOR: int = 0

var _inventario: InventoryState
var _farm: FarmState
var _terreno: EstadoTerreno
var _items: ItemCatalog
var _crops: CropCatalog
var _resolvedor: ResolvedorUso


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_ferramenta("enxada", ItemDef.ACAO_ARAR, [EstadoTerreno.MATO]))
	_items.register(_ferramenta("regador", ItemDef.ACAO_REGAR, []))
	_items.register(_ferramenta("picareta", ItemDef.ACAO_NENHUMA, [EstadoTerreno.PEDRA]))
	_items.register(_ferramenta("machado", ItemDef.ACAO_NENHUMA,
			[EstadoTerreno.ARVORE, EstadoTerreno.TOCO]))
	_items.register(_item("semente_rabanete"))
	_items.register(_item("rabanete"))

	_crops = CropCatalog.new()
	_crops.register(_cultura("rabanete"))

	_inventario = InventoryState.new()
	_farm = FarmState.new()
	_terreno = EstadoTerreno.new()
	_resolvedor = ResolvedorUso.new(_inventario, _farm, _items, _crops, _terreno)

func _ferramenta(id: String, acao: String, alvos: Array[String]) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	def.stack_max = 1
	def.acao_de_uso = acao
	def.alvos_de_limpeza = alvos
	return def

func _item(id: String) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	return def

func _cultura(id: String) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.nome = id
	def.dias_por_estagio = [1, 1, 1]
	def.item_semente = "semente_%s" % id
	def.item_colheita = id
	return def

func _mao(item_id: String) -> void:
	var inv := _inventario.get_player(JOGADOR)
	for i in inv.slots.size():
		inv.slots[i] = InventoryState.Slot.new()
	inv.slots[0] = InventoryState.Slot.new(item_id, 1)
	inv.slot_na_mao = 0

func _acao(x: int = 0, y: int = 0) -> SimAction:
	return _resolvedor.acao_para(JOGADOR, x, y)


# --- Limpar ---

func test_a_enxada_em_mato_capina_em_vez_de_arar() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.MATO)
	_mao("enxada")
	var acao := _acao() as LimparTerrenoAction
	assert_not_null(acao, "o tile decide o que a enxada faz")
	assert_eq(acao.item_id, "enxada", "a ferramenta viaja na ação — é ela que diz o que sai")
	assert_eq(acao.x, 0)
	assert_eq(acao.y, 0)

func test_a_picareta_quebra_pedra() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.PEDRA)
	_mao("picareta")
	assert_not_null(_acao() as LimparTerrenoAction)

func test_o_machado_derruba_arvore_e_toco() -> void:
	_mao("machado")
	_terreno.define_cobertura(0, 0, EstadoTerreno.ARVORE)
	assert_not_null(_acao() as LimparTerrenoAction, "a árvore")
	_terreno.define_cobertura(0, 0, EstadoTerreno.TOCO)
	assert_not_null(_acao() as LimparTerrenoAction, "e o toco que ela deixa")

func test_ferramenta_que_nao_serve_nao_vira_acao_nenhuma() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.PEDRA)
	_mao("enxada")
	assert_null(_acao(),
			"a enxada não quebra pedra, e clicar não pode virar uma ação recusada")

func test_a_agua_nao_vira_acao_nenhuma() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.AGUA)
	for ferramenta in ["enxada", "picareta", "machado"]:
		_mao(ferramenta)
		assert_null(_acao(), "%s no poço não faz nada" % ferramenta)


# --- Arar passou a exigir chão livre ---

func test_nao_se_ara_por_baixo_do_entulho() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.PEDRA)
	_mao("enxada")
	assert_null(_acao(), "sem isso o jogador plantaria dentro de um matagal")

func test_chao_livre_continua_arando() -> void:
	_mao("enxada")
	assert_not_null(_acao() as TillPlotAction, "o que sempre funcionou continua funcionando")


# --- A ordem das regras ---

func test_cultura_pronta_ganha_de_tudo() -> void:
	var plot := _farm.get_plot(0, 0)
	plot.arada = true
	plot.crop_id = "rabanete"
	plot.estagio = _crops.get_def("rabanete").estagio_pronta()
	_mao("machado")
	assert_not_null(_acao() as HarvestCropAction,
			"usar num tile maduro colhe, seja o que for que esteja na mão (wave 11.2)")

func test_regar_nao_e_confundido_com_limpar() -> void:
	_terreno.define_cobertura(0, 0, EstadoTerreno.MATO)
	_mao("regador")
	assert_null(_acao(), "o regador não tira mato, e não há terra arada embaixo dele")

func test_plantar_continua_pedindo_terra_arada() -> void:
	_farm.get_plot(0, 0).arada = true
	_mao("semente_rabanete")
	assert_not_null(_acao() as PlantCropAction, "a semente continua plantando")


# --- Sem terreno injetado, nada muda ---

## O resolvedor nasce com terreno vazio quando ninguém injeta um. É o que faz o
## teste da wave 11.2 continuar valendo sem saber que existe mato.
func test_sem_terreno_o_mundo_e_todo_livre() -> void:
	var solto := ResolvedorUso.new(_inventario, _farm, _items, _crops)
	_mao("enxada")
	assert_not_null(solto.acao_para(JOGADOR, 0, 0) as TillPlotAction)
