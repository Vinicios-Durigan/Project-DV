class_name OficioSubiuEvent
extends SimEvent

## O ofício cruzou um limiar e o jogador ganhou ponto. É o fato que a tela
## comemora e o único momento em que o tabuleiro fica mais perto.
##
## Um evento por salto, não por nível: um golpe caro pode cruzar dois limiares de
## uma vez, e nesse caso `de` → `para` conta o salto inteiro e `pontos` traz os
## dois. Contar dois eventos para um golpe faria a tela piscar duas vezes por uma
## coisa só.

var player_id: int = 0
var oficio: String = ""
var de: int = 0
var para: int = 0
## Quantos pontos este salto creditou — normalmente 1, mais que isso quando o
## salto passou de dois limiares.
var pontos: int = 0
## Quantos pontos deste ofício estão disponíveis agora, já com o crédito.
var disponiveis: int = 0
