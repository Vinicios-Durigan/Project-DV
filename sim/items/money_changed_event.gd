class_name MoneyChangedEvent
extends SimEvent

## O dinheiro do jogador mudou. Campos `de`/`para` porque descreve transição —
## a HUD anima o número sem consultar ninguém.

var player_id: int = 0
var de: int = 0
var para: int = 0
var delta: int = 0
