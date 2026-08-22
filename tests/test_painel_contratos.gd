extends GutTest

## A aba de contratos no playground: a encomenda inteira jogável por botão.
##
## O que estes testes guardam é o que quebra calado num painel:
##
## - **o pedido mostrado na tela** divergindo do que a sim guardou;
## - **o clique virando a ação errada** — cumprir um pedido que a sim recusaria,
##   pagando o trigo à toa (a `CumprirContratoAction` cobra antes de o contrato
##   validar);
## - **a contagem regressiva** calculada por uma conta própria em vez do relógio
##   da sim.

const MOINHO: String = "moinho"
const AMIGO: int = 3

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelContratos
var _mochila: PainelMochila


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_painel = _playground.find_child("PainelContratos", true, false) as PainelContratos
	_mochila = _playground.find_child("PainelMochila", true, false) as PainelMochila
	_vai_para_cidade()

func _vai_para_cidade() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.CIDADE
	_bridge.dispatch(acao)

## O dono já conhece o jogador e a encomenda do dia está na mesa.
func _oferta_na_mesa() -> void:
	_bridge.get_factory().get_estado_contratos().define_dias(MOINHO, AMIGO)
	_bridge.dispatch(SleepAction.new())
	_vai_para_cidade()

func _item_na_mochila(item_id: String) -> int:
	return _bridge.get_factory().get_inventory_state() \
		.get_player(SimFactory.PLAYER_PADRAO).count(item_id)

func _dinheiro() -> int:
	return _bridge.get_factory().get_inventory_state() \
		.get_player(SimFactory.PLAYER_PADRAO).dinheiro


# --- Montagem ---

func test_o_painel_existe_no_playground() -> void:
	assert_not_null(_painel, "mecânica sem painel é wave incompleta (CLAUDE.md)")

func test_e_uma_aba_do_tab_como_a_cidade() -> void:
	_mochila.mostra_aba(PainelMochila.ABA_CONTRATOS)
	assert_true(_mochila.contratos_visivel(), "a aba abre")
	assert_false(_mochila.cidade_visivel(), "e as irmãs se escondem")
	assert_false(_mochila.mochila_visivel(), "inclusive a mochila")

func test_mostra_os_donos_que_a_sim_conhece() -> void:
	assert_eq(_painel.estabelecimentos(), ["moinho", "padaria"],
		"os ids saem da sim, não de uma lista escrita aqui")

func test_sem_relacao_nao_ha_encomenda_na_mesa() -> void:
	assert_false(_painel.tem_contrato(MOINHO),
		"o degrau mínimo é da sim, e a tela só mostra o que existe")


# --- A oferta na tela ---

func test_a_oferta_da_tela_e_a_da_sim() -> void:
	_oferta_na_mesa()
	var con := _bridge.get_factory().get_estado_contratos().contrato(MOINHO)
	assert_true(_painel.tem_contrato(MOINHO), "há encomenda")
	assert_eq(_painel.item_pedido(MOINHO), con.item_id, "o mesmo item")
	assert_eq(_painel.qtd_pedida(MOINHO), con.qtd, "a mesma quantidade")
	assert_eq(_painel.pagamento(MOINHO), con.pagamento, "o mesmo pagamento")
	assert_false(_painel.aceito(MOINHO), "e ainda sem resposta")

func test_a_contagem_regressiva_anda_com_o_relogio_da_sim() -> void:
	_oferta_na_mesa()
	var antes := _painel.minutos_restantes(MOINHO)
	_bridge.advance(60)
	assert_eq(_painel.minutos_restantes(MOINHO), antes - 60,
		"o número é o da sim; conta própria aqui dessincronizaria da recusa")


# --- Os botões ---

func test_aceitar_vira_a_acao_e_a_tela_acompanha() -> void:
	_oferta_na_mesa()
	_painel.aceita(MOINHO)
	assert_true(_painel.aceito(MOINHO), "o compromisso está de pé")

func test_recusar_limpa_a_mesa() -> void:
	_oferta_na_mesa()
	_painel.recusa(MOINHO)
	assert_false(_painel.tem_contrato(MOINHO), "a oferta foi devolvida")

func test_cumprir_paga_e_gasta_o_item() -> void:
	_oferta_na_mesa()
	_painel.aceita(MOINHO)
	_painel.da_o_pedido(MOINHO)
	var dinheiro := _dinheiro()
	var pago := _painel.pagamento(MOINHO)
	var item := _painel.item_pedido(MOINHO)

	_painel.cumpre(MOINHO)

	assert_eq(_dinheiro(), dinheiro + pago, "o contrato pagou o combinado")
	assert_eq(_item_na_mochila(item), 0, "e a mercadoria foi entregue")
	assert_false(_painel.tem_contrato(MOINHO), "a mesa está limpa")

func test_cumprir_sem_ter_o_item_nao_despacha_nada() -> void:
	_oferta_na_mesa()
	_painel.aceita(MOINHO)
	var item := _painel.item_pedido(MOINHO)
	_painel.cumpre(MOINHO)
	assert_eq(_item_na_mochila(item), 0, "nada saiu da mochila vazia")
	assert_true(_painel.aceito(MOINHO), "e o compromisso continua de pé")

func test_cumprir_o_que_nao_foi_aceito_pergunta_antes_e_nao_despacha() -> void:
	_oferta_na_mesa()
	_painel.da_o_pedido(MOINHO)
	var item := _painel.item_pedido(MOINHO)
	var quanto := _item_na_mochila(item)

	_painel.cumpre(MOINHO)

	assert_eq(_item_na_mochila(item), quanto,
		"a ação cobra antes de o contrato validar — por isso o painel pergunta")
	assert_string_contains(_painel.ultimo_aviso(), "pode_cumprir",
		"e o aviso diz que quem disse não foi a sim")


# --- Recusa e destaque ---

func test_o_motivo_exibido_e_o_da_sim() -> void:
	_painel.aceita(MOINHO)
	assert_string_contains(_painel.ultimo_aviso(), SistemaContratos.MOTIVO_SEM_CONTRATO,
		"o texto vem da recusa da sim, não de um if daqui")

func test_o_dono_aberto_pelo_mapa_fica_em_destaque() -> void:
	_mochila.abre_contratos(MOINHO)
	assert_eq(_painel.destacado(), MOINHO, "quem entrou no moinho não procura o moinho")
	assert_true(_mochila.contratos_visivel(), "e já cai na aba certa")
