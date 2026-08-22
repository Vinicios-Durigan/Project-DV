extends GutTest

## Só se age onde se está (decisão de presença, wave 10).
##
## O SistemaLocais roda ANTES de todos os outros no tick: ele carimba
## `rejeitada` na ação fora de lugar e os sistemas seguintes só olham a flag.
## A posição na fila não é detalhe — `PlantCropAction` estende
## `RemoveItemAction`, e se o carimbo viesse depois do Inventory a semente
## seria debitada de uma ação recusada. O teste mais importante deste arquivo
## é o que prova que isso não acontece.

var _factory: SimFactory
var _world: SimWorld


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()


func _viaja(destino: String) -> Array[SimEvent]:
	var acao := ViajarAction.new()
	acao.player_id = 0
	acao.destino = destino
	return _world.handle(acao)

func _tem_evento(eventos: Array[SimEvent], tipo: Variant) -> bool:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return true
	return false

func _rejeicao(eventos: Array[SimEvent]) -> ActionRejectedEvent:
	for evento in eventos:
		if evento is ActionRejectedEvent:
			return evento
	return null

func _sementes_na_mochila() -> int:
	var slots: Array = _world.snapshot()["inventory"]["0"]["slots"]
	var total := 0
	for slot: Dictionary in slots:
		if slot.get("item_id", "") == "semente_rabanete":
			total += int(slot.get("qtd", 0))
	return total


func test_viajar_muda_o_local_e_emite_evento() -> void:
	var eventos := _viaja(EstadoLocais.CIDADE)

	var viagem: JogadorViajouEvent = null
	for evento in eventos:
		if evento is JogadorViajouEvent:
			viagem = evento
	assert_not_null(viagem, "mudou estado, tem que sair evento")
	assert_eq(viagem.de, EstadoLocais.FAZENDA)
	assert_eq(viagem.para, EstadoLocais.CIDADE)
	assert_eq(viagem.player_id, 0)
	assert_eq(_factory.get_estado_locais().local_de(0), EstadoLocais.CIDADE)

func test_viajar_para_onde_ja_esta_e_recusado() -> void:
	var eventos := _viaja(EstadoLocais.FAZENDA)
	var rejeicao := _rejeicao(eventos)
	assert_not_null(rejeicao, "viajar para onde já está não muda nada — recusa")
	assert_eq(rejeicao.motivo, SistemaLocais.MOTIVO_JA_NO_LOCAL)
	assert_false(_tem_evento(eventos, JogadorViajouEvent),
		"recusa não emite evento de viagem")

func test_viajar_para_destino_desconhecido_e_recusado() -> void:
	var eventos := _viaja("lua")
	var rejeicao := _rejeicao(eventos)
	assert_not_null(rejeicao)
	assert_eq(rejeicao.motivo, SistemaLocais.MOTIVO_DESTINO_DESCONHECIDO)
	assert_eq(_factory.get_estado_locais().local_de(0), EstadoLocais.FAZENDA,
		"a recusa não pode ter alterado o estado")


func test_arar_fora_da_fazenda_e_recusado_sem_mudar_o_mundo() -> void:
	_viaja(EstadoLocais.CIDADE)

	var arar := TillPlotAction.new()
	arar.player_id = 0
	arar.x = 0
	arar.y = 0
	var eventos := _world.handle(arar)

	assert_true(arar.rejeitada, "o carimbo é a comunicação entre sistemas")
	var rejeicao := _rejeicao(eventos)
	assert_not_null(rejeicao)
	assert_eq(rejeicao.motivo, SistemaLocais.MOTIVO_FORA_DO_LOCAL)
	assert_false(_tem_evento(eventos, PlotTilledEvent), "nada foi arado")
	var plots: Dictionary = _world.snapshot()["farm"]["plots"]
	assert_false(plots.has("0:0"), "o solo continua intocado")

func test_plantar_fora_da_fazenda_nao_debita_a_semente() -> void:
	# Prepara um canteiro arado ainda na fazenda, para a única recusa possível
	# ser a de local — e não a de solo.
	var arar := TillPlotAction.new()
	arar.player_id = 0
	arar.x = 1
	arar.y = 1
	_world.handle(arar)
	assert_eq(_sementes_na_mochila(), 5, "entrega inicial do GAMEPLAY §5")

	_viaja(EstadoLocais.CIDADE)
	var plantar := PlantCropAction.new()
	plantar.player_id = 0
	plantar.item_id = "semente_rabanete"
	plantar.qtd = 1
	plantar.crop_id = "rabanete"
	plantar.x = 1
	plantar.y = 1
	var eventos := _world.handle(plantar)

	assert_true(plantar.rejeitada)
	assert_not_null(_rejeicao(eventos))
	assert_eq(_sementes_na_mochila(), 5,
		"o SistemaLocais roda ANTES do Inventory: a semente não pode sumir")

func test_regar_e_colher_fora_da_fazenda_sao_recusados() -> void:
	_viaja(EstadoLocais.CIDADE)

	var regar := WaterPlotAction.new()
	regar.player_id = 0
	regar.x = 0
	regar.y = 0
	assert_not_null(_rejeicao(_world.handle(regar)), "regar exige estar lá")

	var colher := HarvestCropAction.new()
	colher.player_id = 0
	colher.x = 0
	colher.y = 0
	assert_not_null(_rejeicao(_world.handle(colher)), "colher também")


func test_na_fazenda_tudo_segue_como_antes_da_wave() -> void:
	var arar := TillPlotAction.new()
	arar.player_id = 0
	arar.x = 2
	arar.y = 2
	var eventos := _world.handle(arar)
	assert_false(arar.rejeitada, "na fazenda o gate é invisível")
	assert_true(_tem_evento(eventos, PlotTilledEvent))

func test_dormir_funciona_de_qualquer_lugar() -> void:
	_viaja(EstadoLocais.CIDADE)
	var dormir := SleepAction.new()
	dormir.player_id = 0
	var eventos := _world.handle(dormir)
	assert_false(dormir.rejeitada,
		"dormir não tem local exigido — CASA como lugar é decisão futura")
	assert_true(_tem_evento(eventos, DayEndedEvent))


func test_o_local_entra_no_save() -> void:
	_viaja(EstadoLocais.CIDADE)
	var snapshot: Dictionary = _world.snapshot()
	assert_true(snapshot.has("locais"), "bloco novo do save, com default")
	assert_eq(snapshot["locais"]["jogadores"]["0"], EstadoLocais.CIDADE)
