class_name MoverSlotAction
extends SimAction

## Move o conteúdo de um slot da mochila para outro. É o arrastar, e é a única
## forma de o jogador escolher **onde** um item fica.
##
## Três resultados, todos resolvidos pelo `InventorySystem`:
##
## - destino vazio → o item muda de endereço;
## - destino com item diferente → os dois **trocam** de lugar;
## - destino com o mesmo item → empilha até o `stack_max`, e o que não couber
##   fica onde estava.
##
## A mão não segue o item. Ela é um índice: quem move o que estava na mão
## continua com a mão no mesmo slot, agora com outra coisa. É como toda hotbar
## do gênero se comporta, e é o que torna a tecla 1 previsível.

## Índices na mochila, de 0 a `capacity - 1`. Fora disso é recusa.
var de: int = 0
var para: int = 0
