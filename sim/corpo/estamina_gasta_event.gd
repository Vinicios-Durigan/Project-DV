class_name EstaminaGastaEvent
extends SimEvent

## Um trabalho cobrou o corpo. Sai a cada desconto, e não a cada minuto: quem
## anda de um canteiro a outro não cansa (o relógio já cobra o deslocamento).
##
## Evento gordo: leva a transição inteira (`de` → `para`) e o teto do corpo, para
## a barra da tela desenhar a fração sem abrir o state de ninguém. E leva o
## `trabalho`, para o diário do playground contar **o que** cansou — "−4" sozinho
## não diz se o jogador arou ou derrubou uma árvore.

var player_id: int = 0
## O tipo de trabalho, do vocabulário do `SistemaCorpo` (`arar`, `regar`, …).
## Não é a ferramenta: o evento de trabalho não diz qual estava na mão, e
## ferramenta melhor ainda não cansa menos.
var trabalho: String = ""
## Quanto o trabalho custou. Pode ser maior que `de` — o último golpe acontece
## inteiro, e a estamina é que para em zero.
var custo: int = 0
var de: int = 0
var para: int = 0
var maxima: int = 0
