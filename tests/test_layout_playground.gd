extends GutTest

## O layout aprovado, montado de verdade: sobe a `SimBridge`, que monta a janela
## do playground, que monta a cena inteira — o mesmo caminho que roda quando
## alguém aperta F1.
##
## É teste de fiação, não de beleza. O que ele pega é o modo de falha caro desta
## wave: um painel que não recebeu o fio. Sem bridge, o painel não quebra nem
## reclama — ele fica bonito e morto na tela, e a gente joga uma tarde inteira
## achando que a sim está errada.

var _bridge: SimBridge
var _playground: Playground


func before_each() -> void:
	_bridge = SimBridge.new()
	# Sem tick automático: o teste manda o tempo, não o relógio de parede.
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	_playground = _acha_playground()


func after_each() -> void:
	_playground = null


func _acha_playground() -> Playground:
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			return janela.get_node("Playground") as Playground
	return null

func _regiao(caminho: String) -> Control:
	return _playground.get_node_or_null(caminho) as Control


func test_a_janela_do_playground_sobe_junto_com_a_bridge() -> void:
	assert_not_null(_playground, "a bridge não montou o playground")

func test_as_cinco_regioes_do_mock_estao_na_tela() -> void:
	var regioes := {
		"Raiz/Barra": &"Barra",
		"Raiz/Corpo/Rail": &"Rail",
		"Raiz/Corpo/Mundo": &"Mundo",
		"Raiz/Corpo/Inspetor": &"Inspetor",
		"Raiz/Diario": &"Diario",
	}
	for caminho: String in regioes:
		var regiao := _regiao(caminho)
		assert_not_null(regiao, "região '%s' sumiu do layout" % caminho)
		assert_eq(regiao.theme_type_variation, regioes[caminho],
			"região '%s' com a variação errada — perdeu a moldura" % caminho)

func test_o_tema_esta_na_raiz_e_os_paineis_herdam() -> void:
	assert_true(_playground.theme is TemaPlayground,
		"sem o tema na raiz nenhum painel nasce vestido")
	var botao := Button.new()
	autofree(botao)
	_regiao("Raiz/Barra").add_child(botao)
	assert_eq(botao.get_theme_stylebox("normal").get_class(), "StyleBoxFlat",
		"botão dentro da barra não herdou o estilo")

func test_cada_painel_esta_na_regiao_dele() -> void:
	assert_not_null(_playground.get_node_or_null(
		"Raiz/Corpo/Rail/RolagemRail/ColunaRail/StatusPanel"), "StatusPanel fora do rail")
	assert_not_null(_playground.get_node_or_null(
		"Raiz/Corpo/Mundo/MundoEsboco"), "MundoEsboco fora do centro")
	assert_not_null(_playground.get_node_or_null(
		"Raiz/Corpo/Inspetor/ColunaInspetor/InspetorTile"), "InspetorTile fora da direita")
	assert_not_null(_playground.get_node_or_null(
		"Raiz/Corpo/Inspetor/ColunaInspetor/MedidorDia"), "MedidorDia fora da direita")
	assert_not_null(_playground.get_node_or_null(
		"Raiz/Diario/ColunaDiario/EventFeed"), "EventFeed fora do rodapé")

func test_todo_painel_recebeu_o_fio() -> void:
	# O modo de falha caro: painel bonito e mudo. `get_bridge` só existe em quem
	# recebeu; para os outros, a prova é indireta e vem nos testes seguintes.
	assert_same(_playground.get_bridge(), _bridge, "a casca não recebeu o fio")
	var mundo := _playground.get_mundo()
	assert_not_null(mundo, "a casca não sabe achar o mundo")
	assert_same(mundo.get_bridge(), _bridge, "o mundo não recebeu o fio")

func test_o_diario_colapsa_e_volta() -> void:
	var feed := _regiao("Raiz/Diario/ColunaDiario/EventFeed")
	assert_true(feed.visible, "o diário começa aberto — é o jogo acontecendo")
	_playground._alterna_diario()
	assert_false(feed.visible, "colapsar não escondeu o diário")
	_playground._alterna_diario()
	assert_true(feed.visible, "não voltou")

func test_a_recusa_vira_toast_com_o_motivo() -> void:
	# Ponta a ponta: ação impossível → a sim recusa → o toast fala português.
	var aviso := _playground.get_node(
		"Raiz/Corpo/Mundo/MundoEsboco/AvisoRecusa") as AvisoRecusa
	var viagem := ViajarAction.new()
	viagem.player_id = SimFactory.PLAYER_PADRAO
	viagem.destino = EstadoLocais.FAZENDA  # já está nela

	_bridge.dispatch(viagem)

	assert_string_contains(aviso._rotulo.text, "já está",
		"a recusa não chegou no toast, ou chegou como id cru")

func test_o_conteudo_do_rail_tem_altura() -> void:
	# Regressão da wave 11: o `StatusPanel` tinha um `ScrollContainer` próprio e,
	# ao entrar no rail (que já rola), o de dentro colapsou para altura zero. O
	# painel continuava lá, montado e atualizado — e invisível. Painel certo e
	# invisível é o pior tipo de bug de layout, porque nada reclama.
	var painel := _playground.get_node(
		"Raiz/Corpo/Rail/RolagemRail/ColunaRail/StatusPanel") as StatusPanel
	await get_tree().process_frame
	await get_tree().process_frame

	assert_gt(painel.get_child_count(), 0, "o painel do rail não montou nada")
	assert_gt(painel.size.y, 0.0,
		"o painel do rail tem altura zero — está na tela e não dá para ver")

func test_o_painel_do_rail_nao_rola_por_conta_propria() -> void:
	# Rolagem dentro de rolagem é o que causou o bug acima. Quem rola é o rail.
	var painel := _playground.get_node(
		"Raiz/Corpo/Rail/RolagemRail/ColunaRail/StatusPanel") as StatusPanel
	for filho in painel.get_children():
		assert_false(filho is ScrollContainer,
			"o painel voltou a ter rolagem própria dentro da rolagem do rail")

# --- Usar: o item na mão decide, e a sim é quem decide ---

func _mira() -> MiraFerramentas:
	return _playground.get_mundo().get_node("MiraFerramentas") as MiraFerramentas

func _plot(x: int, y: int) -> Dictionary:
	return _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_FARM, {}).get("plots", {}).get("%d:%d" % [x, y], {})

## O canteiro debaixo dos pés do jogador, em coordenadas da sim. Os testes usam
## este e não (0,0) porque o alcance é 1: (0,0) fica a quatro tiles de onde o
## jogador nasce, e a ação nem sairia.
func _canteiro_ao_alcance() -> Vector2i:
	return _playground.get_mundo().canteiro_no_tile(
		_playground.get_mundo().tile_do_jogador())

func test_usar_com_a_enxada_ara() -> void:
	# Ponta a ponta: a mão começa na enxada, usar num canteiro cru ara. Nenhum
	# "modo ferramenta" no meio do caminho.
	var aqui := _canteiro_ao_alcance()

	_mira().usa(aqui.x, aqui.y)

	assert_true(bool(_plot(aqui.x, aqui.y).get("arada", false)), "a enxada não arou")

func test_usar_com_a_semente_planta_a_cultura_da_mao() -> void:
	# O bug que motivou a wave: plantar usava sempre a primeira cultura do
	# catálogo. Agora quem manda é a semente que está na mão.
	var semente := AddItemAction.new()
	semente.player_id = SimFactory.PLAYER_PADRAO
	semente.item_id = "semente_cenoura"
	semente.qtd = 1
	_bridge.dispatch(semente)

	var aqui := _canteiro_ao_alcance()
	_mira().usa(aqui.x, aqui.y)             # enxada ainda na mão: ara
	_equipa_o_slot_de("semente_cenoura")
	_mira().usa(aqui.x, aqui.y)

	assert_eq(String(_plot(aqui.x, aqui.y).get("crop_id", "")), "cenoura",
		"plantou outra coisa que não a semente da mão")

func _equipa_o_slot_de(item_id: String) -> void:
	var slots: Array = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_INVENTORY, {}).get("0", {}).get("slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if String(slot.get("item_id", "")) == item_id:
			var acao := EquiparSlotAction.new()
			acao.player_id = SimFactory.PLAYER_PADRAO
			acao.slot = i
			_bridge.dispatch(acao)
			return

func test_usar_fora_do_alcance_nao_faz_nada() -> void:
	# O alcance é a única regra que `game/` julga, porque a sim não tem a
	# posição do jogador (GAMEPLAY §8). Sem ele, dava para arar a fazenda
	# inteira de longe e andar deixaria de custar tempo.
	# O canteiro (0,0) fica a quatro tiles de onde o jogador nasce — longe demais
	# para o braço, e perto o bastante para ser um canteiro de verdade.
	_mira().usa(0, 0)

	assert_false(bool(_plot(0, 0).get("arada", false)),
		"braço curto é o que faz andar custar tempo")

## O teste que faltava, e que custou três tentativas de conserto: ele empurra um
## evento de mouse **de verdade** na janela do playground e confere que ele
## chegou na mira.
##
## O bug era este: `Control` nasce com `mouse_filter = STOP`, e qualquer nó da
## corrente que estivesse em STOP engolia o evento antes do `_unhandled_input`.
## Nada quebrava, nada reclamava — o mouse simplesmente não existia. E o
## retículo escondia isso enquanto tinha o facing como reserva.
func test_o_mouse_chega_ate_a_mira() -> void:
	var mundo := _playground.get_mundo()
	await get_tree().process_frame
	await get_tree().process_frame

	var janela := _playground.get_parent() as Window
	var evento := InputEventMouseMotion.new()
	evento.position = mundo.get_global_rect().get_center()
	janela.push_input(evento)

	assert_true(_mira().tem_alvo(),
		"o mouse não atravessou até a mira — algum Control da corrente está em STOP")

## E este prova o gesto inteiro: mover o mouse até um canteiro ao alcance,
## clicar, e o canteiro ficar arado. É o caminho que o jogador percorre, do
## evento do SO até o estado da sim.
func test_clicar_no_canteiro_ara() -> void:
	var mundo := _playground.get_mundo()
	await get_tree().process_frame
	await get_tree().process_frame

	var aqui := _canteiro_ao_alcance()
	var ponto := mundo.get_global_transform() * mundo.rect_do_tile(
		aqui + MundoEsboco.CANTEIRO_OFFSET).get_center()
	var janela := _playground.get_parent() as Window

	var mover := InputEventMouseMotion.new()
	mover.position = ponto
	janela.push_input(mover)

	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	clique.position = ponto
	janela.push_input(clique)

	assert_true(bool(_plot(aqui.x, aqui.y).get("arada", false)),
		"o clique não virou ação — o gesto inteiro está quebrado")

func test_o_reticulo_some_quando_o_cursor_sai_do_mapa() -> void:
	# Antes ele pulava para o tile à frente do personagem, e a mira parecia ter
	# vontade própria. Sumir é o que o playtest pediu.
	assert_false(_mira().tem_alvo(), "sem cursor sobre o mapa, não há alvo")

func test_a_barra_mostra_o_relogio_e_o_dinheiro_da_sim() -> void:
	var moedas := AddMoneyAction.new()
	moedas.player_id = SimFactory.PLAYER_PADRAO
	moedas.valor = 250

	_bridge.dispatch(moedas)

	assert_string_contains(_playground._dinheiro.text, "g", "o dinheiro sai com a unidade")
	assert_true(_playground._relogio.text.begins_with("Dia "),
		"o relógio da barra não leu o snapshot")
