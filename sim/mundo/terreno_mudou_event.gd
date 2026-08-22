class_name TerrenoMudouEvent
extends SimEvent

## A cobertura de um tile mudou — e o `motivo` diz quem mudou.
##
## Um evento gordo em vez de cinco magros (`TerrenoLimpo`, `MatoNasceu`,
## `AradoFechou`, `MundoGerado`): é a mesma frase — *este tile era X e virou Y* —
## e cinco classes seriam vocabulário inventado para dizer o mesmo.
##
## Quem escuta filtra pelo que lhe interessa: o `FarmSystem` só olha para
## `para != livre` (o arado se perde quando o tile fecha), e o mapa do playground
## pisca em qualquer um deles.
##
## `player_id` é 0 quando ninguém agiu — a noite propagando mato, o mundo sendo
## gerado. Mesma escolha do `BeneficiamentoProntoEvent`.

## Foi o jogador, com a ferramenta na mão.
const POR_LIMPEZA: String = "limpeza"
## O mato pulou de um vizinho durante a noite.
const POR_INVASAO: String = "invasao"
## O arado ficou dias sem uso e o mato tomou o preparo de volta.
const POR_FECHAMENTO: String = "fechamento"
## A fazenda nasceu assim.
const POR_GERACAO: String = "geracao"

var player_id: int = 0
var x: int = 0
var y: int = 0
## A cobertura de antes e a de agora, sempre as duas — quem escuta precisa saber
## se o tile **abriu** ou **fechou**, e só o par responde isso.
var de: String = ""
var para: String = ""
var motivo: String = ""
