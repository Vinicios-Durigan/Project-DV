extends GutTest

## A aba Ofícios: quanto cada ofício praticou, quantos pontos sobraram e o
## tabuleiro inteiro com o que cada vantagem custa.
##
## ## Por que uma aba própria
##
## Progressão sem tela é progressão que não existe: o jogador precisa ver a barra
## andar para saber que o trabalho de hoje virou alguma coisa, e precisa ver o
## tabuleiro inteiro — inclusive o que **não** dá para comprar — para a escolha
## pesar. Um contador solto no rail contaria o número sem contar a decisão.
##
## ## Nenhum custo é calculado aqui
##
## Custo, teto, limiar e o motivo da recusa são perguntas de **regra**, e todas
## saem do `SistemaOficios` — do mesmo jeito que o custo de arar sai do corpo.
## Este arquivo pergunta e formata. Quando a aba e a sim discordarem, quem errou
## é a aba.
##
## ## Ela pergunta antes de despachar
##
## A compra é permanente e o ponto não volta. `pode_comprar()` responde antes do
## clique, como `pode_comer()` na mesa do corpo.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _bridge: SimBridge
var _playground: Playground
var _modal: PainelMochila
var _painel: PainelOficios


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
	_painel = _modal.painel_oficios()

func _sistema() -> SistemaOficios:
	for system in _bridge.get_world().get_systems():
		if system is SistemaOficios:
			return system as SistemaOficios
	return null

func _oficios() -> EstadoOficios:
	return _bridge.get_factory().get_estado_oficios()

func _ara(x: int, y: int) -> void:
	var acao := TillPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = x
	acao.y = y
	_bridge.dispatch(acao)

## Entrega pontos pelo state, para o teste não precisar arar cem vezes.
func _da_pontos(oficio: String, quantos: int) -> void:
	_oficios().credita_pontos(JOGADOR, oficio, quantos)
	_painel.atualiza()


# --- A aba ---

func test_oficios_e_uma_aba_do_tab() -> void:
	assert_true(PainelMochila.ABAS.has(PainelMochila.ABA_OFICIOS),
			"mecânica sem tela própria não pressiona ninguém")

func test_a_aba_aparece_quando_pedida() -> void:
	_modal.mostra_aba(PainelMochila.ABA_OFICIOS)
	assert_true(_modal.oficios_visivel())
	assert_false(_modal.mochila_visivel(), "uma aba de cada vez")
	assert_eq(_modal.aba_atual(), PainelMochila.ABA_OFICIOS)


# --- Tudo o que é regra vem do sistema ---

func test_lista_os_oficios_que_a_sim_conhece() -> void:
	assert_eq(_painel.oficios(), SistemaOficios.OFICIOS,
			"a lista não mora nesta tela — ofício novo aparece sozinho")

func test_lista_as_vantagens_de_cada_oficio() -> void:
	for oficio in _painel.oficios():
		assert_eq(_painel.vantagens(oficio), _sistema().vantagens_do_oficio(oficio),
				"o tabuleiro é do sistema; a tela desenha o que existe")

func test_o_custo_e_o_teto_saem_do_sistema() -> void:
	for oficio in _painel.oficios():
		for vantagem in _painel.vantagens(oficio):
			assert_eq(_painel.custo(vantagem), _sistema().custo_da_vantagem(vantagem))
			assert_eq(_painel.teto(vantagem), _sistema().teto_da_vantagem(vantagem))

func test_o_xp_e_o_nivel_saem_do_sistema() -> void:
	_ara(1, 1)
	assert_eq(_painel.xp(SistemaOficios.LAVOURA),
			_sistema().xp_de(JOGADOR, SistemaOficios.LAVOURA))
	assert_eq(_painel.nivel(SistemaOficios.LAVOURA),
			_sistema().nivel_de(JOGADOR, SistemaOficios.LAVOURA))

func test_a_barra_do_nivel_e_a_fracao_do_sistema() -> void:
	_ara(1, 1)
	assert_almost_eq(_painel.fracao(SistemaOficios.LAVOURA),
			_sistema().fracao_do_nivel(JOGADOR, SistemaOficios.LAVOURA), 0.001,
			"a conta da barra é de regra: quem conhece os limiares é o sistema")

func test_os_pontos_saem_do_sistema() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 2)
	assert_eq(_painel.pontos(SistemaOficios.LAVOURA), 2)


# --- O tabuleiro na tela ---

func test_a_aba_desenha_o_tabuleiro_inteiro() -> void:
	var esperado := 0
	for oficio in _painel.oficios():
		esperado += _painel.vantagens(oficio).size()
	assert_eq(_painel.linhas_do_tabuleiro(), esperado,
			"o que não dá para comprar aparece também — é o que faz a escolha pesar")

func test_vantagem_comprada_aparece_comprada() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 1)
	_painel.compra(SistemaOficios.MAOS_LEVES)
	assert_eq(_painel.nivel_da_vantagem(SistemaOficios.MAOS_LEVES), 1)
	assert_string_contains(_painel.texto_da_vantagem(SistemaOficios.MAOS_LEVES), "1/2")

func test_vantagem_sem_ponto_mostra_o_motivo() -> void:
	assert_false(_painel.pode_comprar(SistemaOficios.MAOS_LEVES))
	assert_eq(_painel.motivo(SistemaOficios.MAOS_LEVES), SistemaOficios.MOTIVO_SEM_PONTO,
			"a tela mostra o porquê sem inventar a regra")

func test_com_ponto_o_botao_libera() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 1)
	assert_true(_painel.pode_comprar(SistemaOficios.MAOS_LEVES))
	assert_eq(_painel.motivo(SistemaOficios.MAOS_LEVES), "")

func test_ponto_de_um_oficio_nao_libera_o_outro() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 2)
	assert_false(_painel.pode_comprar(SistemaOficios.COSTAS_LARGAS),
			"ponto é preso no ofício que o ganhou, e a tela conta isso")


# --- Padrão 2: o botão vira ação ---

func test_comprar_despacha_a_acao_e_a_sim_cobra() -> void:
	_da_pontos(SistemaOficios.CAMPO, 1)
	_painel.compra(SistemaOficios.COSTAS_LARGAS)
	assert_eq(_sistema().nivel_da_vantagem(JOGADOR, SistemaOficios.COSTAS_LARGAS), 1,
			"quem muda o estado é a sim — a tela só despachou")
	assert_eq(_sistema().pontos_de(JOGADOR, SistemaOficios.CAMPO), 0)

## O efeito atravessa a fila e chega ao dono. É o laço inteiro pela tela.
func test_a_compra_feita_na_tela_chega_ao_corpo() -> void:
	_da_pontos(SistemaOficios.CAMPO, 1)
	_painel.compra(SistemaOficios.COSTAS_LARGAS)
	assert_eq(_bridge.get_factory().get_estado_corpo().maxima_de(JOGADOR),
			EstadoCorpo.ESTAMINA_PADRAO + SistemaCorpo.BONUS_COSTAS_LARGAS)

## A tela pergunta antes: a compra é permanente e o ponto não volta.
func test_comprar_sem_ponto_nao_despacha_e_avisa() -> void:
	_painel.compra(SistemaOficios.MAOS_LEVES)
	assert_eq(_sistema().nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 0)
	assert_false(_painel.ultimo_aviso().is_empty(),
			"clique que não vira nada tem que dizer por quê")


# --- A especialização pede uma escolha ---

func test_a_especializacao_pede_cultura() -> void:
	assert_true(_painel.exige_cultura(SistemaOficios.COLHEITA_ESPECIALIZADA))
	assert_false(_painel.exige_cultura(SistemaOficios.MAOS_LEVES))

func test_as_culturas_oferecidas_saem_do_catalogo() -> void:
	assert_eq(_painel.culturas(), _bridge.get_crop_catalog().ids(),
			"cultura nova em .tres aparece na lista sozinha")

func test_especializar_carimba_a_cultura_escolhida() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 2)
	var cultura: String = _painel.culturas()[0]
	_painel.escolhe_cultura(cultura)
	_painel.compra(SistemaOficios.COLHEITA_ESPECIALIZADA)
	assert_eq(_sistema().cultura_de(JOGADOR), cultura)

func test_especializar_sem_escolher_cultura_avisa() -> void:
	_da_pontos(SistemaOficios.LAVOURA, 2)
	_painel.escolhe_cultura("")
	_painel.compra(SistemaOficios.COLHEITA_ESPECIALIZADA)
	assert_eq(_sistema().cultura_de(JOGADOR), "", "nada foi carimbado")
	assert_false(_painel.ultimo_aviso().is_empty())


# --- A tela se redesenha sozinha ---

func test_trabalhar_atualiza_a_aba() -> void:
	var antes := _painel.xp(SistemaOficios.LAVOURA)
	_ara(2, 2)
	assert_gt(_painel.xp(SistemaOficios.LAVOURA), antes,
			"a barra tem que andar no mesmo golpe que ensinou")

## O minuto que passa não mexe em ofício nenhum: XP anda por trabalho feito.
## Ignorar o tick é o que deixa esta aba de graça em ×60.
func test_o_minuto_nao_mexe_na_aba() -> void:
	_ara(3, 3)
	var antes := _painel.texto_do_oficio(SistemaOficios.LAVOURA)
	_bridge.get_world().advance(1)
	assert_eq(_painel.texto_do_oficio(SistemaOficios.LAVOURA), antes)
