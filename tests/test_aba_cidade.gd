extends GutTest

## A cidade como aba do Tab.
##
## A mochila já é a tela cheia do jogo e já é modal. Uma segunda tela modal
## disputaria a mesma tecla e o mesmo espaço; aba resolve — e de quebra põe a
## **cota** ao lado da **capacidade da mochila**, que são os dois números que
## brigam entre si o jogo inteiro.
##
## O que estes testes guardam:
##
## - o balcão da cidade está **dentro** do Tab, e não numa coluna de debug;
## - `E` no prédio abre a aba certa, com o estabelecimento certo destacado — a
##   porta no mundo leva ao balcão, sem o jogador procurar;
## - a hotbar continua viva em qualquer aba: trocar de item é o gesto mais
##   frequente do jogo e não pode depender de qual aba está aberta.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelMochila
var _mundo: MundoEsboco


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_painel = _playground.get_node("PainelMochila") as PainelMochila
	_mundo = _playground.get_mundo()


# --- As duas abas ---

func test_o_painel_abre_na_mochila() -> void:
	_painel.abre()
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_MOCHILA,
		"Tab é 'abrir a mochila' — a cidade é o segundo lugar, não o primeiro")

func test_trocar_de_aba_troca_o_que_aparece() -> void:
	_painel.abre()
	_painel.mostra_aba(PainelMochila.ABA_CIDADE)

	assert_eq(_painel.aba_atual(), PainelMochila.ABA_CIDADE)
	assert_false(_painel.mochila_visivel(), "a grade da mochila sai da frente")
	assert_true(_painel.cidade_visivel())

	_painel.mostra_aba(PainelMochila.ABA_MOCHILA)
	assert_true(_painel.mochila_visivel())
	assert_false(_painel.cidade_visivel())

func test_aba_desconhecida_nao_muda_nada() -> void:
	_painel.abre()
	_painel.mostra_aba("ferreiro")
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_MOCHILA)

## Reabrir volta onde parou: quem estava conversando com o moleiro e apertou Tab
## sem querer não deveria ter que achar a aba de novo.
func test_reabrir_volta_na_aba_que_estava() -> void:
	_painel.abre()
	_painel.mostra_aba(PainelMochila.ABA_CIDADE)
	_painel.fecha()
	_painel.abre()
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_CIDADE)


# --- O balcão mora aqui agora ---

func test_a_aba_da_cidade_e_o_painel_da_cidade() -> void:
	var cidade := _painel.painel_cidade()
	assert_not_null(cidade, "o balcão saiu do rail e entrou no Tab")
	assert_eq(cidade.estabelecimentos(), [MOINHO, PADARIA])

func test_o_balcao_saiu_do_rail() -> void:
	var rail := _playground.get_node("Raiz/Corpo/Rail")
	assert_null(rail.find_child("PainelCidade", true, false),
		"painel no rail é debug — a mecânica agora tem tela")

func test_a_hotbar_sobrevive_a_troca_de_aba() -> void:
	_painel.abre()
	_painel.mostra_aba(PainelMochila.ABA_CIDADE)
	assert_true(_painel.hotbar_visivel(),
		"trocar de item é o gesto mais frequente do jogo — não pode depender da aba")


# --- A porta no mundo leva ao balcão ---

func test_abrir_pela_cidade_ja_destaca_o_estabelecimento() -> void:
	_painel.abre_cidade(PADARIA)
	assert_true(_painel.aberto())
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_CIDADE)
	assert_eq(_painel.painel_cidade().destacado(), PADARIA,
		"quem entrou no moinho não quer procurar o moinho numa lista")

func test_abrir_pela_cidade_com_a_mochila_ja_aberta_so_troca_a_aba() -> void:
	_painel.abre()
	_painel.abre_cidade(MOINHO)
	assert_true(_painel.aberto())
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_CIDADE)

## O fio inteiro: o jogador aperta `E` em cima do prédio e o balcão abre na aba
## certa. A casca é quem liga as duas pontas — o mundo não sabe que existe
## painel, e o painel não sabe que existe mapa.
func test_ativar_o_predio_no_mapa_abre_a_aba() -> void:
	_mundo.teleporta_para_o_predio(MOINHO)
	_mundo.ativa_predio()

	assert_true(_painel.aberto(), "a porta no mundo tem que levar a algum lugar")
	assert_eq(_painel.aba_atual(), PainelMochila.ABA_CIDADE)
	assert_eq(_painel.painel_cidade().destacado(), MOINHO)

func test_o_destaque_troca_de_predio() -> void:
	_mundo.teleporta_para_o_predio(MOINHO)
	_mundo.ativa_predio()
	_painel.fecha()
	_mundo.teleporta_para_o_predio(PADARIA)
	_mundo.ativa_predio()
	assert_eq(_painel.painel_cidade().destacado(), PADARIA)
