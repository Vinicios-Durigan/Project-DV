extends GutTest

## O painel da cidade no playground: a mecânica inteira jogável por botão.
##
## O que estes testes guardam é o que quebra calado num painel:
##
## - **a conta da cota** mostrada na tela discordando da que a sim cobra;
## - **o clique virando a ação errada** — entregar um lote que a sim recusaria,
##   pagando o trigo à toa (a `EntregarAction` cobra antes de a cidade validar);
## - **o tempo restante** calculado por uma conta própria em vez do relógio da
##   sim.

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelCidade

const MOINHO: String = "moinho"


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_painel = _playground.find_child("PainelCidade", true, false) as PainelCidade
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

func _mochila(item_id: String) -> int:
	return _bridge.get_factory().get_inventory_state() \
		.get_player(SimFactory.PLAYER_PADRAO).count(item_id)


# --- Montagem ---

func test_o_painel_existe_no_playground() -> void:
	assert_not_null(_painel, "mecânica sem painel é wave incompleta (CLAUDE.md)")

func test_mostra_os_estabelecimentos_que_a_sim_conhece() -> void:
	assert_eq(_painel.estabelecimentos(), ["moinho", "padaria"],
		"os ids saem da sim, não de uma lista escrita aqui")


# --- Cota ---

func test_a_cota_da_tela_e_a_cota_da_sim() -> void:
	assert_eq(_painel.cota_usada(MOINHO), 0)
	assert_eq(_painel.cota_total(MOINHO), 6, "cota inicial do moinho")

	_da_item("trigo", 4)
	_painel.entrega(MOINHO)
	_painel.entrega(MOINHO)
	assert_eq(_painel.cota_usada(MOINHO), 4, "dois lotes de 2 trigo")

func test_a_cota_conta_o_que_esta_pronto_e_nao_foi_buscado() -> void:
	_da_item("trigo", 2)
	_painel.entrega(MOINHO)
	_bridge.advance(240)
	assert_eq(_painel.cota_usada(MOINHO), 2,
		"pronta e esquecida ainda entope o moinho — é o atrito de ir buscar")


# --- Padrão 2: o clique vira ação ---

func test_entregar_manda_um_lote_e_tira_o_trigo_da_mochila() -> void:
	_da_item("trigo", 2)
	_painel.entrega(MOINHO)
	assert_eq(_mochila("trigo"), 0, "quem tirou foi a sim, pelo InventorySystem")
	assert_eq(_painel.fila(MOINHO).size(), 1)

## Mochila vazia é assunto do inventário, não da cidade: `pode_entregar` diz
## sim, a ação é despachada, e quem recusa é o `InventorySystem` — que valida
## antes de tirar qualquer coisa. Nada é perdido, e o motivo aparece no painel.
func test_entregar_sem_trigo_e_recusado_pela_sim_sem_perder_nada() -> void:
	_painel.entrega(MOINHO)
	assert_eq(_painel.fila(MOINHO).size(), 0)
	assert_eq(_mochila("trigo"), 0)
	assert_string_contains(_painel.ultimo_aviso(), "item_insuficiente",
		"o painel repete o motivo da sim, sem inventar um próprio")

func test_entregar_acima_da_cota_nao_despacha_nada() -> void:
	_da_item("trigo", 20)
	for _i in 3:
		_painel.entrega(MOINHO)     # 6 trigo = a cota inteira
	assert_eq(_painel.cota_usada(MOINHO), 6)

	_painel.entrega(MOINHO)
	assert_eq(_mochila("trigo"), 14, "o quarto lote não foi cobrado")
	assert_eq(_painel.fila(MOINHO).size(), 3)

func test_retirar_paga_a_taxa_que_a_sim_pediu() -> void:
	_da_item("trigo", 2)
	_painel.entrega(MOINHO)
	_bridge.advance(240)

	assert_eq(_painel.taxa_a_pagar(MOINHO), 10)
	_painel.retira(MOINHO)
	assert_eq(_mochila("farinha"), 1)
	assert_eq(_painel.cota_usada(MOINHO), 0)


# --- Padrão 3: o evento vira tela ---

func test_o_tempo_restante_sai_do_relogio_da_sim() -> void:
	_da_item("trigo", 2)
	_painel.entrega(MOINHO)
	assert_eq(_painel.minutos_restantes(MOINHO, 0), 240, "prazo do moinho, inteiro")

	_bridge.advance(100)
	assert_eq(_painel.minutos_restantes(MOINHO, 0), 140)

	_bridge.advance(140)
	assert_eq(_painel.minutos_restantes(MOINHO, 0), 0, "pronta não tem tempo restante")

func test_a_fila_sai_do_snapshot() -> void:
	_da_item("trigo", 2)
	_painel.entrega(MOINHO)
	var linha: Dictionary = _painel.fila(MOINHO)[0]
	assert_eq(String(linha.get("item_id", "")), "farinha",
		"o que aparece na tela é exatamente o que vai para o arquivo de save")

func test_o_texto_do_tempo_e_legivel() -> void:
	assert_eq(_painel.texto_do_tempo(0), "pronta")
	assert_eq(_painel.texto_do_tempo(45), "45min")
	assert_eq(_painel.texto_do_tempo(240), "4h")
	assert_eq(_painel.texto_do_tempo(133), "2h13")
