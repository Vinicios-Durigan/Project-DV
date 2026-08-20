class_name ItemWithdrawnEvent
extends ItemGrantedEvent

## O item saiu do caixote antes da venda — o jogador se arrependeu.
##
## É um `ItemGrantedEvent`: o inventário reage adicionando `item_id` × `qtd` sem
## saber que existe caixote. Mochila cheia gera `ItemLostEvent`, não rejeição.

var total_apos: int = 0
