extends GutTest

## Snapshot e restore do SimWorld: a sim inteira vira dict e volta idêntica.
##
## O roundtrip é o contrato do save. Se um campo novo não entra aqui, ele não
## sobrevive a fechar o jogo — e o teste é o único lugar que percebe isso.

var _world: SimWorld
var _time: TimeState
var _inventory: InventoryState
var _farm: FarmState
var _shipping: ShippingState


func before_each() -> void:
	_world = SimWorld.new()
	_time = TimeState.new()
	_inventory = InventoryState.new()
	_farm = FarmState.new()
	_shipping = ShippingState.new()
	_registra(_world, _time, _inventory, _farm, _shipping)


func _registra(
	world: SimWorld,
	time: TimeState,
	inventory: InventoryState,
	farm: FarmState,
	shipping: ShippingState
) -> void:
	world.register_state("time", time)
	world.register_state("inventory", inventory)
	world.register_state("farm", farm)
	world.register_state("shipping", shipping)


## Mexe em todo state registrado — nenhum bloco fica no default.
func _enche_o_mundo() -> void:
	_time.dia = 14
	_time.minuto = 700
	_time.estacao = "verao"

	var p1 := _inventory.get_player(1)
	p1.dinheiro = 1234
	p1.capacity = 30
	# Capacidade maior pede endereço para todos: desde a wave 11.3 o slot tem
	# posição fixa, e o snapshot grava um por capacidade. Sem completar aqui, o
	# state ficaria inconsistente e o roundtrip normalizaria o que o teste
	# escreveu à mão.
	p1.garante_tamanho()
	p1.slots[24] = _slot("cenoura", 5)
	p1.slots[25] = _slot("semente_abobora", 2)
	var p2 := _inventory.get_player(2)
	p2.dinheiro = 77
	# p2 tem a capacidade padrão (24): o último endereço é o 23.
	p2.slots[23] = _slot("morango", 1)

	var arado := _farm.get_plot(2, 3)
	arado.arada = true
	arado.regada = true
	var plantado := _farm.get_plot(-1, 4)
	plantado.arada = true
	plantado.crop_id = "cenoura"
	plantado.estagio = 2
	plantado.dias_no_estagio = 1

	_shipping.add("rabanete", 9)
	_shipping.add("abobora", 3)


## O tipo declarado importa: `Array[Slot]` não aceita o retorno de
## `Slot.new()` visto de fora sem uma variável tipada no meio.
func _slot(item_id: String, qtd: int) -> InventoryState.Slot:
	return InventoryState.Slot.new(item_id, qtd)

func _json(data: Dictionary) -> String:
	return JSON.stringify(data)


func test_snapshot_carimba_a_versao_do_save() -> void:
	# v2 desde a wave 11.2: arar e regar passaram a exigir ferramenta na mão, e o
	# save antigo precisa de um passo que a entregue.
	assert_eq(SimWorld.SAVE_VERSION, 2, "v2 congela nesta wave")
	assert_eq(int(_world.snapshot()["save_version"]), 2, "todo snapshot sai carimbado")

func test_snapshot_tem_um_bloco_por_state_registrado() -> void:
	var data := _world.snapshot()
	for chave in ["time", "inventory", "farm", "shipping"]:
		assert_true(data.has(chave), "bloco '%s' está no snapshot" % chave)

func test_mundo_sem_state_snapshota_so_a_versao() -> void:
	assert_eq(SimWorld.new().snapshot(), {"save_version": SimWorld.SAVE_VERSION}, "sem state, só o carimbo")

func test_state_keys_segue_a_ordem_de_registro() -> void:
	assert_eq(_world.state_keys(), ["time", "inventory", "farm", "shipping"], "ordem de registro é a ordem do save")

func test_state_keys_devolve_copia() -> void:
	var chaves := _world.state_keys()
	chaves.clear()
	assert_eq(_world.state_keys().size(), 4, "mexer na lista devolvida não desregistra state")

func test_registrar_a_mesma_chave_substitui_sem_duplicar() -> void:
	var outro := TimeState.new()
	outro.dia = 99
	_world.register_state("time", outro)
	assert_eq(_world.state_keys().size(), 4, "chave repetida não entra duas vezes")
	assert_eq(int((_world.snapshot()["time"] as Dictionary)["dia"]), 99, "o último registro é quem vale")

func test_roundtrip_de_estado_rico_volta_identico() -> void:
	_enche_o_mundo()
	var original := _world.snapshot()

	var destino := SimWorld.new()
	var time := TimeState.new()
	var inventory := InventoryState.new()
	var farm := FarmState.new()
	var shipping := ShippingState.new()
	_registra(destino, time, inventory, farm, shipping)
	destino.restore(original)

	assert_eq(_json(destino.snapshot()), _json(original), "o mundo volta idêntico ao que saiu")
	assert_eq(time.dia, 14, "dia voltou")
	assert_eq(time.estacao, "verao", "estação voltou")
	assert_eq(inventory.get_player(1).dinheiro, 1234, "dinheiro voltou")
	assert_eq(inventory.get_player(1).count("cenoura"), 5, "stack voltou")
	assert_eq(inventory.player_ids(), [1, 2], "os dois jogadores voltaram")
	assert_true(farm.peek_plot(2, 3).regada, "plot regado voltou")
	assert_eq(farm.peek_plot(-1, 4).crop_id, "cenoura", "cultura plantada voltou")
	assert_eq(farm.peek_plot(-1, 4).estagio, 2, "estágio da cultura voltou")
	assert_eq(shipping.count("rabanete"), 9, "caixote voltou")

func test_roundtrip_no_mesmo_mundo_nao_muda_nada() -> void:
	_enche_o_mundo()
	var original := _world.snapshot()
	_world.restore(original)
	assert_eq(_json(_world.snapshot()), _json(original), "restaurar sobre si mesmo é idempotente")

func test_restore_com_chave_ausente_volta_ao_default() -> void:
	_enche_o_mundo()
	_world.restore({"save_version": 1, "time": {"dia": 5, "minuto": 400, "estacao": "outono"}})

	assert_eq(_time.dia, 5, "o bloco presente carregou")
	assert_eq(_inventory.player_ids(), [], "bloco ausente volta ao default, não fica com o lixo de antes")
	assert_eq(_farm.plot_ids(), [], "fazenda ausente volta vazia")
	assert_true(_shipping.is_empty(), "caixote ausente volta vazio")

func test_restore_de_dict_vazio_zera_tudo() -> void:
	_enche_o_mundo()
	_world.restore({})
	assert_eq(_json(_world.snapshot()), _json(_padrao()), "sem dado nenhum, tudo cai no default")

func test_restore_ignora_bloco_desconhecido() -> void:
	_world.restore({"save_version": 1, "clima": {"chovendo": true}})
	assert_eq(_time.dia, TimeState.DIA_DEFAULT, "bloco de sistema que não existe aqui não quebra o load")

func test_snapshot_sobrevive_a_ida_e_volta_por_json() -> void:
	_enche_o_mundo()
	var texto := JSON.stringify(_world.snapshot())
	var lido: Variant = JSON.parse_string(texto)

	assert_typeof(lido, TYPE_DICTIONARY, "o snapshot é JSON puro — nenhum objeto vazou para dentro dele")
	_world.restore(lido as Dictionary)
	assert_eq(JSON.stringify(_world.snapshot()), texto, "roundtrip por texto também bate")


## O snapshot de um mundo em que ninguém tocou.
func _padrao() -> Dictionary:
	var world := SimWorld.new()
	_registra(world, TimeState.new(), InventoryState.new(), FarmState.new(), ShippingState.new())
	return world.snapshot()
