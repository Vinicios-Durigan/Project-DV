class_name ContratoOferecidoEvent
extends SimEvent

## Um dono deixou uma encomenda na mesa, na virada do dia.
##
## Não tem `player_id`: ninguém agiu, foi a manhã — mesma escolha do
## `BeneficiamentoProntoEvent`.
##
## Evento gordo: o pedido inteiro viaja, incluindo o pagamento já calculado e o
## prazo para responder, para a tela montar a oferta sem consultar `.tres` nem
## state de ninguém.

var estabelecimento: String = ""
var item_id: String = ""
var qtd: int = 0
## O total prometido, já com o multiplicador do contrato aplicado.
var pagamento: int = 0
## Minuto do relógio monotônico em que a oferta sai da mesa sozinha.
var minuto_limite: int = 0
