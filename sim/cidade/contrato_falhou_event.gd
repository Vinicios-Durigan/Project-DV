class_name ContratoFalhouEvent
extends SimEvent

## A encomenda saiu da mesa sem virar entrega. Três caminhos levam aqui, e o
## `motivo` os distingue porque só um deles dói:
##
## - `recusado` — o jogador disse não. Grátis (PRINCIPIOS §6);
## - `expirado` — a oferta ficou na mesa e o prazo de responder passou. Também
##   grátis: ausência não pune;
## - `estourado` — havia compromisso aceito e o prazo venceu. **Este** custa
##   constância.
##
## Como o `ContratoCumpridoEvent`, ele não diz quanto custa: quem legisla sobre
## relação é o `SistemaCidade`, que reage a este evento.
##
## `player_id` é 0 quando foi o tempo que encerrou (`expirado`, `estourado`) —
## ninguém agiu, como no `BeneficiamentoProntoEvent`.

const MOTIVO_RECUSADO: String = "recusado"
const MOTIVO_EXPIRADO: String = "expirado"
const MOTIVO_ESTOURADO: String = "estourado"

var player_id: int = 0
var estabelecimento: String = ""
var item_id: String = ""
var qtd: int = 0
var motivo: String = ""
