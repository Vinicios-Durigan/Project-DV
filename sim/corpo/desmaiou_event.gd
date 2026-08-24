class_name DesmaiouEvent
extends SimEvent

## O corpo chegou a zero e o jogador caiu.
##
## Não é recusa: o trabalho que derrubou **aconteceu**, e é por isso que este
## evento vem depois do `EstaminaGastaEvent` que o zerou. Quem transforma o
## desmaio em fim de dia é o `TimeSystem`, reagindo daqui — o mesmo caminho das
## 02:00, com a mesma causa (`COLLAPSED`).
##
## `trabalho` viaja junto para a tela poder contar o que derrubou. É a única
## informação que o jogador realmente quer depois de acordar com metade.

var player_id: int = 0
var trabalho: String = ""
## O teto do corpo, para quem escuta saber com quanto ele vai acordar sem abrir
## o state.
var maxima: int = 0
