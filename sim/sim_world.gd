class_name SimWorld
extends RefCounted

## Tick central da simulação: percorre os sistemas em ordem fixa e concatena os
## eventos na sequência em que aconteceram — `game/` depende dessa ordem para
## animar certo.
##
## A ordem de registro é regra de jogo (ela implementa a validação em cadeia e a
## sequência de dormir: validar → vender → crescer → virar o dia). Mudar a ordem
## muda o jogo.
##
## Todo evento emitido passa pela fila de redistribuição antes de sair para
## `game/`: é ali que um sistema fica sabendo do mundo alheio sem ler o state
## de ninguém.

var _systems: Array[SimSystem] = []

## Registra um sistema no fim da ordem fixa.
func register_system(system: SimSystem) -> void:
	_systems.append(system)

## Sistemas registrados, na ordem em que rodam.
func get_systems() -> Array[SimSystem]:
	return _systems.duplicate()

## Avança `ticks` minutos de jogo. Para cada tick, todos os sistemas rodam na
## ordem fixa e a fila do tick esvazia antes do tick seguinte começar.
func advance(ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _i in ticks:
		var pending: Array[SimEvent] = []
		for system in _systems:
			pending.append_array(system.tick())
		events.append_array(_drain(pending))
	return events

## Oferece a ação a todos os sistemas, na mesma ordem fixa do tick.
func handle(action: SimAction) -> Array[SimEvent]:
	var pending: Array[SimEvent] = []
	for system in _systems:
		pending.append_array(system.handle(action))
	return _drain(pending)

## Fila de redistribuição: cada evento é oferecido a todos os sistemas por
## `react()` na ordem fixa; o que a reação gerar volta para o fim da fila.
## Processa até esvaziar — determinístico. A saída sai na ordem em que os
## eventos aconteceram: causa antes de consequência.
func _drain(pending: Array[SimEvent]) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	var queue: Array[SimEvent] = pending.duplicate()
	while not queue.is_empty():
		var event: SimEvent = queue.pop_front()
		events.append(event)
		for system in _systems:
			queue.append_array(system.react(event))
	return events
