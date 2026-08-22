class_name EntregaAceitaEvent
extends SimEvent

## O estabelecimento aceitou o lote e começou a trabalhar.
##
## Evento gordo: as duas pontas da receita viajam juntas, porque quem escuta
## quer mostrar "6 trigo → 3 farinha às 14:00" sem consultar o `.tres` nem o
## state de ninguém.
##
## `taxa` é o preço **combinado agora** e cobrado na retirada. Ele viaja no
## evento e na encomenda: rebalancear o `.tres` amanhã não muda o que foi
## acertado hoje.

var player_id: int = 0
var estabelecimento: String = ""
var item_entrada: String = ""
var qtd_entrada: int = 0
var item_saida: String = ""
var qtd_saida: int = 0
var taxa: int = 0
## Minuto do relógio monotônico (`dia × 1440 + minuto`) em que fica pronto.
var minuto_conclusao: int = 0
