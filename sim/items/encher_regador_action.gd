class_name EncherRegadorAction
extends SimAction

## Encher o que está na mão no poço.
##
## Ação como qualquer outra, e não um gesto de tela: ela passa pela fila
## inteira, pode ser recusada e aparece no diário de eventos. "Encostar no poço
## enche sozinho" pareceria conveniente e tiraria a única coisa que a água
## acrescenta ao jogo — a **ida** até lá.
##
## Quem monta é o `ResolvedorUso`, e só em tile de água: o jogador não tem um
## botão "encher", ele usa o regador e o contexto decide (wave 11.2).
##
## `x`/`y` são o tile do poço. Eles viajam na ação porque quem valida o destino
## é a sim, e não a tela — mesmo desenho do `TillPlotAction`.

var x: int = 0
var y: int = 0
