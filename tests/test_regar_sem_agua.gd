extends GutTest

## Regar gasta água, e sem água a sim diz não.
##
## ## Por que quem desconta é o inventário
##
## O slot é dele, e ele roda antes do Farm na ordem fixa. Mesma família do
## `PlantCropAction`, que já é cobrado lá — a diferença é que o custo é carga,
## não item. Fosse o `FarmSystem` a descontar, ele estaria escrevendo no state
## de outro dono, que é a única coisa que a arquitetura não permite.
##
## ## Recusa, e não silêncio
##
## Regar sem água emite `ActionRejectedEvent` com motivo `sem_agua`. O `null` do
## resolvedor continua reservado para "não há o que fazer aqui" — tile seco que
## ninguém arou. Recusa tem motivo e vira aviso na tela; ausência é silêncio, e
## o jogador que apertou o botão merece saber por que nada aconteceu.
##
## ## Item que não carrega não gasta e não recusa
##
## Capacidade zero descreve a enxada e o trigo. Se regar com eles chegasse até
## aqui, a recusa seria `sem_agua` — quando o problema real é outro. Eles passam
## reto, e quem responde é o resolvedor, com `null`.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _estado: InventoryState
var _items: ItemCatalog
var _sistema: InventorySystem


func before_each() -> void:
	_items = ItemCatalog.new()
	_items.register(_ferramenta("regador", ItemDef.ACAO_REGAR, 15))
	_items.register(_ferramenta("enxada", ItemDef.ACAO_ARAR, 0))
	_estado = InventoryState.new()
	_sistema = InventorySystem.new(_estado, _items, CropCatalog.new())

func _ferramenta(id: String, acao: String, capacidade: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	def.stack_max = 1
	def.acao_de_uso = acao
	def.capacidade_carga = capacidade
	return def

## Põe o item na mão, com a carga que se quiser.
func _mao(item_id: String, carga: int = 0) -> InventoryState.Slot:
	var inv := _estado.get_player(JOGADOR)
	inv.slots[0] = InventoryState.Slot.new(item_id, 1)
	inv.slots[0].carga = carga
	inv.slot_na_mao = 0
	return inv.slots[0]

func _rega() -> Array[SimEvent]:
	var acao := WaterPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = 1
	acao.y = 1
	return _sistema.handle(acao)

func _recusa(eventos: Array[SimEvent]) -> ActionRejectedEvent:
	for evento in eventos:
		if evento is ActionRejectedEvent:
			return evento as ActionRejectedEvent
	return null


# --- O gasto ---

func test_regar_gasta_uma_carga() -> void:
	var slot := _mao("regador", 15)
	_rega()
	assert_eq(slot.carga, 14, "cada tile regado é uma regada a menos no regador")

func test_regar_ate_o_fim_esvazia() -> void:
	var slot := _mao("regador", 3)
	for _i in 3:
		_rega()
	assert_eq(slot.carga, 0, "três tiles, três cargas")

func test_o_gasto_nao_mexe_no_item() -> void:
	var slot := _mao("regador", 5)
	_rega()
	assert_eq(slot.item_id, "regador", "gasta a água, não o regador")
	assert_eq(slot.qtd, 1)


# --- A recusa ---

func test_regador_vazio_recusa_com_motivo() -> void:
	_mao("regador", 0)
	var eventos := _rega()
	var recusa := _recusa(eventos)
	assert_not_null(recusa, "regar sem água não pode ser silêncio")
	assert_eq(recusa.motivo, InventorySystem.MOTIVO_SEM_AGUA, "e o motivo diz qual é o problema")

func test_a_recusa_carimba_a_acao_e_o_farm_nao_rega() -> void:
	_mao("regador", 0)
	var acao := WaterPlotAction.new()
	acao.player_id = JOGADOR
	_sistema.handle(acao)
	assert_true(acao.rejeitada,
			"o carimbo é o que faz o FarmSystem, mais adiante na fila, não molhar nada")

func test_recusar_nao_deixa_a_carga_negativa() -> void:
	var slot := _mao("regador", 0)
	_rega()
	assert_eq(slot.carga, 0, "não se deve água ao poço")


# --- Quem não carrega passa reto ---

func test_enxada_na_mao_nao_gasta_nem_recusa() -> void:
	_mao("enxada")
	var eventos := _rega()
	assert_null(_recusa(eventos),
			"capacidade zero não é regador vazio — quem responde por isso é o resolvedor")

func test_mao_vazia_nao_recusa() -> void:
	_estado.get_player(JOGADOR).slot_na_mao = 0
	assert_null(_recusa(_rega()), "sem item na mão, o problema não é falta de água")

func test_acao_ja_recusada_nao_gasta_carga() -> void:
	var slot := _mao("regador", 5)
	var acao := WaterPlotAction.new()
	acao.player_id = JOGADOR
	acao.rejeitada = true
	_sistema.handle(acao)
	assert_eq(slot.carga, 5,
			"quem foi barrado antes (fora do lugar, por exemplo) não paga o pedágio")
