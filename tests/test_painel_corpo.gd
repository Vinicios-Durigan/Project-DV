extends GutTest

## A aba Corpo: o que cada trabalho custa, quanto o dia já cobrou e quanto ainda
## cabe antes do desmaio.
##
## ## Por que uma aba, e não só a barra do topo
##
## A barra de status responde "quanto resta" — e é só isso que ela pode
## responder no canto do olho. A pergunta que decide o dia é outra: **quantas
## aradas ainda cabem?** Ela precisa da tabela de custos ao lado do número, e
## tabela não cabe numa faixa de 32 pixels.
##
## Esta aba é também o instrumento de calibragem da wave: o teto de 200 e a
## tabela de custos são chute, e "o gasto de hoje, trabalho a trabalho" é o dado
## que diz se a barra raspa junto com o relógio ou muito antes dele.
##
## ## Nenhum custo é calculado aqui
##
## Custo e quantas ações cabem são **perguntas de regra**, e as duas saem do
## `SistemaCorpo` — do mesmo jeito que `cota_de` e `pode_entregar` saem da
## cidade. Este arquivo pergunta e formata. Quando a aba e a sim discordarem,
## quem errou é a aba.
##
## O gasto do dia é a única coisa somada deste lado, e ela não é regra: é o
## total do que os `EstaminaGastaEvent` já contaram, zerado na virada do dia —
## o mesmo espírito do histórico de sessão do `PainelAmizade`.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _bridge: SimBridge
var _playground: Playground
var _modal: PainelMochila
var _painel: PainelCorpo


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_modal = _playground.get_node("PainelMochila") as PainelMochila
	_painel = _modal.painel_corpo()

func _sistema() -> SistemaCorpo:
	for system in _bridge.get_world().get_systems():
		if system is SistemaCorpo:
			return system as SistemaCorpo
	return null

func _corpo() -> EstadoCorpo:
	return _bridge.get_factory().get_estado_corpo()

func _ara(x: int, y: int) -> void:
	var acao := TillPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = x
	acao.y = y
	_bridge.dispatch(acao)


# --- A aba ---

func test_o_corpo_e_uma_aba_do_tab() -> void:
	assert_true(PainelMochila.ABAS.has(PainelMochila.ABA_CORPO),
			"mecânica sem tela própria não pressiona ninguém")

func test_a_aba_aparece_quando_pedida() -> void:
	_modal.mostra_aba(PainelMochila.ABA_CORPO)
	assert_true(_modal.corpo_visivel())
	assert_false(_modal.mochila_visivel(), "uma aba de cada vez")
	assert_eq(_modal.aba_atual(), PainelMochila.ABA_CORPO)


# --- Tudo o que é regra vem do sistema ---

func test_lista_todos_os_trabalhos_que_a_sim_conhece() -> void:
	assert_eq(_painel.trabalhos(), SistemaCorpo.TRABALHOS,
			"a lista não mora nesta tela — trabalho novo aparece sozinho")

func test_o_custo_de_cada_trabalho_e_o_do_sistema() -> void:
	for trabalho in _painel.trabalhos():
		assert_eq(_painel.custo(trabalho), _sistema().custo_para(JOGADOR, trabalho),
				"o custo de '%s' é resposta do sistema" % trabalho)

## O custo mostrado é o **deste** corpo, não o de tabela: quem comprou Mãos leves
## planta de graça, e esta aba não pode ser a única tela que ainda cobra por isso.
func test_a_tabela_enxerga_a_vantagem_comprada() -> void:
	var evento := VantagemEscolhidaEvent.new()
	evento.player_id = JOGADOR
	evento.vantagem_id = SistemaOficios.MAOS_LEVES
	evento.nivel = 1
	_sistema().react(evento)
	assert_eq(_painel.custo(SistemaCorpo.PLANTAR), 0)
	assert_eq(_painel.custo(SistemaCorpo.ARAR), SistemaCorpo.CUSTO_ARAR,
			"e só o que a vantagem alivia muda")

func test_quantas_acoes_cabem_e_o_do_sistema() -> void:
	_corpo().gasta(JOGADOR, 150)
	for trabalho in _painel.trabalhos():
		assert_eq(_painel.cabem(trabalho),
				_sistema().acoes_restantes(trabalho, JOGADOR),
				"quantas '%s' ainda cabem é pergunta de regra" % trabalho)

func test_o_que_cabe_encolhe_com_o_cansaco() -> void:
	var antes := _painel.cabem(SistemaCorpo.ARAR)
	_corpo().gasta(JOGADOR, 100)
	assert_lt(_painel.cabem(SistemaCorpo.ARAR), antes,
			"a tela não guarda cópia: ela pergunta de novo")

func test_a_barra_mostra_o_corpo_de_agora() -> void:
	_corpo().gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO / 2)
	assert_eq(_painel.estamina(), EstadoCorpo.ESTAMINA_PADRAO / 2)
	assert_eq(_painel.maxima(), EstadoCorpo.ESTAMINA_PADRAO)
	assert_almost_eq(_painel.fracao(), 0.5, 0.001)


# --- O gasto do dia ---

func test_o_dia_comeca_sem_gasto() -> void:
	assert_eq(_painel.gasto_do_dia(), 0)
	for trabalho in _painel.trabalhos():
		assert_eq(_painel.vezes_hoje(trabalho), 0)

func test_arar_entra_na_conta_do_dia() -> void:
	_ara(2, 2)
	assert_eq(_painel.gasto_do_dia(), SistemaCorpo.CUSTO_ARAR,
			"o total é o que os eventos contaram, não uma conta desta tela")
	assert_eq(_painel.vezes_hoje(SistemaCorpo.ARAR), 1)
	assert_eq(_painel.vezes_hoje(SistemaCorpo.REGAR), 0,
			"cada trabalho conta o próprio")

func test_dois_trabalhos_somam() -> void:
	_ara(2, 2)
	_ara(3, 2)
	assert_eq(_painel.gasto_do_dia(), SistemaCorpo.CUSTO_ARAR * 2)
	assert_eq(_painel.vezes_hoje(SistemaCorpo.ARAR), 2)

func test_dormir_zera_a_conta_do_dia() -> void:
	_ara(2, 2)
	_bridge.dispatch(SleepAction.new())
	assert_eq(_painel.gasto_do_dia(), 0, "dia novo, conta nova")
	assert_eq(_painel.vezes_hoje(SistemaCorpo.ARAR), 0)


# --- Texto ---

func test_a_linha_junta_custo_e_quanto_cabe() -> void:
	_ara(2, 2)
	var linha := _painel.texto_da_linha(SistemaCorpo.ARAR)
	assert_string_contains(linha, str(SistemaCorpo.CUSTO_ARAR), "o custo aparece")
	assert_string_contains(linha, str(_painel.cabem(SistemaCorpo.ARAR)),
			"e quantas ainda cabem")

func test_o_resumo_do_dia_mostra_o_total() -> void:
	_ara(2, 2)
	assert_string_contains(_painel.texto_do_dia(), str(SistemaCorpo.CUSTO_ARAR),
			"o gasto do dia é o número que calibra o teto de estamina")


# --- A mesa (wave 15.1) ---

## A comida que está na mochila, e só ela. Quem responde "isto se come?" é o
## sistema, lendo o `.tres` — a lista não é escrita nesta tela, e comida nova
## aparece aqui sozinha.

func _da(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.player_id = JOGADOR
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

func test_a_mesa_comeca_vazia() -> void:
	assert_eq(_painel.comidas(), [] as Array[String],
			"o primeiro dia é ferramenta e semente — nada que se coma")

func test_a_mesa_lista_so_o_que_alimenta() -> void:
	_da("pao", 2)
	_da("trigo", 5)
	assert_eq(_painel.comidas(), ["pao"] as Array[String],
			"trigo não se come cru, e ferramenta muito menos")

func test_a_mesa_sai_em_ordem_fixa() -> void:
	_da("pao", 1)
	_da("cenoura", 1)
	assert_eq(_painel.comidas(), ["cenoura", "pao"] as Array[String],
			"a ordem não pode depender de qual slot o item caiu")

func test_a_mesa_conta_quantas_tem_na_mochila() -> void:
	_da("pao", 3)
	assert_eq(_painel.quantidade("pao"), 3)

func test_uma_linha_por_comida() -> void:
	_da("pao", 2)
	_da("cenoura", 1)
	assert_eq(_painel.linhas_da_mesa(), 2, "a mesa desenha o que a mochila tem")


# --- Quanto restaura agora: pergunta de regra ---

## O número da tela é o **efetivo**, com a saciedade do dia aplicada — nunca o
## cru do `.tres`. Quem faz a conta é o sistema.
func test_quanto_restaura_agora_vem_do_sistema() -> void:
	_da("pao", 1)
	assert_eq(_painel.restaura_agora("pao"),
			_sistema().restauro_de("pao", JOGADOR),
			"a tela pergunta e formata, não calcula")

func test_o_valor_encolhe_depois_da_primeira_refeicao() -> void:
	_da("pao", 2)
	_corpo().gasta(JOGADOR, 150)
	var cheia := _painel.restaura_agora("pao")
	_painel.come("pao")
	assert_lt(_painel.restaura_agora("pao"), cheia,
			"a segunda refeição do dia vale metade — a tela mostra antes do clique")

func test_a_mesa_diz_qual_refeicao_vem_a_seguir() -> void:
	assert_eq(_painel.proxima_refeicao(), 1, "o dia começa com a mesa limpa")
	_da("pao", 1)
	_corpo().gasta(JOGADOR, 150)
	_painel.come("pao")
	assert_eq(_painel.proxima_refeicao(), 2)
	assert_almost_eq(_painel.fator_agora(), _sistema().fator_agora(JOGADOR), 0.001)

func test_o_texto_da_linha_junta_quantidade_e_valor() -> void:
	_da("pao", 2)
	_corpo().gasta(JOGADOR, 150)
	var linha := _painel.texto_da_comida("pao")
	assert_string_contains(linha, "2", "quantas tem na mochila")
	assert_string_contains(linha, str(_painel.restaura_agora("pao")),
			"e quanto ela restaura agora")

func test_o_texto_da_mesa_conta_a_saciedade() -> void:
	_corpo().gasta(JOGADOR, 150)
	_da("pao", 1)
	_painel.come("pao")
	assert_string_contains(_painel.texto_da_mesa(), "50",
			"a próxima refeição vale metade, e é o que decide quando comer")


# --- Comer pelo botão ---

func test_comer_tira_da_mochila_e_enche_a_barra() -> void:
	_da("pao", 1)
	_corpo().gasta(JOGADOR, 150)
	var antes := _painel.estamina()
	_painel.come("pao")
	assert_gt(_painel.estamina(), antes, "a barra subiu")
	assert_eq(_painel.quantidade("pao"), 0, "e o pão saiu da mochila")
	assert_eq(_painel.comidas(), [] as Array[String], "a mesa esvazia junto")

## A `ComerAction` cobra o item no Inventory antes de o corpo olhar a barra. Com
## a barra cheia, despachar queimaria um pão de 260g em silêncio — por isso a
## tela pergunta ao sistema antes.
func test_comer_com_a_barra_cheia_nao_despacha() -> void:
	_da("pao", 1)
	assert_false(_painel.pode_comer("pao"), "a sim diz não com a barra cheia")
	_painel.come("pao")
	assert_eq(_painel.quantidade("pao"), 1, "o pão continua na mochila")
	assert_string_contains(_painel.ultimo_aviso(), "pode_comer",
			"e a tela conta por que não foi")

func test_com_a_barra_faltando_um_ponto_ja_da_para_comer() -> void:
	_da("pao", 1)
	_corpo().gasta(JOGADOR, 1)
	assert_true(_painel.pode_comer("pao"))

func test_a_mesa_nao_decide_regra_nenhuma() -> void:
	_da("pao", 1)
	for _i in 5:
		assert_eq(_painel.pode_comer("pao"), _sistema().pode_comer(JOGADOR, "pao"),
				"a resposta é sempre a mesma da sim")
		_corpo().gasta(JOGADOR, 40)
