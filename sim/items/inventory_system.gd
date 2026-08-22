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
const MOTIVO_SLOT_INVALIDO: String = "slot_invalido"

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
	if action is EquiparSlotAction:
		return _equipar_slot(action as EquiparSlotAction)
	if action is MoverSlotAction:
		return _mover_slot(action as MoverSlotAction)
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

	# Cheio o que já existia, o resto ocupa a **primeira posição livre** — e não
	# o fim da lista. Desde a wave 11.3 o slot tem endereço: item novo entra no
	# buraco mais à esquerda, que é onde todo jogo do gênero o põe.
	while restante > 0:
		var livre: int = inv.primeiro_livre()
		if livre < 0:
			break
		var porcao: int = mini(stack_max, restante)
		inv.slots[livre] = InventoryState.Slot.new(action.item_id, porcao)
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
	_esvazia_zerados(inv)

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
## Troca o slot que está na mão. É a ação da hotbar.
##
## Três regras, e nenhuma delas é sobre o item:
##
## 1. **Slot fora da mochila é recusa** — impossível vira motivo, como qualquer
##    outra ação.
## 2. **Slot vazio vale.** Mão vazia é estado legítimo: é com ela que se colhe,
##    e é ela que sobra quando um stack acaba.
## 3. **Equipar o slot que já está na mão não emite nada.** Sem mudança, sem
##    evento — é o que impede a hotbar de encher o diário quando alguém martela
##    a tecla 1.
func _equipar_slot(action: EquiparSlotAction) -> Array[SimEvent]:
	var inv := _state.get_player(action.player_id)
	if action.slot < 0 or action.slot >= inv.capacity:
		return [_rejeitada(action, MOTIVO_SLOT_INVALIDO)]
	if action.slot == inv.slot_na_mao:
		return []

	inv.slot_na_mao = action.slot

	var event := SlotEquipadoEvent.new()
	event.player_id = action.player_id
	event.slot = action.slot
	event.item_id = _item_na_mao(inv)
	return [event]

## Rearranja a mochila: o arrastar. Três resultados, e a diferença entre eles é
## o que está no destino.
##
## 1. **Vazio** → o item muda de endereço.
## 2. **Item diferente** → os dois trocam de lugar. Trocar em vez de recusar é o
##    que deixa reorganizar uma mochila cheia; recusar exigiria um slot livre de
##    manobra e transformaria arrastar num quebra-cabeça.
## 3. **Mesmo item** → empilha até o `stack_max`. O que não couber fica na
##    origem, e não some.
##
## A mão **não segue o item**: ela é um índice. Quem move o que estava na mão
## continua com a mão no mesmo slot, agora com outra coisa — é como toda hotbar
## do gênero se comporta.
func _mover_slot(action: MoverSlotAction) -> Array[SimEvent]:
	var inv := _state.get_player(action.player_id)
	var origem := inv.slot_em(action.de)
	var destino := inv.slot_em(action.para)
	if origem == null or destino == null:
		action.rejeitada = true
		return [_rejeitada(action, MOTIVO_SLOT_INVALIDO)]
	if action.de == action.para or origem.vazio():
		# Sem mudança, sem evento. Arrastar um slot vazio para o lado é gesto
		# perdido, não impossibilidade.
		return []

	var empilhou := false
	if not destino.vazio() and destino.item_id == origem.item_id:
		var cabe: int = mini(
			_catalog.stack_max_of(destino.item_id) - destino.qtd, origem.qtd)
		if cabe <= 0:
			# Destino cheio do mesmo item: não há o que fazer, e trocar dois
			# stacks iguais de lugar não seria movimento nenhum.
			return []
		destino.qtd += cabe
		origem.qtd -= cabe
		if origem.qtd <= 0:
			origem.esvazia()
		empilhou = true
	else:
		var guardado := InventoryState.Slot.new(destino.item_id, destino.qtd)
		destino.item_id = origem.item_id
		destino.qtd = origem.qtd
		origem.item_id = guardado.item_id
		origem.qtd = guardado.qtd

	var event := SlotMovidoEvent.new()
	event.player_id = action.player_id
	event.de = action.de
	event.para = action.para
	event.item_de = origem.item_id
	event.item_para = destino.item_id
	event.empilhou = empilhou
	return [event]

## O que está na mão, ou vazio. O índice pode apontar além dos stacks que
## existem hoje — a mochila esvazia e a mão fica onde estava.
func _item_na_mao(inv: InventoryState.PlayerInventory) -> String:
	if inv.slot_na_mao < 0 or inv.slot_na_mao >= inv.slots.size():
		return ""
	return inv.slots[inv.slot_na_mao].item_id

## Stack que zerou vira **posição livre no lugar**, e não some da lista.
##
## Até a wave 11.3 ele era removido e todo mundo à direita deslizava — o que
## fazia a mão do jogador, que é um índice, passar a segurar outra coisa
## sozinha quando o último de um stack acabava.
func _esvazia_zerados(inv: InventoryState.PlayerInventory) -> void:
	for slot in inv.slots:
		if slot.qtd <= 0:
			slot.esvazia()

func _rejeitada(action: SimAction, motivo: String) -> ActionRejectedEvent:
	var event := ActionRejectedEvent.new()
	event.player_id = action.player_id
	event.acao = action.get_script().get_global_name()
	event.motivo = motivo
	return event
