class_name ComeuEvent
extends SimEvent

## O jogador comeu, e o corpo recebeu. Sai uma vez por refeição aceita — refeição
## recusada não chega aqui, ela sai como `ActionRejectedEvent`.
##
## Evento gordo, como o `EstaminaGastaEvent`: leva a transição inteira (`de` →
## `para`), o teto do corpo e **qual** refeição do dia foi esta, para a tela
## desenhar a barra e explicar a saciedade sem abrir state nenhum.

var player_id: int = 0
## O que foi comido, para a tela dizer o nome — o item já saiu da mochila pelo
## `ItemRemovedEvent` que veio antes, no mesmo lote.
var item_id: String = ""
## **Quanto a refeição valia**, já com o fator da saciedade aplicado sobre o
## número do `.tres`. Pode ser maior que `para - de`: quem come com a barra quase
## cheia desperdiça o resto, e é isso que faz comer cedo demais ser desperdício.
##
## Quanto entrou de fato é `para - de`. Os dois números existem de propósito: um
## explica a comida, o outro explica a barra.
var restaurou: int = 0
var de: int = 0
var para: int = 0
var maxima: int = 0
## Qual refeição do dia foi esta — a primeira é 1. É o número que a tela usa para
## dizer que a próxima vale metade.
var refeicao: int = 0
