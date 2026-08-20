class_name PlantCropAction
extends RemoveItemAction

## Planta a semente no tile.
##
## É uma `RemoveItemAction` porque plantar **é** gastar a semente: o
## InventorySystem, primeiro da ordem fixa, consome `item_id` (ou rejeita a
## ação por falta) antes do FarmSystem encostar no tile. Validação em cadeia,
## sem ninguém desfazer nada.
##
## Quem monta a ação preenche `item_id` com `CropDef.item_semente_id()` — o
## catálogo é leitura livre. Antes de despachar, `game/` pergunta
## `FarmSystem.pode_plantar()` para não cobrar semente por um tile inválido.

var crop_id: String = ""
var x: int = 0
var y: int = 0
