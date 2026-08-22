class_name InventoryState
extends RefCounted

## Estado do inventário, dono exclusivo do InventorySystem.
##
## O inventário é por `player_id` desde o primeiro dia — é o que deixa co-op
## futuro ser problema de rede, não de refatoração. Dinheiro mora aqui dentro,
## junto do player a quem pertence.
##
## Slot guarda `item_id` + quantidade: nenhum tipo concreto de conteúdo entra
## no state. `capacity` é o número de stacks, não de unidades.

const CAPACITY_PADRAO: int = 24
const DINHEIRO_PADRAO: int = 500

## O slot que começa na mão. É o primeiro da mochila, que é onde a `SimFactory`
## põe a enxada — e é o default que descreve corretamente um save gravado antes
## deste campo existir.
const SLOT_NA_MAO_PADRAO: int = 0


## Um stack: item + quantidade. Slot sem item é **posição vazia**, e não um
## buraco na lista — desde a wave 11.3 o endereço é fixo.
class Slot extends RefCounted:
	var item_id: String = ""
	var qtd: int = 0
	## Quanto o item deste slot ainda tem dentro — água, hoje.
	##
	## Mora no slot, e não no jogador, porque com dois regadores na mochila (o
	## velho e o do ferreiro) o número teria que pertencer a um deles. Quanto
	## **cabe** é do `ItemDef`; quanto **tem** é daqui.
	var carga: int = 0

	func _init(item_id_: String = "", qtd_: int = 0) -> void:
		item_id = item_id_
		qtd = qtd_

	## Posição livre. Quantidade zerada conta como vazia: é o que sobra quando o
	## jogador gasta o último de um stack.
	func vazio() -> bool:
		return item_id.is_empty() or qtd <= 0

	## Deixa a posição livre, sem tirá-la da lista. Tirar deslocaria todo mundo
	## à direita — e a mão do jogador é um índice.
	func esvazia() -> void:
		item_id = ""
		qtd = 0
		# A água era do regador que estava aqui. Deixá-la para trás daria meio
		# regador de graça ao próximo item que caísse nesta posição.
		carga = 0

	func to_dict() -> Dictionary:
		return {"item_id": item_id, "qtd": qtd, "carga": carga}

	## `carga` ausente é save de antes da wave 14.1: o regador abre vazio e o
	## jogador enche no primeiro poço. Sem migração.
	func from_dict(data: Dictionary) -> void:
		item_id = String(data.get("item_id", ""))
		qtd = int(data.get("qtd", 0))
		carga = maxi(int(data.get("carga", 0)), 0)


## A mochila de um jogador.
class PlayerInventory extends RefCounted:
	var slots: Array[Slot] = []
	var capacity: int = InventoryState.CAPACITY_PADRAO
	var dinheiro: int = InventoryState.DINHEIRO_PADRAO
	## Índice do slot que está na mão. É estado de jogo, não de tela: é ele que
	## decide o que a ação "usar" faz (`resolvedor_uso.gd`). Fora do save, o
	## jogador reabriria a partida de mãos vazias sem entender por quê.
	##
	## O índice pode apontar para slot que não existe — mochila esvazia e o
	## índice fica onde estava, como em qualquer hotbar. Quem lê trata a mão
	## vazia; guardar o item em vez do índice faria a mão pular sozinha quando um
	## stack acabasse.
	var slot_na_mao: int = InventoryState.SLOT_NA_MAO_PADRAO

	## A mochila nasce com um slot por capacidade, todos vazios. Endereço fixo
	## desde o primeiro frame: é o que faz "pôr o morango no slot 3" existir.
	func _init() -> void:
		garante_tamanho()

	## Completa a lista até a capacidade. Chamado depois de carregar o save (a
	## lista antiga era compacta e curta) e depois de a capacidade crescer.
	##
	## Nunca **encolhe**: capacidade menor com item no fim jogaria item fora, e
	## perder item calado é pior que uma mochila maior do que devia.
	func garante_tamanho() -> void:
		while slots.size() < capacity:
			slots.append(Slot.new())

	## O slot daquele índice, ou `null` fora da mochila. É por aqui que quem lê
	## índice — a mão, o arrastar — evita sair da lista.
	func slot_em(indice: int) -> Slot:
		if indice < 0 or indice >= slots.size():
			return null
		return slots[indice]

	## Primeira posição livre, ou -1 se a mochila está cheia.
	func primeiro_livre() -> int:
		for i in slots.size():
			if slots[i].vazio():
				return i
		return -1

	## Quantos slots têm item. É o número que a tela mostra como "3 / 24".
	func ocupados() -> int:
		var total := 0
		for slot in slots:
			if not slot.vazio():
				total += 1
		return total

	## Quanto o jogador tem do item, somando todos os stacks. Id vazio é posição
	## livre, não um item — perguntar por ele responde zero.
	func count(item_id: String) -> int:
		if item_id.is_empty():
			return 0
		var total := 0
		for slot in slots:
			if slot.item_id == item_id:
				total += slot.qtd
		return total

	func to_dict() -> Dictionary:
		var slots_data: Array[Dictionary] = []
		for slot in slots:
			slots_data.append(slot.to_dict())
		return {
			"slots": slots_data,
			"capacity": capacity,
			"dinheiro": dinheiro,
			"slot_na_mao": slot_na_mao,
		}

	## Save antigo (até a wave 11.2) gravava uma lista **compacta**, mais curta
	## que a capacidade. Lida posicionalmente, ela cai nas primeiras posições —
	## que é onde os itens estavam. É por isso que o endereço fixo entrou sem
	## migração: o arquivo antigo já descrevia o mundo certo.
	func from_dict(data: Dictionary) -> void:
		slots.clear()
		for slot_data: Variant in data.get("slots", []):
			var slot := Slot.new()
			slot.from_dict(slot_data as Dictionary)
			slots.append(slot)
		capacity = int(data.get("capacity", InventoryState.CAPACITY_PADRAO))
		dinheiro = int(data.get("dinheiro", InventoryState.DINHEIRO_PADRAO))
		slot_na_mao = int(data.get("slot_na_mao", InventoryState.SLOT_NA_MAO_PADRAO))
		garante_tamanho()


var _players: Dictionary = {}

## Inventário do jogador, criado com os defaults na primeira vez que é pedido.
func get_player(player_id: int) -> PlayerInventory:
	if not _players.has(player_id):
		_players[player_id] = PlayerInventory.new()
	return _players[player_id] as PlayerInventory

## Jogadores com inventário, em ordem crescente — a ordem não pode depender
## de quem chegou primeiro.
func player_ids() -> Array[int]:
	var ids: Array[int] = []
	for player_id: int in _players.keys():
		ids.append(player_id)
	ids.sort()
	return ids

## Snapshot para o save. A chave vira String porque o destino é JSON.
func to_dict() -> Dictionary:
	var data := {}
	for player_id in player_ids():
		data[str(player_id)] = get_player(player_id).to_dict()
	return data

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai
## no default — é assim que campo novo entra sem migração.
func from_dict(data: Dictionary) -> void:
	_players.clear()
	for chave: Variant in data.keys():
		var inv := PlayerInventory.new()
		inv.from_dict(data[chave] as Dictionary)
		_players[int(str(chave))] = inv
