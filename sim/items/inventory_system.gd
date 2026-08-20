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
##
## É ele quem resolve a compra de semente inteira: o preço mora no `CropDef`
## (leitura livre) e o saldo é dele. O caixote não participa da compra — a aba
## de compra do painel é só UI. A venda é o inverso: o caixote emite o fato e a
## carteira reage somando.

const MOTIVO_ITEM_INSUFICIENTE: String = "item_insuficiente"
const MOTIVO_DINHEIRO_INSUFICIENTE: String = "dinheiro_insuficiente"
const MOTIVO_CULTURA_DESCONHECIDA: String = "cultura_desconhecida"

var _state: InventoryState
var _catalog: ItemCatalog
var _crops: CropCatalog

func _init(state: InventoryState = null, catalog: ItemCatalog = null,
		crops: CropCatalog = null) -> void:
	_state = state if state != null else InventoryState.new()
	_catalog = catalog if catalog != null else ItemCatalog.new()
	_crops = crops if crops != null else CropCatalog.new()

func get_state() -> InventoryState:
	return _state

func get_catalog() -> ItemCatalog:
	return _catalog

## Catálogo de culturas: a carteira o consulta só para saber o preço da semente
## na compra. Definição é leitura livre; state alheio é que é proibido.
func get_crop_catalog() -> CropCatalog:
	return _crops

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is AddItemAction:
		return _add_item(action as AddItemAction)
	if action is RemoveItemAction:
		return _remove_item(action as RemoveItemAction)
	if action is AddMoneyAction:
		return _add_money(action as AddMoneyAction)
	if action is BuySeedAction:
		return _buy_seed(action as BuySeedAction)
	return []

## Qualquer mecânica que conceda item emite um `ItemGrantedEvent`; a mochila
## reage adicionando, sem conhecer a mecânica de origem (colheita hoje, pesca
## amanhã). É o único jeito de um sistema pôr item no inventário sem que o
## inventário conheça o sistema.
##
## O dinheiro da venda do caixote entra pelo mesmo caminho: o ShippingSystem
## emite o fato (`ItemsSoldEvent`) e a carteira reage somando. Nenhum dos dois
## lê o state do outro.
func react(event: SimEvent) -> Array[SimEvent]:
	if event is ItemsSoldEvent:
		return _receive_sale(event as ItemsSoldEvent)
	if not event is ItemGrantedEvent:
		return []
	var granted := event as ItemGrantedEvent
	var action := AddItemAction.new()
	action.player_id = granted.player_id
	action.item_id = granted.item_id
	action.qtd = granted.qtd
	return _add_item(action)

## O caixote vendeu: quem dormiu recebe. Total zero (só ferramenta no caixote)
## não mexe na carteira — sem mudança, sem evento.
func _receive_sale(sold: ItemsSoldEvent) -> Array[SimEvent]:
	var action := AddMoneyAction.new()
	action.player_id = sold.player_id
	action.valor = sold.total
	return _add_money(action)

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

## Compra o lote inteiro ou nenhuma semente: o preço sai do `CropDef` e o saldo
## é validado antes de qualquer coisa mudar.
##
## A mochila cheia não rejeita a compra — perder o que não coube é consequência
## (`ItemLostEvent`), não impossibilidade. É o mesmo contrato de toda entrada
## de item.
func _buy_seed(action: BuySeedAction) -> Array[SimEvent]:
	if action.qtd <= 0:
		return []
	var def := _crops.get_def(action.crop_id)
	if def == null:
		action.rejeitada = true
		return [_rejeitada(action, MOTIVO_CULTURA_DESCONHECIDA)]

	var custo := def.preco_semente * action.qtd
	var inv := _state.get_player(action.player_id)
	if inv.dinheiro < custo:
		action.rejeitada = true
		return [_rejeitada(action, MOTIVO_DINHEIRO_INSUFICIENTE)]

	var bought := SeedBoughtEvent.new()
	bought.player_id = action.player_id
	bought.crop_id = def.id
	bought.item_id = def.item_semente_id()
	bought.qtd = action.qtd
	bought.preco_unitario = def.preco_semente
	bought.custo_total = custo

	var events: Array[SimEvent] = []
	events.append(bought)

	var pagamento := AddMoneyAction.new()
	pagamento.player_id = action.player_id
	pagamento.valor = -custo
	events.append_array(_add_money(pagamento))

	var entrega := AddItemAction.new()
	entrega.player_id = action.player_id
	entrega.item_id = bought.item_id
	entrega.qtd = action.qtd
	events.append_array(_add_item(entrega))
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
