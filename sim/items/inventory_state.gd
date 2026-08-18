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


## Um stack: item + quantidade.
class Slot extends RefCounted:
	var item_id: String = ""
	var qtd: int = 0

	func _init(item_id_: String = "", qtd_: int = 0) -> void:
		item_id = item_id_
		qtd = qtd_

	func to_dict() -> Dictionary:
		return {"item_id": item_id, "qtd": qtd}

	func from_dict(data: Dictionary) -> void:
		item_id = String(data.get("item_id", ""))
		qtd = int(data.get("qtd", 0))


## A mochila de um jogador.
class PlayerInventory extends RefCounted:
	var slots: Array[Slot] = []
	var capacity: int = InventoryState.CAPACITY_PADRAO
	var dinheiro: int = InventoryState.DINHEIRO_PADRAO

	## Quanto o jogador tem do item, somando todos os stacks.
	func count(item_id: String) -> int:
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
		}

	func from_dict(data: Dictionary) -> void:
		slots.clear()
		for slot_data: Variant in data.get("slots", []):
			var slot := Slot.new()
			slot.from_dict(slot_data as Dictionary)
			slots.append(slot)
		capacity = int(data.get("capacity", InventoryState.CAPACITY_PADRAO))
		dinheiro = int(data.get("dinheiro", InventoryState.DINHEIRO_PADRAO))


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
