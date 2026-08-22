class_name ContratoAceitoEvent
extends SimEvent

## O jogador topou. A partir daqui o prazo corre e falhar custa.
##
## `minuto_limite` foi reescrito no aceite: era o prazo para responder, agora é
## o prazo para cumprir. É este número que a contagem regressiva da tela mostra.

var player_id: int = 0
var estabelecimento: String = ""
var item_id: String = ""
var qtd: int = 0
var pagamento: int = 0
## Minuto do relógio monotônico em que o compromisso vence.
var minuto_limite: int = 0
