class_name ViajarAction
extends SimAction

## O jogador quer estar em outro local.
##
## Quem despacha é `game/`, no momento em que o quadrado do jogador cruza a
## fronteira entre os terrenos — a caminhada em pixel é apresentação; a sim só
## fica sabendo da troca de lugar. O custo da viagem é o tempo de relógio que
## passou andando, então esta ação não cobra nada: o preço já foi pago no
## caminho.

## Para onde: uma das constantes de `EstadoLocais` (`FAZENDA`, `CIDADE`).
var destino: String = ""
