extends GutTest

## A montagem do mundo é regra de jogo, então mora em `sim/`.
##
## A ordem dos sistemas implementa a validação em cadeia e a sequência de
## dormir (GAMEPLAY §3); as chaves dos states são o formato do save. Nenhuma
## das duas coisas pode ser decidida por um nó de `game/` — a bridge só pede
## um mundo pronto.
##
## A fábrica é pura: monta o mundo inteiro sem janela e sem árvore de cena.

var _world: SimWorld
var _factory: SimFactory


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()

func _sistema(indice: int) -> SimSystem:
	return _world.get_systems()[indice]


func test_monta_os_cinco_sistemas_na_ordem_fixa() -> void:
	var systems := _world.get_systems()
	assert_eq(systems.size(), 6, "os 6 sistemas do slice")
	assert_true(_sistema(0) is SistemaLocais, "1. Locais barra fora de lugar antes de alguém cobrar")
	assert_true(_sistema(1) is InventorySystem, "2. Inventory valida e cobra")
	assert_true(_sistema(2) is ShippingSystem, "3. Shipping vende antes de o dia virar")
	assert_true(_sistema(3) is FarmSystem, "4. Farm cresce depois da venda")
	assert_true(_sistema(4) is SistemaCidade, "5. Cidade age com a colheita já na mochila")
	assert_true(_sistema(5) is TimeSystem, "6. Time vira o calendário por último")

func test_registra_todo_state_no_save_na_ordem_do_formato() -> void:
	assert_eq(_world.state_keys(), ["time", "inventory", "farm", "shipping", "locais", "cidade"],
		"as chaves são o formato do save — GAMEPLAY §10; bloco novo entra no fim")

func test_o_state_registrado_e_o_mesmo_que_o_sistema_usa() -> void:
	assert_same(_world.get_state("time"), _factory.get_time_state(),
		"salvar o state de outro objeto salvaria um mundo que ninguém joga")
	assert_same(_world.get_state("inventory"), (_sistema(1) as InventorySystem).get_state())
	assert_same(_world.get_state("shipping"), (_sistema(2) as ShippingSystem).get_state())
	assert_same(_world.get_state("farm"), (_sistema(3) as FarmSystem).get_state())
	assert_same(_world.get_state("locais"), _factory.get_estado_locais())

func test_carrega_os_catalogos_de_data() -> void:
	assert_eq(_factory.get_item_catalog().size(), 14, "os 14 itens de data/items/")
	assert_eq(_factory.get_crop_catalog().ids(),
		["abobora", "cenoura", "morango", "rabanete", "trigo"],
		"as 5 culturas de data/crops/")

func test_os_sistemas_compartilham_o_mesmo_catalogo() -> void:
	assert_same((_sistema(1) as InventorySystem).get_catalog(), _factory.get_item_catalog(),
		"catálogo é leitura livre, mas é um só")
	assert_same((_sistema(2) as ShippingSystem).get_catalog(), _factory.get_item_catalog())
	assert_same((_sistema(3) as FarmSystem).get_catalog(), _factory.get_crop_catalog())
	assert_same((_sistema(1) as InventorySystem).get_crop_catalog(), _factory.get_crop_catalog())

func test_mundo_novo_comeca_como_o_gameplay_manda() -> void:
	var inv := (_sistema(1) as InventorySystem).get_state().get_player(SimFactory.PLAYER_PADRAO)
	assert_eq(inv.dinheiro, 500, "500g de início, GAMEPLAY §5")
	assert_eq(inv.count("semente_rabanete"), 5, "e 5 sementes da rápida")
	assert_eq(_factory.get_time_state().dia, 1, "dia 1")
	assert_eq(_factory.get_time_state().minuto, TimeState.MINUTO_DEFAULT, "acordado às 06:00")

## Sem ferramenta na mochila não se ara nem se rega: desde a wave 11.2 o que se
## pode fazer depende do que está na mão, e a mão vem da mochila.
func test_mundo_novo_ja_vem_com_as_ferramentas() -> void:
	var inv := (_sistema(1) as InventorySystem).get_state().get_player(SimFactory.PLAYER_PADRAO)
	for item_id in SimFactory.FERRAMENTAS_INICIAIS:
		assert_eq(inv.count(item_id), 1, "%s: sem ela o jogador não faz nada" % item_id)

## A hotbar é a mochila, e a ordem dos slots é a ordem em que os itens
## entraram. Enxada na tecla 1 e regador na 2 é o arranjo com que se começa a
## jogar — se as sementes entrassem antes, a tecla 1 seria semente.
func test_as_ferramentas_ocupam_os_primeiros_slots() -> void:
	var inv := (_sistema(1) as InventorySystem).get_state().get_player(SimFactory.PLAYER_PADRAO)
	for i in SimFactory.FERRAMENTAS_INICIAIS.size():
		assert_eq(inv.slots[i].item_id, SimFactory.FERRAMENTAS_INICIAIS[i],
			"slot %d fora da ordem da hotbar" % i)

## O resolvedor não é sistema e não entra na fila do tick — mas precisa nascer
## ligado nos mesmos states que os sistemas usam, senão responderia sobre um
## mundo que ninguém joga.
func test_o_resolvedor_le_os_states_da_partida() -> void:
	var resolvedor := _factory.get_resolvedor_uso()
	assert_not_null(resolvedor, "a fábrica tem que montar o resolvedor")
	assert_eq(resolvedor.item_na_mao(SimFactory.PLAYER_PADRAO), "enxada",
		"a mão começa no slot 0, que é onde a enxada foi entregue")

func test_o_mundo_montado_joga_de_verdade() -> void:
	var plantar := PlantCropAction.new()
	plantar.crop_id = "rabanete"
	plantar.item_id = "semente_rabanete"
	_world.handle(TillPlotAction.new())
	_world.handle(plantar)
	assert_true((_sistema(3) as FarmSystem).get_state().peek_plot(0, 0).tem_cultura(),
		"a cadeia inteira funciona sem ninguém montar nada à mão")

func test_o_relogio_anda_no_advance() -> void:
	var events := _world.advance(10)
	assert_eq(_factory.get_time_state().minuto, TimeState.MINUTO_DEFAULT + 10, "10 minutos de jogo")
	assert_eq(events.size(), 10, "um MinuteTickedEvent por minuto")

func test_cada_build_e_um_mundo_novo() -> void:
	var outro := SimFactory.new().build()
	assert_ne(outro, _world, "dois saves abertos não podem compartilhar state")
	assert_ne(outro.get_state("time"), _world.get_state("time"))

func test_snapshot_do_mundo_montado_tem_todos_os_blocos() -> void:
	var data := _world.snapshot()
	for chave in ["save_version", "time", "inventory", "farm", "shipping"]:
		assert_true(data.has(chave), "bloco '%s' está no save" % chave)
