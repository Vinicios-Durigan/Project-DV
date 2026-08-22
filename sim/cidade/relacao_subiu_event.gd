class_name RelacaoSubiuEvent
extends SimEvent

## Mais um dia com entrega neste estabelecimento.
##
## Sai uma vez por dia, na primeira entrega — duas entregas no mesmo dia contam
## uma. Relação sobe por **constância**, não por volume nem por dinheiro, e não
## zera quando o jogador some (PRINCIPIOS §6).
##
## `cota` é a cota já vigente depois deste dia. Ela pode vir igual à de ontem:
## a relação subiu, mas o degrau ainda não foi cruzado.

var player_id: int = 0
var estabelecimento: String = ""
## Quantos dias diferentes já tiveram entrega aqui.
var dias: int = 0
## A cota do jogador depois deste dia, já limitada pela capacidade do prédio.
var cota: int = 0
