extends GutTest

## Contrato de sistema: silêncio por default, override quando tem regra.

class SistemaFalante extends SimSystem:
	func tick() -> Array[SimEvent]:
		var events: Array[SimEvent] = []
		events.append(SimEvent.new())
		return events

	func handle(_action: SimAction) -> Array[SimEvent]:
		var events: Array[SimEvent] = []
		events.append(SimEvent.new())
		events.append(SimEvent.new())
		return events


func test_tick_default_nao_emite_nada() -> void:
	assert_eq(SimSystem.new().tick(), [], "sistema base não emite no tick")

func test_handle_default_nao_emite_nada() -> void:
	assert_eq(SimSystem.new().handle(SimAction.new()), [], "quem não reconhece a ação devolve []")

func test_override_de_tick_vale_pelo_tipo_base() -> void:
	var system: SimSystem = SistemaFalante.new()
	assert_eq(system.tick().size(), 1, "tick sobrescrito é chamado via SimSystem")

func test_override_de_handle_vale_pelo_tipo_base() -> void:
	var system: SimSystem = SistemaFalante.new()
	assert_eq(system.handle(SimAction.new()).size(), 2, "handle sobrescrito é chamado via SimSystem")
