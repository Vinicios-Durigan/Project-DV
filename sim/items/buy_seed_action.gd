class_name BuySeedAction
extends SimAction

## Compra `qtd` sementes da cultura na aba de compra do painel do caixote.
##
## Não é uma `RemoveItemAction` nem uma `AddMoneyAction`: o preço mora no
## `CropDef` e só o InventorySystem conhece o saldo, então ele resolve a compra
## inteira — valida o dinheiro, debita e entrega a semente. O caixote não
## participa; a aba é só UI.

var crop_id: String = ""
var qtd: int = 1
