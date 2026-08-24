class_name VantagemEscolhidaEvent
extends SimEvent

## Uma vantagem foi comprada, e a escolha é para sempre.
##
## Este evento é o **único** caminho pelo qual um efeito chega ao seu dono. O
## `SistemaCorpo` escuta e guarda quanto Mãos leves e Costas largas valem para
## ele; o `FarmSystem` escuta e guarda Rega funda e a cultura especializada.
## Nenhum dos dois lê o state dos ofícios — mesmo padrão de contratos↔cidade, e é
## o que mantém a regra "ninguém lê state alheio" de pé com dois sistemas
## dependendo de um terceiro.
##
## Por isso o evento é gordo: quem cobra precisa do `nivel` novo (o efeito é por
## nível) e da `cultura` (a especialização é de uma só), e não pode ir perguntar.
##
## Sai **depois** de o ponto já ter sido cobrado: é fato consumado, não pedido.

var player_id: int = 0
## O id da vantagem, do tabuleiro do `SistemaOficios` (`maos_leves`, …).
var vantagem_id: String = ""
## O ofício que pagou. Ponto é preso no ofício que o ganhou.
var oficio: String = ""
## O nível **novo** desta vantagem — 1 na primeira compra, 2 na segunda. É o
## número que o dono do efeito guarda.
var nivel: int = 0
## Quantos pontos esta compra custou.
var custo: int = 0
## Quantos pontos do ofício sobraram.
var pontos_restantes: int = 0
## A cultura escolhida, quando a vantagem é a Colheita especializada. Vazia nas
## outras — o campo existe para o dono do efeito não precisar perguntar.
var cultura: String = ""
