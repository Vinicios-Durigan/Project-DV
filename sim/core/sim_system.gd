class_name SimSystem
extends RefCounted

## Contrato de um sistema da simulação. Cada sistema é dono de um state próprio
## e nunca lê o state de outro: pede por ação ou reage a evento.
##
## Os dois pontos de entrada devolvem `[]` por default — sistema que não
## reconhece a ação simplesmente não emite nada.

## Avança o sistema em 1 tick (1 minuto de jogo).
func tick() -> Array[SimEvent]:
	return []

## Recebe uma ação oferecida pelo SimWorld a todos os sistemas.
func handle(_action: SimAction) -> Array[SimEvent]:
	return []

## Reage a um evento já emitido (por este ou por outro sistema). É o único
## caminho para um sistema saber do mundo alheio sem ler state dos outros.
## O que sair daqui volta para a fila do SimWorld.
func react(_event: SimEvent) -> Array[SimEvent]:
	return []
