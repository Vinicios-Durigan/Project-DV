extends GutTest

## Os prédios da cidade no mapa do esboço.
##
## O que estes testes guardam é a regra travada em 2026-08-22: mecânica precisa
## de **lugar** e de **tempo na tela**. Concretamente:
##
## - o moinho e a padaria existem como **pontos no mapa**, e a lista deles sai
##   da sim — estabelecimento novo aparece sem ninguém editar `game/`;
## - o prédio diz **quanto falta** sem o jogador abrir nada. É esse selo que faz
##   a cidade ser olhada de longe e a rota do dia ser decidida;
## - `E` em cima do prédio abre o balcão, e só isso: entregar e retirar
##   continuam sendo decisão de botão, não de tecla.
##
## A conta do tempo mora em `sim/` de propósito. Se ela fosse feita aqui e no
## painel, os dois divergiriam no primeiro ajuste — e a tela mentiria sobre o
## relógio.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _bridge: SimBridge
var _playground: Playground
var _mundo: MundoEsboco
var _cidade: SistemaCidade


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_mundo = _playground.get_mundo()
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			_cidade = system


func _da_item(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

func _vai_para_cidade() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.CIDADE
	_bridge.dispatch(acao)

func _entrega(id: String, item_id: String, qtd: int) -> void:
	var acao := EntregarAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)


# --- As consultas de tempo moram na sim ---

func test_estabelecimento_vazio_nao_tem_prazo() -> void:
	assert_eq(_cidade.minutos_para_a_proxima(MOINHO), -1,
		"nada em produção não é 'zero minutos', é ausência de prazo")
	assert_false(_cidade.tem_pronto(MOINHO))

func test_o_prazo_encolhe_com_o_relogio() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_cidade.minutos_para_a_proxima(MOINHO), 240, "prazo cheio do moinho")

	_bridge.advance(100)
	assert_eq(_cidade.minutos_para_a_proxima(MOINHO), 140)

func test_pronto_e_pronto_nao_e_zero_minutos() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	_bridge.advance(240)

	assert_true(_cidade.tem_pronto(MOINHO), "o lote está esperando alguém buscar")
	assert_eq(_cidade.minutos_para_a_proxima(MOINHO), -1,
		"não sobrou nada em produção — o que existe é retirada pendente")

func test_o_prazo_e_o_do_lote_que_vence_primeiro() -> void:
	_vai_para_cidade()
	_da_item("trigo", 6)
	_entrega(MOINHO, "trigo", 2)
	_bridge.advance(120)
	_entrega(MOINHO, "trigo", 2)

	assert_eq(_cidade.minutos_para_a_proxima(MOINHO), 120,
		"o selo conta o próximo, não o último da fila")

func test_o_prazo_e_por_estabelecimento() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_cidade.minutos_para_a_proxima(PADARIA), -1,
		"o moinho trabalhando não acende a padaria")


# --- O texto é o mesmo nos dois lugares ---

func test_o_formatador_de_tempo_e_compartilhado() -> void:
	# Estático de propósito: o mapa e o painel formatam pelo mesmo lugar, senão
	# um mostra "2h13" e o outro "133min" na mesma tela.
	assert_eq(PainelCidade.texto_do_tempo(0), "pronta")
	assert_eq(PainelCidade.texto_do_tempo(45), "45min")
	assert_eq(PainelCidade.texto_do_tempo(240), "4h")
	assert_eq(PainelCidade.texto_do_tempo(133), "2h13")


# --- Os prédios no mapa ---

func test_os_predios_saem_da_sim() -> void:
	assert_eq(_mundo.predios(), [MOINHO, PADARIA],
		"a lista é da sim — estabelecimento novo aparece no mapa sem editar game/")

func test_cada_predio_ocupa_tiles_dentro_da_cidade() -> void:
	for id in _mundo.predios():
		var tiles := _mundo.tiles_do_predio(id)
		assert_gt(tiles.size.x, 0, "%s: prédio sem largura não é lugar" % id)
		assert_gte(tiles.position.x, MundoEsboco.FAZENDA_LARGURA + MundoEsboco.CAMINHO_LARGURA,
			"%s: o prédio tem que estar dentro do terreno da cidade" % id)
		assert_lte(tiles.end.y, MundoEsboco.MAPA_ALTURA, "%s: passou da borda do mapa" % id)

func test_os_predios_nao_se_sobrepoem() -> void:
	var moinho := _mundo.tiles_do_predio(MOINHO)
	var padaria := _mundo.tiles_do_predio(PADARIA)
	assert_false(moinho.intersects(padaria),
		"dois prédios no mesmo lugar deixariam um deles inalcançável")

func test_predio_que_nao_existe_nao_tem_lugar() -> void:
	assert_eq(_mundo.tiles_do_predio("ferreiro"), Rect2i(),
		"o mapa não inventa prédio que a sim não conhece")


# --- O selo de tempo ---

func test_predio_parado_nao_tem_selo() -> void:
	assert_eq(_mundo.selo_do_predio(MOINHO), "",
		"prédio sem encomenda não escreve nada — selo à toa vira ruído")

func test_o_selo_conta_quanto_falta() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_mundo.selo_do_predio(MOINHO), "4h")

	_bridge.advance(107)
	assert_eq(_mundo.selo_do_predio(MOINHO), "2h13", "o selo anda com o relógio da sim")

func test_o_selo_grita_quando_esta_pronto() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	_bridge.advance(240)
	assert_eq(_mundo.selo_do_predio(MOINHO), "PRONTA",
		"é o aviso que o ARTE.md pede do prédio: dá para ver de longe")


# --- Ativar ---

func test_o_jogador_sabe_em_que_predio_esta() -> void:
	assert_eq(_mundo.predio_sob_o_jogador(), "", "começa na fazenda, longe de tudo")
	_mundo.teleporta_para_o_predio(MOINHO)
	assert_eq(_mundo.predio_sob_o_jogador(), MOINHO)

func test_ativar_avisa_qual_predio_e() -> void:
	_mundo.teleporta_para_o_predio(PADARIA)
	watch_signals(_mundo)
	_mundo.ativa_predio()
	assert_signal_emitted_with_parameters(_mundo, "predio_ativado", [PADARIA])

func test_ativar_longe_de_predio_nao_faz_nada() -> void:
	watch_signals(_mundo)
	_mundo.ativa_predio()
	assert_signal_not_emitted(_mundo, "predio_ativado",
		"apertar E no meio do caminho não pode abrir balcão nenhum")

## Congelado quer dizer que um painel está por cima. Ativar por baixo dele
## reabriria o balcão que o jogador acabou de fechar.
func test_mundo_congelado_nao_ativa() -> void:
	_mundo.teleporta_para_o_predio(MOINHO)
	_mundo.congela(true)
	watch_signals(_mundo)
	_mundo.ativa_predio()
	assert_signal_not_emitted(_mundo, "predio_ativado")
