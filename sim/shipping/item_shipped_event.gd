class_name ItemShippedEvent
extends SimEvent

## O item entrou no caixote de venda. Ainda não virou dinheiro: a venda
## concretiza ao dormir.
##
## `total_apos` viaja junto para o painel do caixote nunca precisar ler o state.

var player_id: int = 0
var item_id: String = ""
var qtd: int = 0
## Quanto do item está no caixote depois deste depósito.
var total_apos: int = 0
