extends GutTest

## Ações formais de inventário: stack, capacity, item perdido, dinheiro e a
## validação em cadeia.

var _state: InventoryState
var _catalog: ItemCatalog
var _system: InventorySystem

func before_each() -> void:
	_state = InventoryState.new()
	_catalog = ItemCatalog.new()
	_catalog.register(_def("rabanete", 999))
	_catalog.register(_def("enxada", 1))
	_system = InventorySystem.new(_state, _catalog)

func _def(id: String, stack_max: int) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.stack_max = stack_max
	return def

func _add(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := AddItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _system.handle(action)

func _remove(item_id: String, qtd: int, player_id: int = 0) -> Array[SimEvent]:
	var action := RemoveItemAction.new()
	action.player_id = player_id
	action.item_id = item_id
	action.qtd = qtd
	return _system.handle(action)

func _money(valor: int, player_id: int = 0) -> Array[SimEvent]:
	var action := AddMoneyAction.new()
	action.player_id = player_id
	action.valor = valor
	return _system.handle(action)

func _slot(item_id: String, qtd: int) -> InventoryState.Slot:
	return InventoryState.Slot.new(item_id, qtd)

func _inv(player_id: int = 0) -> InventoryState.PlayerInventory:
	return _state.get_player(player_id)

## Troca a mochila do jogador por uma de N slots.
##
## Não dá para só baixar `capacity`: desde a wave 11.3 o slot tem endereço, e
## `garante_tamanho` só cresce — encolher jogaria fora o item que estivesse no
## fim. Uma mochila pequena se monta pelo save, que é como o jogo faria.
func _capacidade(n: int) -> void:
	_state.from_dict({"0": {"slots": [], "capacity": n, "dinheiro": 500}})


func test_ganhar_item_abre_slot_e_avisa() -> void:
	var events := _add("rabanete", 3)

	assert_eq(_inv().count("rabanete"), 3, "o item entrou")
	assert_eq(_inv().ocupados(), 1, "um stack só")
	assert_eq(events.size(), 1)
	var event := events[0] as ItemAddedEvent
	assert_not_null(event, "emite ItemAddedEvent")
	assert_eq(event.item_id, "rabanete")
	assert_eq(event.qtd, 3, "quanto entrou")
	assert_eq(event.total_apos, 3, "quanto o jogador tem agora — game/ não precisa perguntar")
	assert_eq(event.player_id, 0)

func test_item_repetido_empilha_no_slot_existente() -> void:
	_add("rabanete", 3)
	_add("rabanete", 4)
	assert_eq(_inv().ocupados(), 1, "não abre slot novo à toa")
	assert_eq(_inv().count("rabanete"), 7)

func test_passar_do_stack_max_abre_outro_slot() -> void:
	_add("enxada", 2)
	assert_eq(_inv().ocupados(), 2, "ferramenta é stack 1: dois slots")
	assert_eq(_inv().count("enxada"), 2)

func test_stack_max_desconhecido_cai_no_padrao() -> void:
	_add("dragao", 999)
	assert_eq(_inv().ocupados(), 1, "sem definição no catálogo, stack padrão 999")

func test_ganhar_quantidade_invalida_nao_faz_nada() -> void:
	assert_eq(_add("rabanete", 0), [], "sem mudança, sem evento")
	assert_eq(_add("rabanete", -5), [], "quantidade negativa é ignorada")
	assert_eq(_inv().ocupados(), 0)

func test_inventario_cheio_perde_a_sobra() -> void:
	_capacidade(1)
	_add("rabanete", 995)

	var events := _add("rabanete", 10)

	assert_eq(_inv().count("rabanete"), 999, "encheu o stack até o limite")
	assert_eq(events.size(), 2, "o que coube entrou, o resto se perdeu")
	assert_eq((events[0] as ItemAddedEvent).qtd, 4)
	var perdido := events[1] as ItemLostEvent
	assert_not_null(perdido, "emite ItemLostEvent")
	assert_eq(perdido.qtd, 6, "a sobra que não coube")
	assert_eq(perdido.item_id, "rabanete")

func test_sem_espaco_nenhum_o_item_todo_se_perde() -> void:
	_capacidade(1)
	_add("rabanete", 999)

	var events := _add("rabanete", 5)

	assert_eq(events.size(), 1, "nada entrou: só o aviso de perda")
	assert_not_null(events[0] as ItemLostEvent)
	assert_eq((events[0] as ItemLostEvent).qtd, 5)

func test_perder_item_nao_rejeita_a_acao() -> void:
	_capacidade(1)
	_add("rabanete", 999)
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5
	_system.handle(action)
	assert_false(action.rejeitada, "o item se perdeu, mas a ação aconteceu")

func test_gastar_item_tira_e_avisa() -> void:
	_add("rabanete", 10)

	var events := _remove("rabanete", 4)

	assert_eq(_inv().count("rabanete"), 6)
	var event := events[0] as ItemRemovedEvent
	assert_not_null(event, "emite ItemRemovedEvent")
	assert_eq(event.qtd, 4)
	assert_eq(event.total_apos, 6)

## O stack que zera **esvazia no lugar**. Antes ele era removido e todo mundo à
## direita deslizava — o que fazia a mão do jogador, que é um índice, passar a
## segurar outra coisa sozinha.
func test_gastar_esvazia_o_slot_sem_deslocar_os_vizinhos() -> void:
	_add("enxada", 3)
	_add("rabanete", 1)
	assert_eq(_inv().ocupados(), 4, "três enxadas de stack 1 mais o rabanete")

	_remove("enxada", 2)

	assert_eq(_inv().count("enxada"), 1)
	assert_eq(_inv().ocupados(), 2, "os dois slots gastos ficaram livres")
	assert_eq(_inv().slots[3].item_id, "rabanete", "o vizinho não andou de endereço")

func test_gastar_o_que_nao_tem_rejeita_a_acao() -> void:
	_add("rabanete", 2)
	var action := RemoveItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5

	var events := _system.handle(action)

	assert_true(action.rejeitada, "quem detecta a impossibilidade marca a flag")
	assert_eq(_inv().count("rabanete"), 2, "nada foi tirado — ninguém desfaz nada")
	var event := events[0] as ActionRejectedEvent
	assert_not_null(event, "emite ActionRejectedEvent")
	assert_eq(event.motivo, InventorySystem.MOTIVO_ITEM_INSUFICIENTE)
	assert_eq(event.acao, "RemoveItemAction", "o evento diz qual ação caiu")

func test_ganhar_dinheiro_avisa_a_transicao() -> void:
	var events := _money(250)

	assert_eq(_inv().dinheiro, 750)
	var event := events[0] as MoneyChangedEvent
	assert_not_null(event, "emite MoneyChangedEvent")
	assert_eq(event.de, 500)
	assert_eq(event.para, 750)
	assert_eq(event.delta, 250)

func test_gastar_dinheiro_e_a_mesma_acao_com_valor_negativo() -> void:
	var events := _money(-200)
	assert_eq(_inv().dinheiro, 300)
	assert_eq((events[0] as MoneyChangedEvent).delta, -200)

func test_gastar_mais_do_que_tem_rejeita_a_acao() -> void:
	var action := AddMoneyAction.new()
	action.valor = -501

	var events := _system.handle(action)

	assert_true(action.rejeitada)
	assert_eq(_inv().dinheiro, 500, "dinheiro intacto")
	assert_eq((events[0] as ActionRejectedEvent).motivo, InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE)

func test_gastar_tudo_e_permitido() -> void:
	_money(-500)
	assert_eq(_inv().dinheiro, 0, "zerar pode; negativo não")

func test_valor_zero_nao_faz_nada() -> void:
	assert_eq(_money(0), [], "sem mudança, sem evento")

func test_acao_ja_rejeitada_e_ignorada() -> void:
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 5
	action.rejeitada = true

	assert_eq(_system.handle(action), [], "sistema seguinte ignora ação rejeitada")
	assert_eq(_inv().count("rabanete"), 0, "e não mexe no state")

func test_acao_desconhecida_e_ignorada() -> void:
	assert_eq(_system.handle(SimAction.new()), [], "quem não reconhece devolve []")

func test_cada_player_mexe_no_proprio_inventario() -> void:
	_add("rabanete", 5, 1)
	assert_eq(_inv(1).count("rabanete"), 5)
	assert_eq(_inv(0).count("rabanete"), 0, "co-op: ação carrega o dono")

# --- Equipar: o que está na mão ---

func _equipa(slot: int, player_id: int = 0) -> Array[SimEvent]:
	var action := EquiparSlotAction.new()
	action.player_id = player_id
	action.slot = slot
	return _system.handle(action)

func test_equipar_muda_a_mao_e_avisa_com_o_item() -> void:
	_add("enxada", 1)
	_add("rabanete", 3)

	var events := _equipa(1)

	assert_eq(_inv().slot_na_mao, 1, "a mão mudou de slot")
	assert_eq(events.size(), 1)
	var event := events[0] as SlotEquipadoEvent
	assert_not_null(event, "emite SlotEquipadoEvent")
	assert_eq(event.slot, 1)
	assert_eq(event.item_id, "rabanete",
		"o evento é gordo: game/ não precisa perguntar o que ficou na mão")

## Slot vazio é mão vazia, e mão vazia é um estado legítimo — colher funciona
## com ela. Por isso equipar um slot sem item não é recusa.
func test_equipar_slot_vazio_e_mao_vazia() -> void:
	var events := _equipa(5)

	assert_eq(_inv().slot_na_mao, 5)
	assert_eq((events[0] as SlotEquipadoEvent).item_id, "", "mão vazia")

## Fora da mochila é impossível, e impossível é recusa com motivo — a mesma
## regra de qualquer outra ação.
func test_equipar_fora_da_capacidade_e_recusa() -> void:
	var events := _equipa(_inv().capacity)

	assert_eq(_inv().slot_na_mao, 0, "a mão não se mexeu")
	var recusa := events[0] as ActionRejectedEvent
	assert_not_null(recusa, "emite ActionRejectedEvent")
	assert_eq(recusa.motivo, InventorySystem.MOTIVO_SLOT_INVALIDO)

func test_equipar_slot_negativo_e_recusa() -> void:
	var events := _equipa(-1)
	assert_eq((events[0] as ActionRejectedEvent).motivo, InventorySystem.MOTIVO_SLOT_INVALIDO)

## Equipar o slot que já está na mão não muda nada: sem mudança, sem evento. É
## a mesma regra do resto da sim, e é ela que impede a hotbar de encher o diário
## quando alguém martela a tecla 1.
func test_equipar_o_mesmo_slot_nao_emite_nada() -> void:
	_add("enxada", 1)
	assert_eq(_equipa(0), [] as Array[SimEvent], "já estava na mão")

func test_a_mao_e_de_cada_jogador() -> void:
	_equipa(3, 1)
	assert_eq(_inv(1).slot_na_mao, 3)
	assert_eq(_inv(0).slot_na_mao, 0, "co-op: a mão carrega o dono")

# --- Mover: o arrastar ---

func _move(de: int, para: int, player_id: int = 0) -> Array[SimEvent]:
	var action := MoverSlotAction.new()
	action.player_id = player_id
	action.de = de
	action.para = para
	return _system.handle(action)

func test_mover_para_vazio_muda_o_endereco() -> void:
	_add("rabanete", 3)

	var events := _move(0, 5)

	assert_true(_inv().slots[0].vazio(), "a origem ficou livre")
	assert_eq(_inv().slots[5].item_id, "rabanete", "o item foi para onde o jogador o pôs")
	assert_eq(_inv().slots[5].qtd, 3, "o stack inteiro foi junto")
	var event := events[0] as SlotMovidoEvent
	assert_not_null(event, "emite SlotMovidoEvent")
	assert_eq(event.item_para, "rabanete", "o evento diz o que ficou em cada ponta")
	assert_eq(event.item_de, "", "e a origem ficou vazia")

## Trocar, e não recusar: recusar exigiria um slot livre de manobra e
## transformaria reorganizar uma mochila cheia num quebra-cabeça.
func test_mover_para_item_diferente_troca_os_dois() -> void:
	_add("rabanete", 3)
	_add("enxada", 1)

	_move(0, 1)

	assert_eq(_inv().slots[0].item_id, "enxada", "o de baixo subiu")
	assert_eq(_inv().slots[1].item_id, "rabanete", "e o de cima desceu")
	assert_eq(_inv().slots[1].qtd, 3, "a quantidade veio junto")

func test_mover_para_o_mesmo_item_empilha() -> void:
	_add("rabanete", 3)
	_inv().slots[4] = _slot("rabanete", 2)

	var events := _move(0, 4)

	assert_eq(_inv().slots[4].qtd, 5, "os dois viraram um stack só")
	assert_true(_inv().slots[0].vazio(), "a origem esvaziou")
	assert_true((events[0] as SlotMovidoEvent).empilhou, "o evento diz que juntou")

func test_empilhar_respeita_o_stack_max_e_a_sobra_fica() -> void:
	_inv().slots[0] = _slot("rabanete", 10)
	_inv().slots[1] = _slot("rabanete", 995)

	_move(0, 1)

	assert_eq(_inv().slots[1].qtd, 999, "encheu até o limite")
	assert_eq(_inv().slots[0].qtd, 6, "a sobra ficou onde estava, e não sumiu")

func test_empilhar_em_stack_ja_cheio_nao_faz_nada() -> void:
	_inv().slots[0] = _slot("rabanete", 5)
	_inv().slots[1] = _slot("rabanete", 999)

	assert_eq(_move(0, 1), [] as Array[SimEvent], "sem mudança, sem evento")
	assert_eq(_inv().slots[0].qtd, 5, "nada se mexeu")

func test_mover_slot_vazio_nao_faz_nada() -> void:
	assert_eq(_move(3, 4), [] as Array[SimEvent], "arrastar o vazio é gesto perdido")

func test_mover_para_o_mesmo_slot_nao_faz_nada() -> void:
	_add("rabanete", 3)
	assert_eq(_move(0, 0), [] as Array[SimEvent], "soltar onde pegou não é movimento")

func test_mover_para_fora_da_mochila_e_recusa() -> void:
	_add("rabanete", 3)
	var action := MoverSlotAction.new()
	action.de = 0
	action.para = _inv().capacity

	var events := _system.handle(action)

	assert_true(action.rejeitada)
	assert_eq((events[0] as ActionRejectedEvent).motivo, InventorySystem.MOTIVO_SLOT_INVALIDO)
	assert_eq(_inv().slots[0].item_id, "rabanete", "nada se mexeu")

## A mão é um índice, não um item. Quem move o que estava na mão continua com a
## mão no mesmo slot — agora com outra coisa.
func test_mover_nao_arrasta_a_mao_junto() -> void:
	_add("enxada", 1)
	_equipa(0)

	_move(0, 3)

	assert_eq(_inv().slot_na_mao, 0, "a mão seguiu o item em vez de ficar no slot")

func test_sistema_nasce_com_state_e_catalogo_proprios() -> void:
	var solo := InventorySystem.new()
	assert_eq(solo.get_state().get_player(0).dinheiro, 500, "sem state injetado, cria o próprio")

func test_roda_dentro_do_sim_world() -> void:
	var world := SimWorld.new()
	world.register_system(_system)
	var action := AddItemAction.new()
	action.item_id = "rabanete"
	action.qtd = 2

	var events := world.handle(action)

	assert_eq(events.size(), 1, "o evento sai pela fila do mundo")
	assert_not_null(events[0] as ItemAddedEvent)
