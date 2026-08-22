class_name ContratoCumpridoEvent
extends SimEvent

## O jogador entregou o que prometeu, dentro do prazo.
##
## Sai acompanhado de um `DinheiroConcedidoEvent` — o contrato informa o fato, o
## inventário é quem mexe na carteira.
##
## **Não diz quantos dias de constância isso vale.** Quem decide o preço da
## relação é o `SistemaCidade`, que reage a este evento; o `RelacaoSubiuEvent`
## que vem logo atrás é que traz o número novo. Sistema magro: o contrato não
## legisla sobre amizade.

var player_id: int = 0
var estabelecimento: String = ""
var item_id: String = ""
var qtd: int = 0
var pagamento: int = 0
