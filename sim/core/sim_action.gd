class_name SimAction
extends RefCounted

## Intenção que entra na simulação, no imperativo (WaterPlotAction, SellItemAction).
## Dados puros, sem método: quem interpreta é o sistema.
##
## `player_id` existe em toda ação desde o primeiro dia — hoje sempre 0, sem
## singleton "o jogador". É o que deixa co-op futuro ser problema de rede.

var player_id: int = 0

## Validação em cadeia: o sistema que detecta impossibilidade (sem semente, sem
## dinheiro) marca a flag e emite ActionRejectedEvent; os sistemas seguintes
## ignoram a ação. Ninguém desfaz nada — quem valida vem antes de quem executa.
var rejeitada: bool = false
