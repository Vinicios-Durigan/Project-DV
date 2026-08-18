class_name RemoveItemAction
extends SimAction

## Tira item do inventário do jogador. Rejeitada se ele não tem tudo o que foi
## pedido — não existe remoção parcial.

var item_id: String = ""
var qtd: int = 1
