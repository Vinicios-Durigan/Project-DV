class_name DinheiroConcedidoEvent
extends SimEvent

## Uma mecânica pagou o jogador. O irmão do `ItemGrantedEvent`: quem concede
## emite, e o `InventorySystem` — dono da carteira — reage somando.
##
## Existe porque até a wave 12 só havia dois caminhos para o dinheiro:
## `AddMoneyAction`, que é intenção vinda de `game/`, e `ItemsSoldEvent`, que é
## a venda do caixote ao dormir. Um contrato cumprido não é nenhum dos dois — é
## fato consumado dentro da sim. Sem este canal, o `SistemaContratos` teria de
## conhecer o `InventoryState`, e state alheio é proibido.
##
## É **só crédito**: valor zero ou negativo não faz nada. Cobrar continua sendo
## `AddMoneyAction` com valor negativo, que pode ser **recusada** por saldo — e
## recusa precisa de ação. Evento é fato consumado; ele não pede licença.
##
## `motivo` é id de máquina (o id do estabelecimento, da mecânica, do prêmio) —
## quem fala com o jogador é `game/`.

var player_id: int = 0
var valor: int = 0
var motivo: String = ""
