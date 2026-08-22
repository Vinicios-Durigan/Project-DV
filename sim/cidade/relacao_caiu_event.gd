class_name RelacaoCaiuEvent
extends SimEvent

## O jogador quebrou uma promessa: aceitou um contrato e deixou o prazo vencer.
##
## É o irmão do `RelacaoSubiuEvent`, e existe separado dele por honestidade de
## nome — "subiu" com número menor mentiria para quem lê o diário de eventos, e
## a wave 12 já publicou aquele evento com aquele significado. Renomear o que já
## existe é risco sem retorno (CLAUDE.md).
##
## **Só quebra de promessa chega aqui.** Recusar a oferta e deixá-la expirar são
## de graça: relação não pune ausência (PRINCIPIOS §6), do mesmo jeito que a
## planta não regada pausa em vez de morrer.
##
## `cota` é a cota já vigente depois da queda. Ela pode vir igual à de ontem: a
## relação caiu, mas o degrau ainda não foi perdido.

var player_id: int = 0
var estabelecimento: String = ""
## Quantos dias com entrega sobraram. Nunca abaixo de zero.
var dias: int = 0
## A cota do jogador depois da queda, já limitada pela capacidade do prédio.
var cota: int = 0
