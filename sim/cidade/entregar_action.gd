class_name EntregarAction
extends RemoveItemAction

## Entrega matéria-prima num estabelecimento da cidade para beneficiar.
##
## É uma `RemoveItemAction` porque entregar **é** gastar o item da mochila: o
## `InventorySystem`, antes da cidade na ordem fixa, consome `item_id` (ou
## rejeita a ação por falta) antes de o `SistemaCidade` olhar a cota.
##
## É por isso que existe `SistemaCidade.pode_entregar()`: como o `PlantCropAction`
## (receita 2, §4), esta ação cobra antes de a cidade validar, e despachá-la num
## lote inválido custaria o trigo. `game/` pergunta primeiro.
##
## A **taxa não sai aqui** — ela é paga na retirada, por uma `RetirarAction`.
## Nenhum sistema existente precisou ser editado por causa disso: item e
## dinheiro continuam sendo os dois assuntos do inventário, um por ação.

## Id do estabelecimento, como em `data/cidade/*.tres`.
var estabelecimento: String = ""
