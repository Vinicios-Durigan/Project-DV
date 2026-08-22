extends GutTest

## A ficha de amizade: a escada da relação vista de fora.
##
## Constância é a mecânica mais lenta do jogo — ela anda um passo por dia, e
## um número cru ("relação 7 dias") não diz se esse passo valeu alguma coisa.
## Esta aba existe para responder isso, e o que estes testes guardam é
## exatamente onde uma tela de progresso costuma mentir:
##
## - **o degrau desenhado** discordando do degrau que a sim cobra;
## - **o "faltam N"** virando zero no topo da escada, como se o próximo degrau
##   estivesse a um dia de distância para sempre;
## - **a promessa de cota** de um degrau que já não cabe no prédio;
## - o painel **calculando** degrau em vez de perguntar — um `if` de regra em
##   `game/` é bug de arquitetura mesmo quando a tela fica certa.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelAmizade
var _modal: PainelMochila


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
	_painel = _modal.painel_amizade()
	_vai_para_cidade()


func _vai_para_cidade() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.CIDADE
	_bridge.dispatch(acao)

func _da_item(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

func _da_dinheiro(valor: int) -> void:
	var acao := AddMoneyAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.valor = valor
	_bridge.dispatch(acao)

func _entrega(id: String, item_id: String, qtd: int) -> void:
	var acao := EntregarAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

func _retira(id: String) -> void:
	var acao := RetirarAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.valor = -_sistema().taxa_a_pagar(id)
	_bridge.dispatch(acao)

func _dorme() -> void:
	_bridge.dispatch(SleepAction.new())

## Um dia de rotina no moinho: entrega, busca e dorme. É o único jeito de a
## relação andar — nenhum atalho mexe no state por fora.
func _dias_de_rotina(quantos: int) -> void:
	_da_item("trigo", quantos * 2 + 2)
	_da_dinheiro(quantos * 100)
	for dia in quantos:
		_entrega(MOINHO, "trigo", 2)
		_retira(MOINHO)
		_dorme()

func _sistema() -> SistemaCidade:
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			return system as SistemaCidade
	return null


# --- Montagem ---

func test_a_ficha_existe_no_playground() -> void:
	assert_not_null(_painel, "mecânica sem painel é wave incompleta (CLAUDE.md)")

func test_a_amizade_e_uma_aba_do_tab() -> void:
	assert_true(PainelMochila.ABAS.has(PainelMochila.ABA_AMIZADE),
		"painel no rail é debug — a mecânica tem tela própria")
	_modal.abre()
	_modal.mostra_aba(PainelMochila.ABA_AMIZADE)
	assert_true(_modal.amizade_visivel())
	assert_false(_modal.cidade_visivel(), "o balcão sai da frente")

func test_lista_os_estabelecimentos_que_a_sim_conhece() -> void:
	assert_eq(_painel.estabelecimentos(), [MOINHO, PADARIA],
		"os ids saem da sim, não de uma lista escrita no painel")

func test_a_ficha_e_o_balcao_destacam_o_mesmo_predio() -> void:
	_modal.abre_cidade(PADARIA)
	assert_eq(_painel.destacado(), PADARIA,
		"trocar de aba não pode perder onde o jogador está")


# --- O degrau é o que a sim responde ---

func test_a_ficha_comeca_sem_degrau_e_com_a_escada_inteira_por_subir() -> void:
	assert_eq(_painel.dias(MOINHO), 0)
	assert_eq(_painel.degrau(MOINHO), 0)
	assert_eq(_painel.degraus(MOINHO), 4)
	assert_eq(_painel.texto_do_degrau(MOINHO), "sem degrau",
		"'degrau 0' leria como um degrau que existe")
	assert_eq(_painel.texto_da_escada(MOINHO), "○3  ○7  ○14  ○24")

func test_o_degrau_desenhado_e_o_degrau_que_a_sim_cobra() -> void:
	_dias_de_rotina(3)
	assert_eq(_painel.degrau(MOINHO), _sistema().degrau_de(MOINHO),
		"quando a tela e a sim discordam, quem errou é o painel")
	assert_eq(_painel.texto_do_degrau(MOINHO), "degrau 1 de 4")
	assert_eq(_painel.texto_da_escada(MOINHO), "●3  ○7  ○14  ○24",
		"o limiar cumprido fica cheio")

func test_o_progresso_diz_quanto_falta_e_o_que_o_degrau_paga() -> void:
	_dias_de_rotina(3)
	assert_eq(_painel.falta(MOINHO), 4)
	assert_eq(_painel.texto_do_progresso(MOINHO),
		"3 dias · faltam 4 dias para o degrau 2 (+4 de cota)")

func test_o_primeiro_dia_fala_no_singular() -> void:
	_dias_de_rotina(1)
	assert_string_contains(_painel.texto_do_progresso(MOINHO), "1 dia ·",
		"'1 dias' é o detalhe que faz o painel parecer rascunho")

func test_a_barra_anda_com_os_dias() -> void:
	assert_almost_eq(_painel.fracao(MOINHO), 0.0, 0.001)
	_dias_de_rotina(3)
	assert_almost_eq(_painel.fracao(MOINHO), 3.0 / 7.0, 0.001,
		"a barra mira o próximo limiar, não o fim da escada")


# --- Cota e capacidade são números diferentes ---

func test_a_cota_e_a_capacidade_aparecem_lado_a_lado() -> void:
	assert_eq(_painel.cota(MOINHO), 6)
	assert_eq(_painel.capacidade(MOINHO), 20)
	assert_eq(_painel.texto_da_cota(MOINHO), "cota 6 · capacidade 20")
	assert_false(_painel.no_teto(MOINHO), "no começo sobra prédio")


# --- O contrato é um degrau, e a ficha diz quanto falta ---

func test_a_ficha_avisa_que_o_dono_ainda_nao_encomenda() -> void:
	assert_eq(_painel.texto_do_contrato(MOINHO), "encomenda em 1 degrau")

func test_o_dono_passa_a_encomendar_quando_o_degrau_cai() -> void:
	_dias_de_rotina(3)
	assert_eq(_painel.texto_do_contrato(MOINHO), "o dono encomenda")


# --- O diário da sessão ---

func test_o_diario_comeca_vazio() -> void:
	assert_eq(_painel.historico(MOINHO), [] as Array[String],
		"a sim não guarda diário de amizade — este é da sessão, e diz isso")

func test_cada_entrega_deixa_um_movimento_no_diario() -> void:
	_dias_de_rotina(2)
	var linhas: Array[String] = _painel.historico(MOINHO)
	assert_eq(linhas.size(), 2, "um por dia — volume não conta (PRINCIPIOS §6)")
	assert_string_contains(linhas[0], "+1 → 2 dias",
		"o mais recente vem primeiro")

func test_o_diario_nao_cresce_para_sempre() -> void:
	_dias_de_rotina(8)
	assert_eq(_painel.historico(MOINHO).size(), PainelAmizade.MOVIMENTOS_LEMBRADOS,
		"a lista cabe na janela sem empurrar a escada para fora")

func test_o_diario_e_por_estabelecimento() -> void:
	_dias_de_rotina(2)
	assert_eq(_painel.historico(PADARIA), [] as Array[String],
		"aparecer no moinho não é aparecer na padaria")


# --- Estabelecimento que a sim não conhece ---

func test_id_desconhecido_desenha_zerado_em_vez_de_quebrar() -> void:
	assert_eq(_painel.degrau("ferreiro"), 0)
	assert_eq(_painel.texto_do_degrau("ferreiro"), "sem escada")
	assert_eq(_painel.texto_do_contrato("ferreiro"), "não encomenda")
	assert_eq(_painel.texto_da_escada("ferreiro"), "")
