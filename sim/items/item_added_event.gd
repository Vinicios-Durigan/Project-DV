class_name ItemAddedEvent
extends SimEvent

## Item entrou no inventário. `total_apos` viaja junto para `game/` nunca
## precisar ler o state para atualizar a hotbar.

var player_id: int = 0
var item_id: String = ""
## Quanto entrou de fato (pode ser menos que o pedido, se faltou espaço).
var qtd: int = 0
var total_apos: int = 0
