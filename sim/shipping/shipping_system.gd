class_name ShippingSystem
extends SimSystem

## Dono do caixote de venda.
##
## Segundo da ordem fixa de handle, entre Inventory e Farm. A posição é regra
## de jogo e faz duas coisas:
##
## - **depositar** chega aqui já cobrado — a `ShipItemAction` é uma
##   `RemoveItemAction`, então o InventorySystem tirou o item da mochila (ou
##   rejeitou a ação) antes;
## - **dormir** passa por aqui antes de Farm e Time, e é isso que implementa a
##   sequência do GAMEPLAY §3: caixote vende → culturas crescem → calendário
##   avança.
##
## Retirar é o caminho inverso e a única validação que o caixote faz sozinho:
## só ele sabe o que está lá dentro. O item volta para a mochila pela reação ao
## `ItemWithdrawnEvent`, nunca por este sistema conhecer o inventário.
##
## Não conhece item concreto nenhum: `item_id` + catálogo. Preço de venda vem do
## `ItemDef` — fonte única; id sem definição vale 0.

const MOTIVO_ITEM_INSUFICIENTE: String = "item_insuficiente"

var _state: ShippingState
var _catalog: ItemCatalog

func _init(state: ShippingState = null, catalog: ItemCatalog = null) -> void:
	_state = state if state != null else ShippingState.new()
	_catalog = catalog if catalog != null else ItemCatalog.new()

func get_state() -> ShippingState:
	return _state

func get_catalog() -> ItemCatalog:
	return _catalog

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is ShipItemAction:
		return _ship(action as ShipItemAction)
	if action is WithdrawItemAction:
		return _withdraw(action as WithdrawItemAction)
	if action is SleepAction:
		return _sell_all(action)
	return []

## O item já saiu da mochila lá atrás: aqui é só guardar.
func _ship(action: ShipItemAction) -> Array[SimEvent]:
	if action.qtd <= 0:
		return []
	_state.add(action.item_id, action.qtd)

	var event := ItemShippedEvent.new()
	event.player_id = action.player_id
	event.item_id = action.item_id
	event.qtd = action.qtd
	event.total_apos = _state.count(action.item_id)
	return [event]

## Tudo ou nada, como na mochila: se falta, rejeita e não encosta no state.
func _withdraw(action: WithdrawItemAction) -> Array[SimEvent]:
	if action.qtd <= 0:
		return []
	if _state.count(action.item_id) < action.qtd:
		action.rejeitada = true
		return [_rejeitada(action, MOTIVO_ITEM_INSUFICIENTE)]

	_state.remove(action.item_id, action.qtd)

	var event := ItemWithdrawnEvent.new()
	event.player_id = action.player_id
	event.item_id = action.item_id
	event.qtd = action.qtd
	event.total_apos = _state.count(action.item_id)
	return [event]

## Dormir esvazia o caixote e transforma o conteúdo nas linhas do resumo.
##
## Roda antes de Farm e Time: é o passo 1 da sequência de dormir. Caixote vazio
## não emite nada — sem mudança, sem evento.
##
## Item sem `ItemDef` vale 0 mas ainda ganha linha: ele saiu do caixote, e
## sumir da tela seria pior do que aparecer valendo nada.
func _sell_all(action: SimAction) -> Array[SimEvent]:
	if _state.is_empty():
		return []

	var event := ItemsSoldEvent.new()
	event.player_id = action.player_id
	for item_id in _state.item_ids():
		var def := _catalog.get_def(item_id)
		var preco := def.preco_venda if def != null else 0
		var linha := ItemsSoldEvent.Linha.new(item_id, _state.count(item_id), preco)
		event.linhas.append(linha)
		event.total += linha.subtotal
		event.total_itens += linha.qtd
	_state.clear()
	return [event]

func _rejeitada(action: SimAction, motivo: String) -> ActionRejectedEvent:
	var event := ActionRejectedEvent.new()
	event.player_id = action.player_id
	event.acao = action.get_script().get_global_name()
	event.motivo = motivo
	return event
