class_name JogadorViajouEvent
extends SimEvent

## O jogador trocou de local. `de` e `para` são constantes de `EstadoLocais`.
##
## Sem campo de hora: como todo evento, a hora é carimbada pelo EventLogger e
## pelo feed usando o relógio da sim.

var player_id: int = 0
var de: String = ""
var para: String = ""
