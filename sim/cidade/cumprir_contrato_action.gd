class_name CumprirContratoAction
extends RemoveItemAction

## Entrega o que o contrato pedia, no prédio do dono.
##
## É uma `RemoveItemAction` pelo mesmo motivo da `EntregarAction`: cumprir **é**
## gastar o item da mochila, e o `InventorySystem` — antes dos contratos na
## ordem fixa — consome `item_id` (ou rejeita por falta) antes de alguém olhar
## o prazo.
##
## Por isso existe `SistemaContratos.pode_cumprir()`: despachar isto sem
## contrato aceito, com o item errado ou com a conta errada custaria a
## mercadoria. `game/` pergunta antes (receita 2, §4).
##
## Não passa pelo caixote de propósito. O contrato é o degrau da **entrega
## direta** (PRINCIPIOS §3): cumprir dormindo sairia de graça em relógio e
## mataria a ficção do dono que espera você aparecer.

## Id do estabelecimento, como em `data/cidade/*.tres`.
var estabelecimento: String = ""
