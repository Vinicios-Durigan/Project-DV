class_name RegadorEnchidoEvent
extends SimEvent

## O regador voltou cheio do poço.
##
## Evento gordo: `de` e `para` viajam juntos porque quem escuta quer mostrar
## "3 → 15" sem consultar o `.tres` nem o state de ninguém. `capacidade` vem
## junto pelo mesmo motivo — o medidor da tela desenha "15/15" com o que chegou
## aqui, e não precisa saber que existe `ItemDef`.
##
## É o par do `PlotWateredEvent`: um diz que uma regada saiu, o outro diz que o
## regador voltou a ficar cheio. Entre os dois, a tela sabe o número inteiro sem
## nunca ler o inventário.

var player_id: int = 0
## O que foi enchido, como em `data/items/*.tres`.
var item_id: String = ""
var de: int = 0
var para: int = 0
var capacidade: int = 0
## O tile de onde a água saiu — o poço tem endereço, e o evento o carrega.
var x: int = 0
var y: int = 0
