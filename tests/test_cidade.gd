extends GutTest

## A cidade carimbada por código: um nó por estabelecimento que a sim conhece.
##
## A cena é **molde**, não prédio. Moinho e padaria saem dela com id e sprite
## diferentes, e é isso que faz a promessa do `.tres` valer também na tela:
## estabelecimento novo é conteúdo novo, não cena nova nem código novo.
##
## O que estes testes guardam:
##
## - **quem manda na lista é a sim.** Prédio no mapa que a sim não conhece, ou
##   `.tres` cadastrado que não aparece, são a mesma mentira em direções
##   opostas;
## - **onde cada um fica é conta, não tabela.** Uma coordenada digitada por
##   prédio faria o terceiro estabelecimento nascer em cima do segundo até
##   alguém lembrar de editar `game/`;
## - **arte faltando não quebra prédio.** A arte é a última coisa a chegar e
##   não pode ser a primeira a ser exigida;
## - **o selo é do prédio certo.** Um aviso que acende na padaria porque a
##   farinha ficou pronta no moinho manda o jogador atravessar o mapa à toa.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _bridge: SimBridge
var _cidade: Cidade
var _sistema: SistemaCidade


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			_sistema = system
	_cidade = Cidade.new()
	add_child_autofree(_cidade)
	_cidade.setup(_bridge)


func _arte_de(id: String) -> Sprite2D:
	return _cidade.predio(id).get_node("Arte") as Sprite2D

func _selo_de(id: String) -> Sprite2D:
	return _cidade.predio(id).get_node("Selo") as Sprite2D

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
	acao.valor = -_sistema.taxa_a_pagar(id)
	_bridge.dispatch(acao)


# --- Quem manda na lista é a sim ---

func test_planta_um_predio_por_estabelecimento() -> void:
	assert_eq(_cidade.plantados(), _sistema.ids().size(),
		"prédio a mais ou a menos que a sim conhece é mapa mentindo")
	assert_eq(_cidade.ids(), _sistema.ids())

func test_cada_predio_carrega_o_proprio_id() -> void:
	for id in _sistema.ids():
		var no := _cidade.predio(id)
		assert_not_null(no, "%s existe na sim e tem que existir no mapa" % id)
		assert_eq(no.id_estabelecimento, id,
			"o id é o que liga o nó ao .tres — errar aqui troca os dois prédios")

func test_o_mapa_nao_inventa_predio() -> void:
	assert_null(_cidade.predio("ferreiro"),
		"id que a sim não conhece não vira nó — o mapa não cadastra prédio")

func test_sem_a_sim_nao_ha_o_que_plantar() -> void:
	var orfa := Cidade.new()
	add_child_autofree(orfa)
	assert_eq(orfa.plantados(), 0, "sem bridge não há lista de prédios")
	assert_eq(orfa.ids(), [] as Array[String])


# --- Onde cada um fica é conta, não tabela ---

func test_a_ordem_no_mapa_segue_a_ordem_da_sim() -> void:
	var ids := _sistema.ids()
	for indice in ids.size():
		assert_eq(_cidade.predio(ids[indice]).position, _cidade.posicao_de(indice),
			"o lugar sai do índice: prédio novo acha o dele sozinho")

func test_dois_predios_nao_nascem_no_mesmo_lugar() -> void:
	assert_ne(_cidade.predio(MOINHO).position, _cidade.predio(PADARIA).position)

func test_o_espaco_e_ajustavel_sem_tocar_no_tres() -> void:
	var outra := Cidade.new()
	outra.origem = Vector2(100.0, 40.0)
	outra.espaco = Vector2(80.0, 0.0)
	add_child_autofree(outra)
	outra.setup(_bridge)
	assert_eq(outra.predio(MOINHO).position, Vector2(100.0, 40.0))
	assert_eq(outra.predio(PADARIA).position, Vector2(180.0, 40.0),
		"layout é decisão de game/ — mudar não pede migração de conteúdo")


# --- Arte faltando não quebra prédio ---

func test_o_sprite_do_tres_vira_a_textura_do_predio() -> void:
	assert_eq(_sistema.def_de(MOINHO).sprite,
		"res://assets/objects/Free_Chicken_House.png",
		"a arte do prédio é conteúdo do .tres, editável no inspector")
	assert_not_null(_arte_de(MOINHO).texture)

func test_estabelecimento_sem_sprite_nasce_mesmo_assim() -> void:
	assert_eq(_sistema.def_de(PADARIA).sprite, "", "a padaria ainda não tem arte")
	assert_not_null(_cidade.predio(PADARIA), "prédio sem desenho continua sendo prédio")
	assert_null(_arte_de(PADARIA).texture)

## O pé do prédio no (0,0) do nó, seja qual for o tamanho da arte — é o que faz
## todos encostarem no chão na mesma linha sem ninguém digitar offset.
func test_a_arte_ancora_pelo_pe() -> void:
	var arte := _arte_de(MOINHO)
	assert_false(arte.centered)
	assert_eq(arte.offset.y, -float(arte.texture.get_height()))
	assert_eq(arte.offset.x, -arte.texture.get_width() / 2.0)


# --- O selo é do prédio certo ---

func test_o_selo_nasce_apagado() -> void:
	assert_false(_selo_de(MOINHO).visible, "sem nada pronto, nada a avisar")

func test_o_selo_acende_quando_a_encomenda_fica_pronta() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	assert_false(_selo_de(MOINHO).visible, "entregou não é pronto — o prazo é a mecânica")

	_bridge.advance(_sistema.def_de(MOINHO).prazo_minutos)
	assert_true(_selo_de(MOINHO).visible,
		"o prédio avisa de longe: é o que deixa a rota do dia ser decidida sem abrir painel")

	_retira(MOINHO)
	assert_false(_selo_de(MOINHO).visible, "buscou, apagou")

func test_o_selo_de_um_predio_nao_acende_no_outro() -> void:
	_vai_para_cidade()
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	_bridge.advance(_sistema.def_de(MOINHO).prazo_minutos)
	assert_false(_selo_de(PADARIA).visible,
		"farinha pronta no moinho não é pão pronto na padaria")
