extends GutTest

## A barra do corpo na barra de status: quanto ainda dá para trabalhar hoje.
##
## ## Por que ela mora no topo, e não numa aba
##
## Estamina que só aparece dentro do Tab não pressiona ninguém. A decisão que
## esta mecânica existe para criar — "rego mais um canteiro ou volto para a
## cama?" — é tomada no meio do canteiro, e é lá que o número precisa estar no
## canto do olho.
##
## ## A tela não faz a conta
##
## Nenhum `if` de regra e nenhum desconto acontece aqui: os dois números saem do
## `snapshot()`, a mesma foto que o save grava. Se a barra e a sim discordarem,
## quem errou é a tela.
##
## Onde ela **muda de cor** é decisão de tela, não regra: a sim não tem opinião
## sobre "perto do fim". Quantas ações ainda cabem, essa sim é pergunta de regra
## — e ela é respondida na aba Corpo, que pergunta ao sistema.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _bridge: SimBridge
var _playground: Playground
var _medidor: MedidorEstamina


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_medidor = _playground.get_node("Raiz/Barra/LinhaBarra/MedidorEstamina") as MedidorEstamina

func _corpo() -> EstadoCorpo:
	return _bridge.get_factory().get_estado_corpo()

## Deixa o corpo com tanto de estamina, pela porta do state — o que se testa
## aqui é a leitura, não o desconto (isso é do `SistemaCorpo`).
func _deixa_com(quanto: int) -> void:
	var corpo := _corpo()
	corpo.enche(JOGADOR)
	corpo.gasta(JOGADOR, corpo.maxima_de(JOGADOR) - quanto)

func _ara(x: int, y: int) -> void:
	var acao := TillPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = x
	acao.y = y
	_bridge.dispatch(acao)


# --- O que a barra mostra ---

func test_o_dia_comeca_com_o_corpo_inteiro() -> void:
	assert_eq(_medidor.estamina(), EstadoCorpo.ESTAMINA_PADRAO)
	assert_eq(_medidor.maxima(), EstadoCorpo.ESTAMINA_PADRAO)
	assert_eq(_medidor.fracao(), 1.0)
	assert_eq(_medidor.texto(), "%d/%d" % [EstadoCorpo.ESTAMINA_PADRAO,
			EstadoCorpo.ESTAMINA_PADRAO], "o número cru, do jeito que a sim o tem")

func test_o_numero_sai_do_snapshot() -> void:
	_deixa_com(123)
	var bloco: Dictionary = _bridge.get_world().snapshot()[SimFactory.CHAVE_CORPO]
	var jogador: Dictionary = bloco["jogadores"][str(JOGADOR)]
	assert_eq(_medidor.estamina(), int(jogador["estamina"]),
			"a barra mostra exatamente o que iria para o arquivo de save")

func test_trabalhar_baixa_a_barra() -> void:
	_ara(2, 2)
	assert_eq(_medidor.estamina(), EstadoCorpo.ESTAMINA_PADRAO - SistemaCorpo.CUSTO_ARAR,
			"quem desconta é a sim; a barra só relê quando o evento chega")
	assert_lt(_medidor.fracao(), 1.0)

func test_a_barra_na_tela_acompanha_o_texto() -> void:
	_ara(2, 2)
	assert_eq(_medidor.rotulo_na_tela(), _medidor.texto(),
			"o rótulo desenhado é o mesmo número que o teste lê")
	assert_almost_eq(_medidor.barra_na_tela(), _medidor.fracao(), 0.001,
			"e a barra desenhada é a mesma fração")


# --- A cor conta antes de o número ser lido ---

func test_corpo_cheio_e_verde() -> void:
	assert_eq(_medidor.nivel(), MedidorEstamina.INTEIRO)
	assert_eq(_medidor.cor(), Paleta.VERDE)

func test_meio_dia_de_trabalho_vira_atencao() -> void:
	_deixa_com(int(EstadoCorpo.ESTAMINA_PADRAO * 0.4))
	assert_eq(_medidor.nivel(), MedidorEstamina.ATENCAO)
	assert_eq(_medidor.cor(), Paleta.OURO, "ouro é o aviso, não o alarme")

func test_perto_do_fim_acende_o_alerta() -> void:
	_deixa_com(int(EstadoCorpo.ESTAMINA_PADRAO * 0.1))
	assert_eq(_medidor.nivel(), MedidorEstamina.BEIRA)
	assert_eq(_medidor.cor(), Paleta.ALERTA,
			"descobrir que vai desmaiar é a informação mais cara desta tela")

func test_corpo_no_chao_continua_no_alerta() -> void:
	_deixa_com(0)
	assert_eq(_medidor.fracao(), 0.0)
	assert_eq(_medidor.nivel(), MedidorEstamina.BEIRA)


# --- A manhã ---

func test_dormir_devolve_a_barra_cheia() -> void:
	_deixa_com(20)
	_bridge.dispatch(SleepAction.new())
	assert_eq(_medidor.fracao(), 1.0, "dormir sempre enche")
	assert_eq(_medidor.nivel(), MedidorEstamina.INTEIRO,
			"e a cor volta junto — a barra não guarda o susto de ontem")
