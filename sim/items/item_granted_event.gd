class_name ItemGrantedEvent
extends SimEvent

## Uma mecânica qualquer concedeu item ao jogador.
##
## É o caminho genérico de "isto virou item na mochila": quem concede estende
## esta classe (`CropHarvestedEvent`, e amanhã `FishCaughtEvent`, presente de
## NPC, recompensa) e o InventorySystem reage adicionando — sem conhecer a
## mecânica de origem. Mecânica nova = arquivo novo, zero edição no inventário.
##
## Conceder não é impossibilidade: mochila cheia gera `ItemLostEvent`, não
## rejeição.

var player_id: int = 0
var item_id: String = ""
var qtd: int = 0
