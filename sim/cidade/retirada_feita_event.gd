class_name RetiradaFeitaEvent
extends ItemGrantedEvent

## O jogador buscou o que era dele e pagou a taxa.
##
## É um `ItemGrantedEvent`: o inventário reage adicionando `item_id` × `qtd` sem
## saber que existe cidade — o mesmo caminho da colheita e do caixote. Mochila
## cheia gera `ItemLostEvent`, não rejeição.
##
## A taxa já foi cobrada quando este evento sai: ela é a própria `RetirarAction`,
## que é uma `AddMoneyAction`. `taxa_paga` está aqui só para a tela poder contar
## a história inteira numa linha.

var estabelecimento: String = ""
var taxa_paga: int = 0
