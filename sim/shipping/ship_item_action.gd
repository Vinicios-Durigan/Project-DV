class_name ShipItemAction
extends RemoveItemAction

## Deposita o item no caixote de venda.
##
## É uma `RemoveItemAction` porque depositar **é** gastar o item da mochila: o
## InventorySystem, primeiro da ordem fixa, consome `item_id` (ou rejeita a ação
## por falta) antes do ShippingSystem encostar no caixote. Validação em cadeia,
## sem ninguém desfazer nada.
##
## A venda só concretiza ao dormir — até lá dá para retirar de volta com uma
## `WithdrawItemAction`.
