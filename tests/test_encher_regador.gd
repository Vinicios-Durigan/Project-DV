extends GutTest

## O poço: a única fonte de água, e ela tem endereço.
##
## ## Por que não se enche em qualquer tile molhado
##
## Regar um tile e reencher nele mesmo mataria a rota antes de ela existir. A
## água fica num lugar só, e é a **ida** até lá que cobra o relógio — que é a
## coisa toda que esta wave acrescenta ao jogo.
##
## ## Encher é ação, não gesto
##
## `EncherRegadorAction` passa pela fila inteira como qualquer outra, e quem a
## monta é o resolvedor — o jogador não tem botão "encher", ele usa o regador em
## cima da água.
##
## ## Regador cheio é `null`, não recusa
##
## Não há nada de errado em estar cheio; simplesmente não há o que fazer.
## Recusa é para o que o jogador tentou e não pôde, e vira aviso na tela.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _estado: InventoryState
var _farm: FarmState
var _terreno: EstadoTerreno
var _items: ItemCatalog
var _sistema: InventorySystem
var _resolvedor: ResolvedorUso


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_ferramenta("regador", ItemDef.ACAO_REGAR, 15))
	_items.register(_ferramenta("enxada", ItemDef.ACAO_ARAR, 0))

	_estado = InventoryState.new()
	_farm = FarmState.new()
	_terreno = EstadoTerreno.new()
	_terreno.define_cobertura(4, 4, EstadoTerreno.AGUA)

	_sistema = InventorySystem.new(_estado, _items, CropCatalog.new())
	_resolvedor = ResolvedorUso.new(_estado, _farm, _items, CropCatalog.new(), _terreno)

func _ferramenta(id: String, acao: String, capacidade: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	def.stack_max = 1
	def.acao_de_uso = acao
	def.capacidade_carga = capacidade
	return def

func _mao(item_id: String, carga: int = 0) -> InventoryState.Slot:
	var inv := _estado.get_player(JOGADOR)
	inv.slots[0] = InventoryState.Slot.new(item_id, 1)
	inv.slots[0].carga = carga
	inv.slot_na_mao = 0
	return inv.slots[0]

## No poço, em (4,4).
func _usa_no_poco() -> SimAction:
	return _resolvedor.acao_para(JOGADOR, 4, 4)

func _enche() -> Array[SimEvent]:
	var acao := EncherRegadorAction.new()
	acao.player_id = JOGADOR
	acao.x = 4
	acao.y = 4
	return _sistema.handle(acao)

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null


# --- O resolvedor decide pelo contexto ---

func test_regador_no_poco_vira_acao_de_encher() -> void:
	_mao("regador", 0)
	var acao := _usa_no_poco() as EncherRegadorAction
	assert_not_null(acao, "usar o regador na água enche — sem botão novo")
	assert_eq(acao.x, 4, "o tile do poço viaja na ação")
	assert_eq(acao.y, 4)

func test_regador_pela_metade_ainda_enche() -> void:
	_mao("regador", 7)
	assert_not_null(_usa_no_poco() as EncherRegadorAction,
			"completar o que falta é o gesto mais comum de todos")

func test_regador_cheio_no_poco_nao_faz_nada() -> void:
	_mao("regador", 15)
	assert_null(_usa_no_poco(),
			"estar cheio não é erro — é ausência de ação, e ausência é silêncio")

func test_enxada_no_poco_nao_faz_nada() -> void:
	_mao("enxada")
	assert_null(_usa_no_poco(), "a enxada não carrega água, e não se ara dentro do poço")

func test_regador_fora_do_poco_continua_regando() -> void:
	_farm.get_plot(1, 1).arada = true
	_mao("regador", 5)
	assert_not_null(_resolvedor.acao_para(JOGADOR, 1, 1) as WaterPlotAction,
			"longe da água o regador faz o de sempre")

func test_regador_vazio_fora_do_poco_ainda_tenta_regar() -> void:
	_farm.get_plot(1, 1).arada = true
	_mao("regador", 0)
	assert_not_null(_resolvedor.acao_para(JOGADOR, 1, 1) as WaterPlotAction,
			"quem responde por falta de água é a sim, com motivo — não o silêncio daqui")


# --- O inventário enche ---

func test_encher_completa_ate_a_capacidade() -> void:
	var slot := _mao("regador", 3)
	_enche()
	assert_eq(slot.carga, 15, "o poço não serve meia dose")

func test_encher_avisa_de_quanto_para_quanto() -> void:
	_mao("regador", 3)
	var evento := _primeiro(_enche(), RegadorEnchidoEvent) as RegadorEnchidoEvent
	assert_not_null(evento, "o medidor da tela vive deste evento")
	assert_eq(evento.item_id, "regador", "o que foi enchido")
	assert_eq(evento.de, 3, "de quanto era")
	assert_eq(evento.para, 15, "para quanto foi")
	assert_eq(evento.capacidade, 15, "e quanto cabe, para a tela escrever 15/15")

func test_encher_o_que_ja_esta_cheio_nao_emite_nada() -> void:
	_mao("regador", 15)
	assert_eq(_enche().size(), 0, "sem mudança, sem evento")

func test_encher_com_a_mao_vazia_nao_faz_nada() -> void:
	_estado.get_player(JOGADOR).slot_na_mao = 0
	assert_eq(_enche().size(), 0)

func test_encher_item_que_nao_carrega_nao_faz_nada() -> void:
	var slot := _mao("enxada")
	_enche()
	assert_eq(slot.carga, 0, "capacidade zero não vira balde por decreto")


# --- A rota, ponta a ponta ---

## O laço que a wave existe para criar: enche, rega até acabar, volta ao poço.
func test_o_regador_acaba_e_a_rota_recomeca() -> void:
	var slot := _mao("regador", 0)
	_sistema.handle(_acao_de_encher())
	assert_eq(slot.carga, 15, "cheio")

	for i in 15:
		_farm.get_plot(i, 2).arada = true
		var rega := WaterPlotAction.new()
		rega.player_id = JOGADOR
		rega.x = i
		rega.y = 2
		_sistema.handle(rega)
	assert_eq(slot.carga, 0, "quinze tiles depois, acabou")

	var seca := WaterPlotAction.new()
	seca.player_id = JOGADOR
	assert_not_null(_primeiro(_sistema.handle(seca), ActionRejectedEvent),
			"e o décimo sexto tile fica esperando a próxima viagem")

func _acao_de_encher() -> EncherRegadorAction:
	var acao := EncherRegadorAction.new()
	acao.player_id = JOGADOR
	acao.x = 4
	acao.y = 4
	return acao
