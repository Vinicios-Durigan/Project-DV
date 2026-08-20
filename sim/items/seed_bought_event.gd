class_name SeedBoughtEvent
extends SimEvent

## O jogador comprou semente. É a causa: o `MoneyChangedEvent` e o
## `ItemAddedEvent` que vêm logo atrás são a consequência.
##
## Evento gordo: o recibo já vem pronto (preço unitário e custo do lote), para
## `game/` não multiplicar nada nem abrir o catálogo.

var player_id: int = 0
var crop_id: String = ""
## Id do item de semente, já resolvido pela convenção do `CropDef`.
var item_id: String = ""
var qtd: int = 0
var preco_unitario: int = 0
var custo_total: int = 0
