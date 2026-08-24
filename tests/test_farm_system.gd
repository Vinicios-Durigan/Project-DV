extends GutTest

## As 4 ações de fazenda: arar, plantar, regar, colher.
##
## Ação inválida não muda nada e não emite nada — exceto quando a cadeia já
## cobrou o preço (plantar consome a semente antes do FarmSystem olhar o tile):
## aí sai `ActionRejectedEvent` para `game/` ter o que dizer ao jogador.

var _state: FarmState
var _catalog: CropCatalog
var _system: FarmSystem

func before_each() -> void:
	_state = FarmState.new()
	_catalog = CropCatalog.new()
	_catalog.register(_def("rabanete", [1, 1, 2] as Array[int]))
	_catalog.register(_def("morango", [2, 2, 4] as Array[int], true, 1))
	_system = FarmSystem.new(_state, _catalog)

func _def(id: String, dias: Array[int], rebrota: bool = false, rende: int = 1) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.dias_por_estagio = dias
	def.colheitas_infinitas = rebrota
	def.rende_por_colheita = rende
	return def

func _arar(x: int, y: int) -> Array[SimEvent]:
	var action := TillPlotAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _plantar(crop_id: String, x: int, y: int) -> Array[SimEvent]:
	var action := PlantCropAction.new()
	action.crop_id = crop_id
	action.item_id = "semente_%s" % crop_id
	action.x = x
	action.y = y
	return _system.handle(action)

func _regar(x: int, y: int) -> Array[SimEvent]:
	var action := WaterPlotAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _colher(x: int, y: int) -> Array[SimEvent]:
	var action := HarvestCropAction.new()
	action.x = x
	action.y = y
	return _system.handle(action)

func _madura(crop_id: String, x: int, y: int) -> void:
	var plot := _state.get_plot(x, y)
	plot.arada = true
	plot.crop_id = crop_id
	plot.estagio = _catalog.get_def(crop_id).estagio_pronta()


func test_arar_grama_revira_a_terra() -> void:
	var events := _arar(1, 1)

	assert_true(_state.get_plot(1, 1).arada)
	assert_eq(events.size(), 1)
	var event := events[0] as PlotTilledEvent
	assert_not_null(event, "emite PlotTilledEvent")
	assert_eq(event.x, 1)
	assert_eq(event.y, 1)
	assert_eq(event.plot_id, "1:1")
	assert_eq(event.player_id, 0)

func test_arar_de_novo_nao_faz_nada() -> void:
	_arar(1, 1)
	assert_eq(_regar(1, 1).size(), 1, "sanidade: o tile existe e é regável")
	assert_eq(_arar(1, 1), [], "tile já arado: sem mudança, sem evento")

func test_arar_tile_com_cultura_nao_faz_nada() -> void:
	_madura("rabanete", 1, 1)
	assert_eq(_arar(1, 1), [], "a enxada não passa por cima da plantação")
	assert_true(_state.get_plot(1, 1).tem_cultura())

func test_plantar_em_terra_arada() -> void:
	_arar(2, 3)
	var events := _plantar("rabanete", 2, 3)

	var plot := _state.get_plot(2, 3)
	assert_eq(plot.crop_id, "rabanete")
	assert_eq(plot.estagio, 0, "nasce no primeiro estágio")
	assert_eq(plot.dias_no_estagio, 0)
	assert_eq(events.size(), 1)
	var event := events[0] as CropPlantedEvent
	assert_not_null(event, "emite CropPlantedEvent")
	assert_eq(event.crop_id, "rabanete")
	assert_eq(event.x, 2)
	assert_eq(event.y, 3)
	assert_eq(event.estagio_pronta, 3, "game/ já sabe quantos estágios animar")

func test_plantar_em_grama_e_rejeitado() -> void:
	var events := _plantar("rabanete", 2, 3)

	assert_false(_state.peek_plot(2, 3).tem_cultura(), "semente não pega em grama")
	assert_eq(events.size(), 1)
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "a semente já foi cobrada: game/ precisa saber que falhou")
	assert_eq(event.motivo, FarmSystem.MOTIVO_TILE_NAO_ARADO)
	assert_eq(event.acao, "PlantCropAction")

func test_plantar_em_tile_ocupado_e_rejeitado() -> void:
	_arar(2, 3)
	_plantar("rabanete", 2, 3)
	var events := _plantar("morango", 2, 3)

	assert_eq(_state.get_plot(2, 3).crop_id, "rabanete", "a primeira cultura fica")
	assert_eq((events[0] as ActionRejectedEvent).motivo, FarmSystem.MOTIVO_TILE_OCUPADO)

func test_plantar_cultura_desconhecida_e_rejeitado() -> void:
	_arar(2, 3)
	var events := _plantar("dragao", 2, 3)

	assert_false(_state.get_plot(2, 3).tem_cultura())
	assert_eq((events[0] as ActionRejectedEvent).motivo, FarmSystem.MOTIVO_CULTURA_DESCONHECIDA)

func test_acao_ja_rejeitada_nao_encosta_no_tile() -> void:
	_arar(2, 3)
	var action := PlantCropAction.new()
	action.crop_id = "rabanete"
	action.item_id = "semente_rabanete"
	action.x = 2
	action.y = 3
	action.rejeitada = true

	assert_eq(_system.handle(action), [], "quem valida vem antes de quem executa")
	assert_false(_state.get_plot(2, 3).tem_cultura(), "sem semente, sem plantio")

func test_regar_escurece_a_terra() -> void:
	_arar(4, 4)
	var events := _regar(4, 4)

	assert_true(_state.get_plot(4, 4).regada)
	var event := events[0] as PlotWateredEvent
	assert_not_null(event, "emite PlotWateredEvent")
	assert_eq(event.x, 4)
	assert_eq(event.y, 4)
	assert_eq(event.crop_id, "", "tile arado sem planta também molha")

func test_regar_de_novo_nao_faz_nada() -> void:
	_arar(4, 4)
	_regar(4, 4)
	assert_eq(_regar(4, 4), [], "já estava molhado")

func test_regar_grama_nao_faz_nada() -> void:
	assert_eq(_regar(4, 4), [], "água em grama não vira nada")
	assert_false(_state.has_plot(4, 4), "e nem cria plot no save")

func test_colher_cultura_pronta() -> void:
	_madura("rabanete", 5, 5)
	var events := _colher(5, 5)

	var plot := _state.get_plot(5, 5)
	assert_false(plot.tem_cultura(), "cultura sem rebrota sai do tile")
	assert_true(plot.arada, "a terra continua arada")
	assert_eq(events.size(), 1)
	var event := events[0] as CropHarvestedEvent
	assert_not_null(event, "emite CropHarvestedEvent")
	assert_eq(event.crop_id, "rabanete")
	assert_eq(event.item_id, "rabanete", "o que entra na mochila é o item, não a cultura")
	assert_eq(event.qtd, 1)
	assert_false(event.rebrota)

func test_colher_cultura_verde_nao_faz_nada() -> void:
	_arar(5, 5)
	_plantar("rabanete", 5, 5)
	assert_eq(_colher(5, 5), [], "cultura verde não vem na mão")
	assert_true(_state.get_plot(5, 5).tem_cultura())

func test_colher_um_estagio_antes_da_pronta_nao_faz_nada() -> void:
	_madura("rabanete", 5, 5)
	_state.get_plot(5, 5).estagio -= 1
	assert_eq(_colher(5, 5), [], "falta um estágio")

func test_colher_tile_vazio_nao_faz_nada() -> void:
	_arar(5, 5)
	assert_eq(_colher(5, 5), [])

func test_colher_rebrota_volta_ao_estagio_anterior() -> void:
	_madura("morango", 6, 6)
	var events := _colher(6, 6)

	var plot := _state.get_plot(6, 6)
	assert_eq(plot.crop_id, "morango", "a planta fica no chão")
	assert_eq(plot.estagio, 2, "volta ao estágio anterior ao pronta")
	assert_eq(plot.dias_no_estagio, 0, "e recomeça a contagem")
	assert_true((events[0] as CropHarvestedEvent).rebrota)

func test_rende_mais_de_uma_unidade() -> void:
	_catalog.register(_def("abobora", [4, 4, 5] as Array[int], false, 3))
	_madura("abobora", 7, 7)
	assert_eq((_colher(7, 7)[0] as CropHarvestedEvent).qtd, 3)

func test_consultas_do_reticulo_nao_mudam_nada() -> void:
	assert_true(_system.pode_arar(1, 1))
	assert_false(_system.pode_plantar("rabanete", 1, 1))
	assert_false(_system.pode_regar(1, 1))
	assert_false(_system.pode_colher(1, 1))
	assert_false(_state.has_plot(1, 1), "consultar o retículo não cria plot")

	_arar(1, 1)
	assert_false(_system.pode_arar(1, 1))
	assert_true(_system.pode_plantar("rabanete", 1, 1))
	assert_true(_system.pode_regar(1, 1))
	assert_false(_system.pode_colher(1, 1))

	_plantar("rabanete", 1, 1)
	assert_false(_system.pode_plantar("rabanete", 1, 1))
	assert_false(_system.pode_colher(1, 1), "ainda verde")
	_state.get_plot(1, 1).estagio = 3
	assert_true(_system.pode_colher(1, 1))


# --- A lavoura aprende (wave 17) ---

## As vantagens chegam por `VantagemEscolhidaEvent` e a lavoura guarda a própria
## cópia. Ela nunca abre o state dos ofícios — mesmo padrão do corpo.

func _escolheu(vantagem_id: String, nivel: int,
		cultura: String = "") -> VantagemEscolhidaEvent:
	var evento := VantagemEscolhidaEvent.new()
	evento.player_id = 0
	evento.vantagem_id = vantagem_id
	evento.nivel = nivel
	evento.cultura = cultura
	return evento

func _dia_virou() -> Array[SimEvent]:
	return _system.react(DayEndedEvent.new())

## Os ids são os mesmos dos dois lados. Sem isto, uma renomeação no tabuleiro
## desligaria o efeito em silêncio — depois de o jogador já ter pago o ponto.
func test_os_ids_das_vantagens_batem_com_o_tabuleiro() -> void:
	assert_eq(FarmSystem.REGA_FUNDA, SistemaOficios.REGA_FUNDA)
	assert_eq(FarmSystem.COLHEITA_ESPECIALIZADA, SistemaOficios.COLHEITA_ESPECIALIZADA)


# --- Rega funda ---

## Sem a vantagem, a rega é de um dia só: era assim antes da wave 17 e continua
## sendo para quem não gastou o ponto.
func test_sem_rega_funda_a_agua_seca_na_virada() -> void:
	_arar(1, 1)
	_regar(1, 1)
	_dia_virou()
	assert_false(_state.get_plot(1, 1).regada, "o default preserva o de hoje")

func test_rega_funda_segura_a_agua_ate_depois_de_amanha() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 1))
	_arar(1, 1)
	_regar(1, 1)

	_dia_virou()
	assert_true(_state.get_plot(1, 1).regada, "a terra funda ainda está molhada")
	_dia_virou()
	assert_false(_state.get_plot(1, 1).regada, "mas não para sempre — é um dia a mais")

## Uma rega, dois crescimentos: é isso que a vantagem compra. Ela devolve
## relógio, e não preço de venda.
func test_uma_rega_funda_faz_a_planta_crescer_dois_dias() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 1))
	_plantar_em(1, 1)
	_regar(1, 1)

	assert_eq(_estagio(1, 1), 0)
	_dia_virou()
	assert_eq(_estagio(1, 1), 1, "cresceu com a rega de ontem")
	_dia_virou()
	assert_eq(_estagio(1, 1), 2, "e de novo, sem ninguém voltar lá")

func _plantar_em(x: int, y: int) -> void:
	_arar(x, y)
	_plantar("rabanete", x, y)

func _estagio(x: int, y: int) -> int:
	return _state.get_plot(x, y).estagio

## O teto é o que faz a vantagem ser decisão e não interruptor: os primeiros 4
## canteiros do dia seguram água, o quinto é rega comum. Quais são os quatro é o
## jogador quem decide, pela ordem em que rega — nada de sorteio.
func test_rega_funda_pega_so_os_primeiros_canteiros_do_dia() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 1))
	for i in 5:
		_arar(i, 0)
		_regar(i, 0)
	_dia_virou()

	for i in 4:
		assert_true(_state.get_plot(i, 0).regada,
				"o canteiro %d entrou na cota do dia" % i)
	assert_false(_state.get_plot(4, 0).regada,
			"o quinto é rega comum — a cota é 4 no nível 1")

func test_o_nivel_dois_dobra_a_cota() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 2))
	assert_eq(_system.cota_de_rega_funda(), 2 * FarmSystem.CANTEIROS_POR_NIVEL,
			"segundo ponto, cota dobrada")

func test_a_cota_volta_a_encher_todo_dia() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 1))
	for i in 4:
		_arar(i, 0)
		_regar(i, 0)
	assert_eq(_system.regas_fundas_hoje(), 4, "a cota do dia acabou")

	_dia_virou()
	assert_eq(_system.regas_fundas_hoje(), 0, "dia novo, cota cheia")

## Regar tile seco não é rega: não pode gastar a cota do dia.
func test_rega_recusada_nao_gasta_a_cota() -> void:
	_system.react(_escolheu(FarmSystem.REGA_FUNDA, 1))
	_regar(9, 9)
	assert_eq(_system.regas_fundas_hoje(), 0,
			"tile que ninguém arou não bebe água nem gasta cota")


# --- Colheita especializada ---

func test_sem_especializacao_o_rendimento_e_o_do_tres() -> void:
	_madura("rabanete", 1, 1)
	var eventos := _colher(1, 1)
	var colhida := eventos[0] as CropHarvestedEvent
	assert_eq(colhida.qtd, _catalog.get_def("rabanete").rende_por_colheita)

func test_a_cultura_escolhida_rende_um_a_mais() -> void:
	_system.react(_escolheu(FarmSystem.COLHEITA_ESPECIALIZADA, 1, "rabanete"))
	_madura("rabanete", 1, 1)
	var colhida := _colher(1, 1)[0] as CropHarvestedEvent
	assert_eq(colhida.qtd, _catalog.get_def("rabanete").rende_por_colheita
			+ FarmSystem.BONUS_DA_ESPECIALIZACAO,
			"o +1 é da cultura escolhida, e ele nasce na colheita — nunca no preço")

func test_as_outras_culturas_continuam_iguais() -> void:
	_system.react(_escolheu(FarmSystem.COLHEITA_ESPECIALIZADA, 1, "rabanete"))
	_madura("morango", 2, 2)
	var colhida := _colher(2, 2)[0] as CropHarvestedEvent
	assert_eq(colhida.qtd, _catalog.get_def("morango").rende_por_colheita,
			"escolher uma é abrir mão das outras")

func test_a_especializacao_vale_na_rebrota_tambem() -> void:
	_system.react(_escolheu(FarmSystem.COLHEITA_ESPECIALIZADA, 1, "morango"))
	_madura("morango", 2, 2)
	var primeira := _colher(2, 2)[0] as CropHarvestedEvent
	_state.get_plot(2, 2).estagio = _catalog.get_def("morango").estagio_pronta()
	var segunda := _colher(2, 2)[0] as CropHarvestedEvent
	assert_eq(primeira.qtd, segunda.qtd, "a planta que rebrota rende igual toda vez")


# --- O que não é dela ---

func test_vantagem_de_outro_dono_nao_mexe_na_lavoura() -> void:
	_system.react(_escolheu(SistemaOficios.MAOS_LEVES, 2))
	_arar(1, 1)
	_regar(1, 1)
	_dia_virou()
	assert_false(_state.get_plot(1, 1).regada,
			"Mãos leves é do corpo — a lavoura ignora o que não é dela")

## O laço inteiro pela porta da frente: a compra atravessa a fila do `SimWorld` e
## chega à lavoura sem ninguém ler state alheio.
func test_a_compra_chega_a_lavoura_pela_fila() -> void:
	var factory := SimFactory.new()
	var world := factory.build()
	factory.get_estado_oficios().credita_pontos(0, SistemaOficios.LAVOURA, 1)

	var acao := EscolherVantagemAction.new()
	acao.player_id = 0
	acao.vantagem_id = SistemaOficios.REGA_FUNDA
	world.handle(acao)

	for system in world.get_systems():
		if system is FarmSystem:
			assert_eq((system as FarmSystem).cota_de_rega_funda(),
					FarmSystem.CANTEIROS_POR_NIVEL,
					"o efeito viaja por evento, e o dono guarda a própria cópia")
			return
	fail_test("o FarmSystem sumiu do tick")
