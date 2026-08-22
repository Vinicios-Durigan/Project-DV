class_name SlotMovidoEvent
extends SimEvent

## O jogador rearranjou a mochila: o conteúdo de um slot mudou de endereço.
##
## Evento gordo: vem com o que ficou em **cada uma** das duas pontas depois da
## mudança, para `game/` redesenhar os dois quadrados sem consultar o estado. É
## o mesmo evento para os três resultados possíveis — mover para vazio, trocar
## com item diferente e empilhar com item igual — porque para quem desenha os
## três são a mesma coisa: dois slots que mudaram.
##
## `empilhou` distingue o caso em que os itens se juntaram, para quem quiser
## animar diferente. Ninguém usa hoje; existe porque perguntar depois custaria
## um evento novo.

var player_id: int = 0
var de: int = 0
var para: int = 0
## O que ficou em cada ponta **depois** do movimento. Vazio = posição livre.
var item_de: String = ""
var item_para: String = ""
## Os dois eram o mesmo item e se juntaram num stack só.
var empilhou: bool = false
