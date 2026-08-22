class_name RetirarAction
extends AddMoneyAction

## Busca o que ficou pronto no estabelecimento, pagando a taxa combinada.
##
## É uma `AddMoneyAction` com `valor` negativo porque quem é dono do dinheiro é
## o `InventorySystem`: ele cobra e, se o saldo não der, rejeita a ação antes de
## a cidade entregar nada. A recusa por `dinheiro_insuficiente` sai de quem sabe
## responder por ela, sem a cidade nunca ler a carteira de ninguém.
##
## O `valor` não é inventado por `game/`: sai de
## `SistemaCidade.taxa_a_pagar()`. A cidade confere na chegada e recusa com
## `taxa_incorreta` se o número não bater — painel inventando preço faz barulho,
## não passa.
##
## Leva **tudo** o que está pronto. Retirada parcial só criaria uma decisão que
## ninguém quer tomar: o produto ocupa cota até sair, então metade é sempre
## pior que tudo.

## Id do estabelecimento, como em `data/cidade/*.tres`.
var estabelecimento: String = ""
