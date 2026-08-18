class_name InventorySystem
extends SimSystem

## Dono da mochila e do dinheiro de cada jogador.
##
## Primeiro da ordem fixa de handle: é ele quem descobre que falta semente ou
## falta dinheiro e marca a ação como rejeitada, antes de qualquer sistema
## executar. Validação em cadeia — ninguém desfaz nada.
##
## Não conhece item concreto nenhum: `item_id` + catálogo. Stack máximo vem da
## definição; id sem definição cai no padrão.

const MOTIVO_ITEM_INSUFICIENTE: String = "item_insuficiente"
const MOTIVO_DINHEIRO_INSUFICIENTE: String = "dinheiro_insuficiente"

var _state: InventoryState
var _catalog: ItemCatalog

func _init(state: InventoryState = null, catalog: ItemCatalog = null) -> void:
	_state = state if state != null else InventoryState.new()
	_catalog = catalog if catalog != null else ItemCatalog.new()

func get_state() -> InventoryState:
	return _state

func get_catalog() -> ItemCatalog:
	return _catalog

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is AddItemAction:
		return _add_item(action as AddItemAction)
	if action is RemoveItemAction:
		return _remove_item(action as RemoveItemAction)
	if action is AddMoneyAction:
		return _add_money(action as AddMoneyAction)
	return []

## Empilha no que já existe antes de abrir slot novo. O que não couber some:
## o jogador é avisado por `ItemLostEvent`, mas a ação aconteceu — perder item
## não é impossibilidade, é consequência.
func _add_item(action: AddItemAction) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	if action.qtd <= 0:
		return events

	var inv := _state.get_player(action.player_id)
	var stack_max := _catalog.stack_max_of(action.item_id)
	var restante := action.qtd

	for slot in inv.slots:
		if restante <= 0:
			break
		if slot.item_id != action.item_id:
			continue
		var cabe: int = mini(stack_max - slot.qtd, restante)
		slot.qtd += cabe
		restante -= cabe

	while restante > 0 and inv.slots.size() < inv.capacity:
		var porcao: int = mini(stack_max, restante)
		inv.slots.append(InventoryState.Slot.new(action.item_id, porcao))
		restante -= porcao

	var entrou := action.qtd - restante
	if entrou > 0:
		var added := ItemAddedEvent.new()
		added.player_id = action.player_id
		added.item_id = action.item_id
		added.qtd = entrou
		added.total_apos = inv.count(action.item_id)
		events.append(added)
	if restante > 0:
		var lost := ItemLostEvent.new()
		lost.player_id = action.player_id
		lost.item_id = action.item_id
		lost.qtd = restante
		events.append(lost)
	return events

## Tudo ou nada: não existe remoção parcial. Se falta, rejeita e não encosta
## no state.
func _remove_item(action: RemoveItemAction) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	if action.qtd <= 0:
		return events

	var inv := _state.get_player(action.player_id)
	if inv.count(action.item_id) < action.qtd:
		action.rejeitada = true
		events.append(_rejeitada(action, MOTIVO_ITEM_INSUFICIENTE))
		return events

	var restante := action.qtd
	for slot in inv.slots:
		if restante <= 0:
			break
		if slot.item_id != action.item_id:
			continue
		var tirado: int = mini(slot.qtd, restante)
		slot.qtd -= tirado
		restante -= tirado
	_limpa_slots_vazios(inv)

	var removed := ItemRemovedEvent.new()
	removed.player_id = action.player_id
	removed.item_id = action.item_id
	removed.qtd = action.qtd
	removed.total_apos = inv.count(action.item_id)
	events.append(removed)
	return events

## `valor` negativo é gasto. Zerar pode; ficar negativo não.
func _add_money(action: AddMoneyAction) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	if action.valor == 0:
		return events

	var inv := _state.get_player(action.player_id)
	var de := inv.dinheiro
	var para := de + action.valor
	if para < 0:
		action.rejeitada = true
		events.append(_rejeitada(action, MOTIVO_DINHEIRO_INSUFICIENTE))
		return events

	inv.dinheiro = para
	var changed := MoneyChangedEvent.new()
	changed.player_id = action.player_id
	changed.de = de
	changed.para = para
	changed.delta = action.valor
	events.append(changed)
	return events

## Slot zerado não fica ocupando lugar na mochila.
func _limpa_slots_vazios(inv: InventoryState.PlayerInventory) -> void:
	for i in range(inv.slots.size() - 1, -1, -1):
		if inv.slots[i].qtd <= 0:
			inv.slots.remove_at(i)

func _rejeitada(action: SimAction, motivo: String) -> ActionRejectedEvent:
	var event := ActionRejectedEvent.new()
	event.player_id = action.player_id
	event.acao = action.get_script().get_global_name()
	event.motivo = motivo
	return event
