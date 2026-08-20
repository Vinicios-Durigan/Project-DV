class_name WithdrawItemAction
extends SimAction

## Tira o item do caixote de volta para a mochila.
##
## Aqui quem valida é o ShippingSystem: só ele sabe o que está no caixote. O
## item volta pela reação ao `ItemWithdrawnEvent`, não por esta ação — a mochila
## não conhece o caixote.

var item_id: String = ""
var qtd: int = 1
