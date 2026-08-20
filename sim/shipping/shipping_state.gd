class_name ShippingState
extends RefCounted

## Estado do caixote de venda, dono exclusivo do ShippingSystem.
##
## O caixote é do mundo, não de um jogador: em co-op todo mundo deposita no
## mesmo caixote. Por isso não existe `player_id` aqui — quem depositou viaja
## na ação e no evento, não no state.
##
## Guarda `item_id` + quantidade: nenhum tipo concreto de conteúdo entra no
## state. Quanto cada item vale é o `ItemDef` no catálogo.
##
## Todo campo tem default e entra no snapshot do save (bloco `shipping`) por
## to_dict/from_dict.

var _itens: Dictionary = {}

## Quanto do item está esperando a venda.
func count(item_id: String) -> int:
	return int(_itens.get(item_id, 0))

## Ids depositados, em ordem alfabética.
##
## A ordem é contrato: as linhas do resumo do dia saem nela, e não podem
## depender de quem foi depositado primeiro nem de como o save voltou.
func item_ids() -> Array[String]:
	var out: Array[String] = []
	for item_id: String in _itens.keys():
		out.append(item_id)
	out.sort()
	return out

func is_empty() -> bool:
	return _itens.is_empty()

## Soma de todas as quantidades — unidades esperando a venda.
func total_itens() -> int:
	var total := 0
	for item_id: String in _itens.keys():
		total += int(_itens[item_id])
	return total

## Soma no que já está lá. Id vazio e quantidade não-positiva não viram
## depósito.
func add(item_id: String, qtd: int) -> void:
	if item_id.is_empty() or qtd <= 0:
		return
	_itens[item_id] = count(item_id) + qtd

## Tira do caixote e devolve quanto saiu de fato — o state não inventa item.
## Quem garante o "tudo ou nada" é o sistema, que valida antes. Entrada zerada
## some.
func remove(item_id: String, qtd: int) -> int:
	if qtd <= 0:
		return 0
	var saiu: int = mini(count(item_id), qtd)
	if saiu <= 0:
		return 0
	var restante := count(item_id) - saiu
	if restante > 0:
		_itens[item_id] = restante
	else:
		_itens.erase(item_id)
	return saiu

## Esvazia o caixote — é o que a venda ao dormir faz.
func clear() -> void:
	_itens.clear()

## Snapshot para o save, na ordem contratada.
func to_dict() -> Dictionary:
	var itens: Array[Dictionary] = []
	for item_id in item_ids():
		itens.append({"item_id": item_id, "qtd": count(item_id)})
	return {"itens": itens}

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai
## no default — é assim que campo novo entra sem migração. Entrada sem id ou
## sem quantidade é lixo e não volta.
func from_dict(data: Dictionary) -> void:
	_itens.clear()
	for entrada: Variant in data.get("itens", []):
		var dados := entrada as Dictionary
		add(String(dados.get("item_id", "")), int(dados.get("qtd", 0)))
