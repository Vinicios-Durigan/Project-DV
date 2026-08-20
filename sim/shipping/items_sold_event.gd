class_name ItemsSoldEvent
extends SimEvent

## O caixote vendeu tudo o que estava dentro, na virada do dia. É o primeiro
## passo da sequência de dormir (GAMEPLAY §3), antes de as culturas crescerem.
##
## Evento gordo: já vem com a tela pronta. `game/` monta o resumo do dia com as
## linhas daqui e a data do `DayEndedEvent` — nenhuma conta e nenhuma consulta
## ao catálogo do lado visual.
##
## Quem soma o dinheiro é o InventorySystem, reagindo a este evento: o caixote
## não conhece a carteira de ninguém.


## Uma linha do resumo: "qtd × preço = subtotal".
class Linha extends RefCounted:
	var item_id: String = ""
	var qtd: int = 0
	var preco_unitario: int = 0
	var subtotal: int = 0

	func _init(item_id_: String = "", qtd_: int = 0, preco_unitario_: int = 0) -> void:
		item_id = item_id_
		qtd = qtd_
		preco_unitario = preco_unitario_
		subtotal = qtd_ * preco_unitario_


## Quem dormiu — é dele o dinheiro.
var player_id: int = 0
## Uma linha por item, em ordem alfabética. A ordem é contrato do resumo.
var linhas: Array[Linha] = []
## Soma dos subtotais: o dinheiro do dia.
var total: int = 0
## Unidades que saíram do caixote.
var total_itens: int = 0
