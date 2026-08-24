class_name EscolherVantagemAction
extends SimAction

## Gasta ponto de ofício numa vantagem do tabuleiro. É a única ação do
## `SistemaOficios` — trabalho entra por evento consumado, como no corpo.
##
## A escolha é permanente: não existe ação de desfazer, e é isso que faz o ponto
## pesar na hora de gastar (PRINCIPIOS §7). Respec pago em produção, se um dia a
## permanência doer demais jogando, entra por uma ação nova sem quebrar esta.
##
## Não leva custo nem ofício: quem sabe quanto uma vantagem cobra e de qual bolso
## é o sistema. Uma ação que carregasse o preço seria `game/` decidindo regra.
##
## Como toda compra irreversível, `game/` pergunta antes: `pode_comprar()` e
## `recusa_de()` respondem sem gastar nada.

## O id da vantagem no tabuleiro (`maos_leves`, `costas_largas`, …).
var vantagem_id: String = ""
## Só para a Colheita especializada: qual cultura ganha o +1. Ignorado pelas
## outras vantagens, obrigatório nela — e conferido contra o catálogo, porque uma
## escolha permanente num id digitado errado queimaria dois pontos para sempre.
var cultura: String = ""
