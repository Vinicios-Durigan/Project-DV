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
##
## O mundo também é o dono do snapshot: cada state registrado por chave vira um
## bloco do save, e `restore()` reconstrói. State que não está registrado não
## existe para o save — registrar é o que faz o campo sobreviver a fechar o jogo.

## Versão do formato do save. Todo snapshot sai carimbado; o load usa o carimbo
## para decidir quais migrações aplicar. Só sobe quando o formato mudar de um
## jeito que `from_dict` sozinho não resolve.
const SAVE_VERSION: int = 1

## Chave do carimbo dentro do snapshot. Reservada: nenhum state pode usá-la.
const CHAVE_VERSAO: String = "save_version"

var _systems: Array[SimSystem] = []
var _states: Dictionary = {}
var _state_keys: Array[String] = []

## Registra um sistema no fim da ordem fixa.
func register_system(system: SimSystem) -> void:
	_systems.append(system)

## Sistemas registrados, na ordem em que rodam.
func get_systems() -> Array[SimSystem]:
	return _systems.duplicate()

## Registra um state no save sob uma chave. O state precisa ter `to_dict()` e
## `from_dict(Dictionary)` — é o único contrato que o snapshot exige.
##
## Registrar a mesma chave de novo troca o state e mantém a posição na ordem.
func register_state(key: String, state: RefCounted) -> void:
	if key.is_empty() or key == CHAVE_VERSAO or state == null:
		return
	if not _states.has(key):
		_state_keys.append(key)
	_states[key] = state

## State registrado na chave, ou `null` se ninguém registrou.
func get_state(key: String) -> RefCounted:
	return _states.get(key, null) as RefCounted

## Chaves dos states, na ordem de registro — é a ordem dos blocos no save.
func state_keys() -> Array[String]:
	return _state_keys.duplicate()

## A sim inteira como dicionário JSON-puro, carimbada com a versão do formato.
func snapshot() -> Dictionary:
	var data := {CHAVE_VERSAO: SAVE_VERSION}
	for key in _state_keys:
		var state := _states[key] as RefCounted
		var bloco: Dictionary = state.call("to_dict")
		data[key] = bloco
	return data

## Reconstrói a sim a partir de um snapshot.
##
## Todo state registrado é carregado, inclusive os que não estão no dicionário:
## bloco ausente carrega `{}` e cai nos defaults, então o mundo nunca fica com
## resto do jogo anterior. Bloco de chave desconhecida é ignorado — save de uma
## versão com sistema a mais não derruba o load.
func restore(data: Dictionary) -> void:
	for key in _state_keys:
		var state := _states[key] as RefCounted
		var bruto: Variant = data.get(key, {})
		# bloco que não é dicionário é lixo de save corrompido: cai no default
		var bloco: Dictionary = bruto if bruto is Dictionary else {}
		state.call("from_dict", bloco)

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
