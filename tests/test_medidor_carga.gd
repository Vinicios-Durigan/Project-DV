extends GutTest

## O número da água na tela — na mira e no slot da mão.
##
## Regar até acabar tem que ser legível **sem abrir painel**: o jogador está no
## meio do canteiro, olhando para o retículo, e é ali que ele precisa ver que
## restam duas regadas. Descobrir o regador vazio só quando o clique é recusado
## é tarde demais para planejar a rota.
##
## ## A tela não faz a conta
##
## Nenhum `if` de regra e nenhum decremento acontece aqui: o número sai do
## `snapshot()`, e a tela só relê quando um evento avisa que ele mudou — uma
## regada saiu (`PlotWateredEvent`) ou o regador voltou cheio
## (`RegadorEnchidoEvent`). Se a tela contasse sozinha, ela e a sim divergiriam
## na primeira recusa.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelMochila
var _mira: MiraFerramentas


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
	_mira = _playground.get_mundo().get_node("MiraFerramentas") as MiraFerramentas

func _inventario() -> InventoryState.PlayerInventory:
	return _bridge.get_factory().get_inventory_state().get_player(JOGADOR)

## O índice do slot onde o regador foi entregue.
func _slot_do_regador() -> int:
	var inv := _inventario()
	for i in inv.slots.size():
		if inv.slots[i].item_id == "regador":
			return i
	return -1

func _equipa_o_regador() -> void:
	var acao := EquiparSlotAction.new()
	acao.player_id = JOGADOR
	acao.slot = _slot_do_regador()
	_bridge.dispatch(acao)

func _define_carga(quanto: int) -> void:
	_inventario().slots[_slot_do_regador()].carga = quanto

## O rótulo de carga dentro de um quadrado da hotbar, ou "".
func _carga_na_hotbar(indice: int) -> String:
	var slot := _painel._hotbar.get_child(indice) as Control
	for filho in slot.get_children():
		var rotulo := filho as Label
		if rotulo != null and "/" in rotulo.text:
			return rotulo.text
	return ""


# --- Na hotbar ---

func test_o_regador_mostra_quanto_tem() -> void:
	_define_carga(9)
	_painel._atualiza()
	assert_eq(_carga_na_hotbar(_slot_do_regador()), "9/15",
			"o medidor sai do snapshot, não de uma conta feita na tela")

func test_o_regador_cheio_mostra_o_teto() -> void:
	_define_carga(15)
	_painel._atualiza()
	assert_eq(_carga_na_hotbar(_slot_do_regador()), "15/15")

func test_a_enxada_nao_ganha_medidor() -> void:
	var inv := _inventario()
	var enxada := -1
	for i in inv.slots.size():
		if inv.slots[i].item_id == "enxada":
			enxada = i
	_painel._atualiza()
	assert_eq(_carga_na_hotbar(enxada), "",
			"capacidade zero não vira 0/0 — quem não carrega não mostra número")

func test_slot_vazio_nao_ganha_medidor() -> void:
	_painel._atualiza()
	assert_eq(_carga_na_hotbar(PainelMochila.SLOTS_HOTBAR - 1), "",
			"posição livre não tem o que medir")


# --- Na mira ---

func test_a_mira_escreve_a_carga_junto_do_nome() -> void:
	_define_carga(4)
	_equipa_o_regador()
	assert_eq(_mira.item_na_mao(), "regador", "o regador está na mão")
	assert_eq(_mira.rotulo(), "Regador 4/15",
			"é o número que o jogador olha sem tirar os olhos do canteiro")

func test_a_mira_nao_escreve_carga_de_quem_nao_carrega() -> void:
	assert_eq(_mira.rotulo(), "Enxada",
			"a mão começa na enxada, e ela não tem água para mostrar")


# --- A tela acompanha a sim ---

func test_encher_no_poco_atualiza_a_mira() -> void:
	_define_carga(0)
	_equipa_o_regador()
	assert_eq(_mira.rotulo(), "Regador 0/15", "vazio antes")

	var encher := EncherRegadorAction.new()
	encher.player_id = JOGADOR
	_bridge.dispatch(encher)

	assert_eq(_mira.rotulo(), "Regador 15/15",
			"o RegadorEnchidoEvent é o gatilho — a tela releu, não contou")

func test_regar_atualiza_a_mira() -> void:
	_define_carga(5)
	_equipa_o_regador()
	_bridge.get_factory().get_farm_state().get_plot(1, 1).arada = true

	var rega := WaterPlotAction.new()
	rega.player_id = JOGADOR
	rega.x = 1
	rega.y = 1
	_bridge.dispatch(rega)

	assert_eq(_mira.rotulo(), "Regador 4/15",
			"o PlotWateredEvent é o gatilho da descida")
