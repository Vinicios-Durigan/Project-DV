class_name ComerAction
extends RemoveItemAction

## Come um item da mochila. O corpo devolve estamina, com o desconto da
## saciedade do dia.
##
## É uma `RemoveItemAction` porque comer **é** gastar o item: o
## `InventorySystem`, antes do corpo na ordem fixa, consome `item_id` (ou rejeita
## a ação por falta) antes de o `SistemaCorpo` olhar qualquer coisa. Mesmo truque
## de `EntregarAction` e `PlantCropAction`.
##
## É por isso que existe `SistemaCorpo.pode_comer()`: esta ação cobra antes de o
## corpo validar, e despachá-la com a barra cheia queimaria um pão de 260g em
## silêncio. `game/` pergunta primeiro (receita 2, §4) — item sumindo sem aviso é
## o pior tipo de bug.
##
## Não leva campo nenhum além dos herdados: o que a comida vale é do `ItemDef`, e
## quanto ela vale **agora** é do sistema. Uma ação que carregasse o número seria
## `game/` decidindo regra.
