extends GutTest

## Reação a evento e validação em cadeia: o contrato que o resto da sim usa.

class SistemaReativo extends SimSystem:
	var eventos_recebidos: Array[SimEvent] = []

	func react(event: SimEvent) -> Array[SimEvent]:
		eventos_recebidos.append(event)
		var out: Array[SimEvent] = []
		out.append(SimEvent.new())
		return out


func test_react_default_nao_emite_nada() -> void:
	assert_eq(SimSystem.new().react(SimEvent.new()), [], "sistema base não reage a nada")

func test_react_pode_ser_sobrescrito() -> void:
	var system: SimSystem = SistemaReativo.new()
	var out := system.react(SimEvent.new())
	assert_eq(out.size(), 1, "reação sobrescrita é chamada via SimSystem")
	assert_eq((system as SistemaReativo).eventos_recebidos.size(), 1, "o sistema recebeu o evento")

func test_acao_nasce_valida() -> void:
	assert_false(SimAction.new().rejeitada, "ação nasce sem rejeição")

func test_acao_pode_ser_rejeitada() -> void:
	var action := SimAction.new()
	action.rejeitada = true
	assert_true(action.rejeitada, "quem detecta impossibilidade marca a flag")
