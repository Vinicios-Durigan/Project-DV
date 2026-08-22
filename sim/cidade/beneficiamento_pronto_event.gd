class_name BeneficiamentoProntoEvent
extends SimEvent

## O lote ficou pronto e está esperando ser buscado.
##
## Não tem `player_id`: ninguém agiu para isso acontecer — foi o relógio. É o
## mesmo motivo pelo qual o `EstadoCidade` não é indexado por jogador, como o
## caixote do `ShippingState` não é.
##
## Ficar pronto **não** libera a cota: o produto ocupa o estabelecimento até a
## retirada. Buscar custa o dia, e é de propósito (PRINCIPIOS §9).

var estabelecimento: String = ""
var item_id: String = ""
var qtd: int = 0
