extends GutTest

## O corpo cobrando o trabalho: cada golpe desconta, zero desmaia, e a manhã
## devolve o que a noite dever.
##
## ## Ele reage, não valida
##
## Nenhuma ação passa por aqui. A ordem do tick não comporta um validador de
## estamina — ele teria que vir antes do `InventorySystem` (que cobra a semente)
## e depois do `SistemaTerreno` (que recusa a limpeza impossível), e não existe
## posição que satisfaça as duas. Reagindo ao evento, o corpo só desconta o que
## **aconteceu de verdade**: ação recusada não cansa ninguém, e é isso que estes
## testes prendem.
##
## ## Zero é desmaio, nunca recusa
##
## Chegar ao fim não bloqueia o botão: emite `DesmaiouEvent`, e quem fecha o dia
## é o `TimeSystem`. Apertar o botão e nada acontecer, no meio do canteiro, é o
## pior momento de jogo que esta mecânica poderia produzir.
##
## ## Andar não cansa
##
## O relógio cobra o deslocamento e o corpo cobra o trabalho. Um dia de só ir à
## cidade, entregar e voltar não gasta estamina — se gastasse, a rota da água da
## wave 14.1 passaria a ter dois preços somados.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

## Comida de mentira, com os números redondos que a conta da saciedade precisa.
## O corpo não pode depender do conteúdo do jogo para ser testado — quem prende
## os valores reais é `test_item_defs.gd`.
const PAO: String = "pao_de_teste"
const RAIZ: String = "raiz_de_teste"
const MIGALHA: String = "migalha_de_teste"
const PEDRA: String = "pedra_de_teste"

const RESTAURO_DO_PAO: int = 100
const RESTAURO_DA_RAIZ: int = 20

var _estado: EstadoCorpo
var _items: ItemCatalog
var _sistema: SistemaCorpo


func before_each() -> void:
	_estado = EstadoCorpo.new()
	_items = _catalogo()
	_sistema = SistemaCorpo.new(_estado, _items)

func _catalogo() -> ItemCatalog:
	var catalogo := ItemCatalog.new()
	catalogo.register(_comida(PAO, RESTAURO_DO_PAO))
	catalogo.register(_comida(RAIZ, RESTAURO_DA_RAIZ))
	catalogo.register(_comida(MIGALHA, 1))
	catalogo.register(_comida(PEDRA, 0))
	return catalogo

func _comida(id: String, restaura: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	def.restaura_estamina = restaura
	return def

## Come pela porta da frente, como o `SimWorld` oferece a ação.
func _come(item_id: String) -> Array[SimEvent]:
	var acao := ComerAction.new()
	acao.player_id = JOGADOR
	acao.item_id = item_id
	return _sistema.handle(acao)


# --- Fabriquinhas de evento, como a sim os emite ---

func _arou() -> PlotTilledEvent:
	var evento := PlotTilledEvent.new()
	evento.player_id = JOGADOR
	evento.x = 1
	evento.y = 1
	return evento

func _regou() -> PlotWateredEvent:
	var evento := PlotWateredEvent.new()
	evento.player_id = JOGADOR
	return evento

func _plantou() -> CropPlantedEvent:
	var evento := CropPlantedEvent.new()
	evento.player_id = JOGADOR
	evento.crop_id = "rabanete"
	return evento

func _colheu() -> CropHarvestedEvent:
	var evento := CropHarvestedEvent.new()
	evento.player_id = JOGADOR
	evento.crop_id = "rabanete"
	return evento

func _limpou(de: String) -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.player_id = JOGADOR
	evento.de = de
	evento.para = EstadoTerreno.LIVRE
	evento.motivo = TerrenoMudouEvent.POR_LIMPEZA
	return evento

func _noite(motivo: String) -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.de = EstadoTerreno.LIVRE
	evento.para = EstadoTerreno.MATO
	evento.motivo = motivo
	return evento

func _dia_acabou(cause: DayEndedEvent.Cause) -> DayEndedEvent:
	var evento := DayEndedEvent.new()
	evento.cause = cause
	return evento

## Cansa o jogador até faltar `quanto` para o fim.
func _cansa_ate_faltar(quanto: int) -> void:
	_estado.gasta(JOGADOR, _estado.maxima_de(JOGADOR) - quanto)


# --- A tabela de custos ---

func test_cada_trabalho_tem_custo() -> void:
	for trabalho in SistemaCorpo.TRABALHOS:
		assert_gt(_sistema.custo_de(trabalho), 0,
				"trabalho '%s' sem custo é trabalho de graça" % trabalho)

func test_trabalho_desconhecido_nao_custa_nada() -> void:
	assert_eq(_sistema.custo_de("pescar"), 0,
			"mecânica que ainda não existe não pode cansar ninguém")

func test_arar_custa_mais_que_plantar() -> void:
	assert_gt(_sistema.custo_de(SistemaCorpo.ARAR), _sistema.custo_de(SistemaCorpo.PLANTAR),
			"quebrar a terra é o trabalho pesado do ciclo")

func test_arvore_e_o_golpe_mais_caro() -> void:
	for trabalho in SistemaCorpo.TRABALHOS:
		assert_true(_sistema.custo_de(SistemaCorpo.LIMPAR_ARVORE)
				>= _sistema.custo_de(trabalho),
				"derrubar árvore tem que ser o golpe mais caro (contra %s)" % trabalho)


# --- O trabalho desconta ---

func test_arar_desconta_o_custo_de_arar() -> void:
	var eventos := _sistema.react(_arou())
	assert_eq(_estado.estamina_de(JOGADOR),
			EstadoCorpo.ESTAMINA_PADRAO - SistemaCorpo.CUSTO_ARAR)
	assert_eq(eventos.size(), 1, "um desconto, um evento")
	var gasto := eventos[0] as EstaminaGastaEvent
	assert_not_null(gasto, "o evento é EstaminaGastaEvent")
	assert_eq(gasto.trabalho, SistemaCorpo.ARAR)
	assert_eq(gasto.custo, SistemaCorpo.CUSTO_ARAR)
	assert_eq(gasto.de, EstadoCorpo.ESTAMINA_PADRAO, "o evento traz a transição inteira")
	assert_eq(gasto.para, EstadoCorpo.ESTAMINA_PADRAO - SistemaCorpo.CUSTO_ARAR)
	assert_eq(gasto.maxima, EstadoCorpo.ESTAMINA_PADRAO,
			"e o teto, para a tela desenhar a barra sem abrir o state")

func test_o_ciclo_inteiro_do_canteiro_cansa() -> void:
	_sistema.react(_arou())
	_sistema.react(_plantou())
	_sistema.react(_regou())
	_sistema.react(_colheu())
	var esperado := SistemaCorpo.CUSTO_ARAR + SistemaCorpo.CUSTO_PLANTAR \
		+ SistemaCorpo.CUSTO_REGAR + SistemaCorpo.CUSTO_COLHER
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - esperado)

func test_limpar_cobra_pelo_que_estava_no_caminho() -> void:
	_sistema.react(_limpou(EstadoTerreno.ARVORE))
	assert_eq(_estado.estamina_de(JOGADOR),
			EstadoCorpo.ESTAMINA_PADRAO - SistemaCorpo.CUSTO_LIMPAR_ARVORE,
			"a árvore cobra pela árvore, não pelo toco que ela virou")

func test_derrubar_e_arrancar_sao_dois_golpes_e_dois_precos() -> void:
	_sistema.react(_limpou(EstadoTerreno.ARVORE))
	_sistema.react(_limpou(EstadoTerreno.TOCO))
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO
			- SistemaCorpo.CUSTO_LIMPAR_ARVORE - SistemaCorpo.CUSTO_LIMPAR_TOCO)

func test_o_mato_da_noite_nao_cansa_ninguem() -> void:
	_sistema.react(_noite(TerrenoMudouEvent.POR_INVASAO))
	_sistema.react(_noite(TerrenoMudouEvent.POR_FECHAMENTO))
	_sistema.react(_noite(TerrenoMudouEvent.POR_GERACAO))
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"quem trabalhou foi a noite — o motivo é quem separa")

func test_andar_nao_cansa() -> void:
	var viajou := JogadorViajouEvent.new()
	viajou.player_id = JOGADOR
	assert_eq(_sistema.react(viajou), [] as Array[SimEvent])
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"o relógio já cobra o deslocamento; cobrar de novo somaria dois preços")

func test_entregar_na_cidade_nao_cansa() -> void:
	var entrega := EntregaAceitaEvent.new()
	entrega.player_id = JOGADOR
	assert_eq(_sistema.react(entrega), [] as Array[SimEvent])
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO)

func test_o_corpo_certo_e_o_de_quem_agiu() -> void:
	var evento := _arou()
	evento.player_id = 7
	_sistema.react(evento)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"o cansaço é de quem trabalhou, não do jogador 0")
	assert_lt(_estado.estamina_de(7), EstadoCorpo.ESTAMINA_PADRAO)


# --- O desmaio ---

func test_chegar_a_zero_desmaia() -> void:
	_cansa_ate_faltar(SistemaCorpo.CUSTO_ARAR)
	var eventos := _sistema.react(_arou())

	assert_eq(eventos.size(), 2, "o gasto vem primeiro, o desmaio depois")
	assert_true(eventos[0] is EstaminaGastaEvent, "causa antes de consequência")
	var desmaio := eventos[1] as DesmaiouEvent
	assert_not_null(desmaio, "o segundo evento é DesmaiouEvent")
	assert_eq(desmaio.player_id, JOGADOR)
	assert_eq(desmaio.trabalho, SistemaCorpo.ARAR, "o evento diz o que derrubou")

func test_o_ultimo_golpe_acontece_inteiro() -> void:
	_cansa_ate_faltar(1)
	var gasto := _sistema.react(_limpou(EstadoTerreno.PEDRA))[0] as EstaminaGastaEvent
	assert_eq(gasto.custo, SistemaCorpo.CUSTO_LIMPAR_PEDRA,
			"o custo cobrado é o do trabalho, mesmo com o corpo no fim")
	assert_eq(gasto.para, 0, "e a estamina para em zero, nunca negativa")

func test_nao_desmaia_duas_vezes_seguidas() -> void:
	_cansa_ate_faltar(0)
	assert_eq(_sistema.react(_arou()), [] as Array[SimEvent],
			"quem já caiu não desconta de novo — o dia dele acabou")

func test_trabalhar_sem_zerar_nao_desmaia() -> void:
	assert_eq(_sistema.react(_arou()).size(), 1, "só o gasto")


# --- A manhã ---

func test_dormir_enche() -> void:
	_sistema.react(_arou())
	_sistema.react(_dia_acabou(DayEndedEvent.Cause.SLEPT))
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"dormir sempre enche — o dia de amanhã não depende do de ontem")

func test_desmaiar_acorda_com_metade() -> void:
	_cansa_ate_faltar(0)
	_sistema.react(_dia_acabou(DayEndedEvent.Cause.COLLAPSED))
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO / 2,
			"o preço do desmaio é tempo de trabalho, e ele se paga sozinho")

func test_a_manha_nao_emite_evento() -> void:
	_sistema.react(_arou())
	assert_eq(_sistema.react(_dia_acabou(DayEndedEvent.Cause.SLEPT)),
			[] as Array[SimEvent],
			"encher não é fato que alguém precise animar — a tela relê a barra")

func test_a_manha_nao_inventa_corpo_para_quem_nunca_trabalhou() -> void:
	_sistema.react(_dia_acabou(DayEndedEvent.Cause.SLEPT))
	assert_eq(_estado.jogadores(), [] as Array[int],
			"restaurar quem já estava cheio só encheria o save")


# --- Quanto ainda cabe (a pergunta que a aba Corpo faz) ---

func test_quantas_acoes_ainda_cabem() -> void:
	_cansa_ate_faltar(10)
	assert_eq(_sistema.acoes_restantes(SistemaCorpo.PLANTAR, JOGADOR), 10,
			"10 de estamina e 1 por planta = 10 plantas")
	assert_eq(_sistema.acoes_restantes(SistemaCorpo.ARAR, JOGADOR), 2,
			"10 de estamina e 4 por arada = 2 aradas e um golpe que derruba")

func test_acoes_restantes_de_trabalho_desconhecido() -> void:
	assert_eq(_sistema.acoes_restantes("pescar", JOGADOR), 0,
			"não dá para prometer ação de mecânica que não existe")


# --- No mundo ---

func test_o_sistema_entra_no_tick_depois_do_farm() -> void:
	var world := SimFactory.new().build()
	var corpo := -1
	var farm := -1
	var sistemas := world.get_systems()
	for i in sistemas.size():
		if sistemas[i] is FarmSystem:
			farm = i
		if sistemas[i] is SistemaCorpo:
			corpo = i
	assert_gt(corpo, farm, "o corpo lê eventos de trabalho já emitidos no tick")

func test_o_corpo_entra_no_save_no_fim_do_arquivo() -> void:
	var world := SimFactory.new().build()
	assert_true(world.snapshot().has(SimFactory.CHAVE_CORPO),
			"state que não é registrado não existe para o save")
	var chaves := world.state_keys()
	assert_eq(chaves[chaves.size() - 1], SimFactory.CHAVE_CORPO,
			"bloco novo entra no fim — save antigo carrega sem migração")

func test_sistema_nasce_com_state_proprio() -> void:
	assert_eq(SistemaCorpo.new().get_state().estamina_de(JOGADOR),
			EstadoCorpo.ESTAMINA_PADRAO, "sem state injetado, cria o próprio")

## O laço inteiro, pela porta da frente: uma enxadada com o corpo no fim tem que
## sair da ação, passar pelo corpo, chegar ao relógio e voltar como manhã.
##
## É o teste que prende a fila de redistribuição do `SimWorld`: o `TimeSystem`
## está **atrás** do corpo na ordem, e mesmo assim escuta o desmaio.
func test_desmaiar_arando_fecha_o_dia_e_acorda_com_metade() -> void:
	var factory := SimFactory.new()
	var world := factory.build()
	var corpo := factory.get_estado_corpo()
	corpo.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO - SistemaCorpo.CUSTO_ARAR)

	var acao := TillPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = 3
	acao.y = 3
	var eventos := world.handle(acao)

	var tipos: Array[String] = []
	for evento in eventos:
		tipos.append(evento.get_script().get_global_name())
	assert_true(tipos.has("EstaminaGastaEvent"), "o trabalho aconteceu e cobrou")
	assert_true(tipos.has("DesmaiouEvent"), "e derrubou: %s" % str(tipos))
	assert_true(tipos.has("DayEndedEvent"), "e o dia acabou: %s" % str(tipos))
	assert_eq(factory.get_time_state().dia, 2, "o calendário virou")
	assert_eq(corpo.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO / 2,
			"e o jogador acorda com metade — o preço se paga sozinho")


# --- A mesa: comer (wave 15.1) ---

## O corpo passou a tratar **uma** ação, e só uma. Ele continua sem validar
## trabalho: arar, regar e limpar seguem entrando por evento consumado.
func test_comer_restaura_a_estamina() -> void:
	_estado.gasta(JOGADOR, 150)
	_come(PAO)
	assert_eq(_estado.estamina_de(JOGADOR),
			EstadoCorpo.ESTAMINA_PADRAO - 150 + RESTAURO_DO_PAO,
			"a primeira refeição do dia vale o número cheio do .tres")

func test_o_evento_conta_a_mordida_inteira() -> void:
	_estado.gasta(JOGADOR, 150)
	var eventos := _come(PAO)
	assert_eq(eventos.size(), 1, "uma refeição, um evento")
	var comeu := eventos[0] as ComeuEvent
	assert_not_null(comeu, "o evento é ComeuEvent")
	assert_eq(comeu.player_id, JOGADOR)
	assert_eq(comeu.item_id, PAO)
	assert_eq(comeu.refeicao, 1, "qual refeição do dia foi esta")
	assert_eq(comeu.restaurou, RESTAURO_DO_PAO, "o valor efetivo da refeição")
	assert_eq(comeu.de, EstadoCorpo.ESTAMINA_PADRAO - 150, "a transição inteira")
	assert_eq(comeu.para, EstadoCorpo.ESTAMINA_PADRAO - 150 + RESTAURO_DO_PAO)
	assert_eq(comeu.maxima, EstadoCorpo.ESTAMINA_PADRAO,
			"e o teto, para a barra da tela não abrir state nenhum")

## Comer não é trabalho: nada de `EstaminaGastaEvent` no caminho de volta.
func test_comer_nao_cansa_ninguem() -> void:
	_estado.gasta(JOGADOR, 100)
	for evento in _come(PAO):
		assert_null(evento as EstaminaGastaEvent, "comer não cobra o corpo")


# --- A saciedade ---

## 100%, 50%, 25%, 10% — o freio que impede a mochila de pão de apagar o corpo.
func test_cada_refeicao_do_dia_vale_menos_que_a_anterior() -> void:
	var valores: Array[int] = []
	for _i in 4:
		# devolve o corpo ao fundo para cada mordida caber inteira
		_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
		_estado.restaura(JOGADOR, 10)
		var comeu := _come(PAO)[0] as ComeuEvent
		valores.append(comeu.restaurou)
	assert_eq(valores, [100, 50, 25, 10] as Array[int],
			"1ª cheia, 2ª metade, 3ª um quarto, 4ª um décimo")

func test_da_quarta_em_diante_e_sempre_um_decimo() -> void:
	for _i in 6:
		_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
		_estado.restaura(JOGADOR, 10)
		var comeu := _come(PAO)[0] as ComeuEvent
		assert_true(comeu.restaurou >= RESTAURO_DO_PAO / 10,
				"a mesa não vira zero: a 7ª refeição vale o mesmo que a 4ª")
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 6)

## Uma mordida sempre é uma mordida. Item que some sem devolver nada é o bug que
## a `pode_comer()` existe para evitar — arredondar para zero seria o mesmo bug
## por outro caminho.
func test_uma_mordida_nunca_vale_zero() -> void:
	_estado.gasta(JOGADOR, 100)
	for _i in 3:
		_come(MIGALHA)
	var comeu := _come(MIGALHA)[0] as ComeuEvent
	assert_eq(comeu.restaurou, 1, "o piso é 1 para qualquer comida de verdade")

## Comer com a saciedade no fundo não é recusado: restaura pouco, mas a decisão
## é do jogador. A tela mostra o valor efetivo antes do clique.
func test_saciedade_no_fundo_nao_recusa() -> void:
	_estado.gasta(JOGADOR, 190)
	for _i in 3:
		_come(RAIZ)
	var eventos := _come(RAIZ)
	assert_not_null(eventos[0] as ComeuEvent, "o jogador pode desperdiçar se quiser")

func test_a_conta_da_saciedade_e_do_sistema() -> void:
	assert_almost_eq(SistemaCorpo.fator_da_refeicao(1), 1.0, 0.001)
	assert_almost_eq(SistemaCorpo.fator_da_refeicao(2), 0.5, 0.001)
	assert_almost_eq(SistemaCorpo.fator_da_refeicao(3), 0.25, 0.001)
	assert_almost_eq(SistemaCorpo.fator_da_refeicao(9), 0.1, 0.001,
			"da quarta em diante é o piso")
	assert_almost_eq(SistemaCorpo.fator_da_refeicao(0), 1.0, 0.001,
			"refeição inválida vale a primeira")


# --- O teto ---

## Comer cedo demais desperdiça: o que passa do topo se perde, e o evento conta
## a verdade — `restaurou` é o que a refeição valia, `de`→`para` é o que entrou.
func test_o_que_passa_do_teto_se_perde() -> void:
	_estado.gasta(JOGADOR, 10)
	var comeu := _come(PAO)[0] as ComeuEvent
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO)
	assert_eq(comeu.restaurou, RESTAURO_DO_PAO, "a refeição valia 100")
	assert_eq(comeu.para - comeu.de, 10, "e só 10 couberam")


# --- Recusas ---

func test_comer_com_a_barra_cheia_e_recusado() -> void:
	var acao := ComerAction.new()
	acao.player_id = JOGADOR
	acao.item_id = PAO
	var eventos := _sistema.handle(acao)
	var recusa := eventos[0] as ActionRejectedEvent
	assert_not_null(recusa, "recusa é ActionRejectedEvent")
	assert_eq(recusa.motivo, SistemaCorpo.MOTIVO_ESTAMINA_CHEIA)
	assert_true(acao.rejeitada, "a ação sai carimbada")
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0, "refeição recusada não conta na mesa")

func test_o_que_nao_alimenta_e_recusado() -> void:
	_estado.gasta(JOGADOR, 100)
	var recusa := _come(PEDRA)[0] as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaCorpo.MOTIVO_NAO_E_COMIDA)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 100)

func test_item_fora_do_catalogo_nao_alimenta() -> void:
	_estado.gasta(JOGADOR, 100)
	var recusa := _come("nada_disso")[0] as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaCorpo.MOTIVO_NAO_E_COMIDA)

## Chegou a zero, o dia acabou. Comida é o que **evita** o desmaio, nunca o que
## o desfaz.
func test_desmaiado_nao_come() -> void:
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
	var recusa := _come(PAO)[0] as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaCorpo.MOTIVO_DESMAIADO)
	assert_eq(_estado.estamina_de(JOGADOR), 0, "o chão continua sendo o chão")

## O `InventorySystem` vem antes e recusa por `item_insuficiente`. O corpo não
## trata o que já foi carimbado — senão comeria o que não existe.
func test_acao_ja_recusada_nao_chega_a_mesa() -> void:
	_estado.gasta(JOGADOR, 100)
	var acao := ComerAction.new()
	acao.player_id = JOGADOR
	acao.item_id = PAO
	acao.rejeitada = true
	assert_eq(_sistema.handle(acao), [] as Array[SimEvent])
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 100)


# --- A pergunta que game/ faz antes ---

## `ComerAction` estende `RemoveItemAction`: o inventário cobra o item antes de
## o corpo olhar qualquer coisa. Um clique errado com a barra cheia queimaria o
## pão em silêncio — por isso `game/` pergunta primeiro.
func test_pode_comer_responde_o_mesmo_que_o_handle() -> void:
	assert_false(_sistema.pode_comer(JOGADOR, PAO), "com a barra cheia, não")
	_estado.gasta(JOGADOR, 1)
	assert_true(_sistema.pode_comer(JOGADOR, PAO), "com um ponto faltando, sim")
	assert_false(_sistema.pode_comer(JOGADOR, PEDRA), "pedra nunca")
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
	assert_false(_sistema.pode_comer(JOGADOR, PAO), "desmaiado nunca")

func test_quanto_esta_comida_restaura_agora() -> void:
	_estado.gasta(JOGADOR, 190)
	assert_eq(_sistema.restauro_de(PAO, JOGADOR), RESTAURO_DO_PAO,
			"a primeira do dia vale inteira")
	_come(PAO)
	assert_eq(_sistema.restauro_de(PAO, JOGADOR), RESTAURO_DO_PAO / 2,
			"depois de uma, a próxima vale metade")

func test_o_que_nao_e_comida_nao_restaura_nada() -> void:
	assert_eq(_sistema.restauro_de(PEDRA, JOGADOR), 0)
	assert_eq(_sistema.restauro_de("nada_disso", JOGADOR), 0)
	assert_false(_sistema.e_comida(PEDRA))
	assert_true(_sistema.e_comida(PAO))

func test_qual_refeicao_vem_a_seguir() -> void:
	assert_eq(_sistema.proxima_refeicao(JOGADOR), 1, "o dia começa com a mesa limpa")
	_estado.gasta(JOGADOR, 100)
	_come(PAO)
	assert_eq(_sistema.proxima_refeicao(JOGADOR), 2)
	assert_almost_eq(_sistema.fator_agora(JOGADOR), 0.5, 0.001)


# --- A manhã limpa a mesa ---

func test_dormir_limpa_a_mesa() -> void:
	_estado.gasta(JOGADOR, 100)
	_come(PAO)
	_sistema.react(_dia_acabou(DayEndedEvent.Cause.SLEPT))
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0, "dia novo, refeição cheia de novo")
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO)

## A saciedade é do dia, e o dia acabou — inclusive quando acabou no chão. Se
## isso parecer generoso demais, o `cause` está no evento e dá para diferenciar.
func test_desmaiar_tambem_limpa_a_mesa() -> void:
	_estado.gasta(JOGADOR, 100)
	_come(PAO)
	_sistema.react(_dia_acabou(DayEndedEvent.Cause.COLLAPSED))
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO / 2)


# --- No mundo, pela porta da frente ---

## O pão sai da mochila e entra no corpo, com o `InventorySystem` cobrando antes
## e o corpo restaurando depois. É a ordem fixa fazendo o trabalho dela.
func test_comer_o_pao_de_verdade_tira_da_mochila_e_enche_o_corpo() -> void:
	var factory := SimFactory.new()
	var world := factory.build()
	var corpo := factory.get_estado_corpo()
	corpo.gasta(JOGADOR, 150)

	var ganha := AddItemAction.new()
	ganha.player_id = JOGADOR
	ganha.item_id = "pao"
	ganha.qtd = 1
	world.handle(ganha)

	var acao := ComerAction.new()
	acao.player_id = JOGADOR
	acao.item_id = "pao"
	var tipos: Array[String] = []
	for evento in world.handle(acao):
		tipos.append(evento.get_script().get_global_name())

	assert_true(tipos.has("ItemRemovedEvent"), "o pão saiu da mochila: %s" % str(tipos))
	assert_true(tipos.has("ComeuEvent"), "e entrou no corpo: %s" % str(tipos))
	assert_eq(factory.get_inventory_state().get_player(JOGADOR).count("pao"), 0)
	assert_gt(corpo.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 150,
			"a barra subiu")

## Sem o pão na mochila, quem recusa é o inventário — e o corpo não restaura
## nada de graça.
func test_comer_o_que_nao_se_tem_nao_alimenta() -> void:
	var factory := SimFactory.new()
	var world := factory.build()
	var corpo := factory.get_estado_corpo()
	corpo.gasta(JOGADOR, 150)

	var acao := ComerAction.new()
	acao.player_id = JOGADOR
	acao.item_id = "pao"
	world.handle(acao)
	assert_eq(corpo.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 150,
			"ação recusada pelo inventário não alimenta ninguém")
	assert_eq(corpo.refeicoes_hoje(JOGADOR), 0, "nem conta na mesa do dia")

## A fiação: o corpo lê `restaura_estamina` do catálogo que a fábrica montou. Sem
## isso, comida nova em `.tres` não chegaria ao corpo.
func test_o_corpo_recebe_o_catalogo_de_itens_da_fabrica() -> void:
	var world := SimFactory.new().build()
	for system in world.get_systems():
		if system is SistemaCorpo:
			assert_true((system as SistemaCorpo).e_comida("pao"),
					"o corpo tem que enxergar o .tres do pão")
			return
	fail_test("o SistemaCorpo sumiu do tick")
