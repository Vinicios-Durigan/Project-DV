extends GutTest

## Tick central: ordem fixa e concatenação na sequência real.

class EventoMarcado extends SimEvent:
	var marca: String = ""


class SistemaMarcador extends SimSystem:
	var marca: String = ""
	var acoes_recebidas: int = 0

	func _init(marca_: String) -> void:
		marca = marca_

	func tick() -> Array[SimEvent]:
		var events: Array[SimEvent] = []
		events.append(_marcado("tick"))
		return events

	func handle(_action: SimAction) -> Array[SimEvent]:
		acoes_recebidas += 1
		var events: Array[SimEvent] = []
		events.append(_marcado("handle"))
		return events

	func _marcado(origem: String) -> EventoMarcado:
		var event := EventoMarcado.new()
		event.marca = "%s:%s" % [marca, origem]
		return event


class SistemaMudo extends SimSystem:
	var acoes_recebidas: int = 0

	func handle(_action: SimAction) -> Array[SimEvent]:
		acoes_recebidas += 1
		return []


func _marcas(events: Array[SimEvent]) -> Array[String]:
	var marcas: Array[String] = []
	for event in events:
		marcas.append((event as EventoMarcado).marca)
	return marcas


func test_mundo_vazio_nao_emite_nada() -> void:
	assert_eq(SimWorld.new().advance(5), [], "sem sistema registrado não há evento")

func test_sistemas_rodam_na_ordem_de_registro() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaMarcador.new("A"))
	world.register_system(SistemaMarcador.new("B"))
	assert_eq(_marcas(world.advance(1)), ["A:tick", "B:tick"], "ordem fixa é a de registro")

func test_ordem_de_registro_invertida_inverte_os_eventos() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaMarcador.new("B"))
	world.register_system(SistemaMarcador.new("A"))
	assert_eq(_marcas(world.advance(1)), ["B:tick", "A:tick"], "a ordem é regra de jogo")

func test_advance_concatena_tick_a_tick() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaMarcador.new("A"))
	world.register_system(SistemaMarcador.new("B"))
	var esperado := ["A:tick", "B:tick", "A:tick", "B:tick", "A:tick", "B:tick"]
	assert_eq(_marcas(world.advance(3)), esperado, "eventos saem na sequência em que aconteceram")

func test_advance_zero_nao_roda_nada() -> void:
	var world := SimWorld.new()
	var system := SistemaMarcador.new("A")
	world.register_system(system)
	assert_eq(world.advance(0), [], "advance(0) é no-op")

func test_handle_oferece_acao_a_todos_os_sistemas() -> void:
	var world := SimWorld.new()
	var falante := SistemaMarcador.new("A")
	var mudo := SistemaMudo.new()
	world.register_system(falante)
	world.register_system(mudo)

	var events := world.handle(SimAction.new())

	assert_eq(_marcas(events), ["A:handle"], "só quem reconhece a ação emite")
	assert_eq(falante.acoes_recebidas, 1, "sistema falante recebeu a ação")
	assert_eq(mudo.acoes_recebidas, 1, "sistema mudo também recebeu — só não emitiu")

func test_handle_respeita_a_ordem_fixa() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaMarcador.new("A"))
	world.register_system(SistemaMarcador.new("B"))
	assert_eq(_marcas(world.handle(SimAction.new())), ["A:handle", "B:handle"], "handle usa o mesmo laço do advance")

func test_get_systems_devolve_copia() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaMarcador.new("A"))
	var systems := world.get_systems()
	systems.clear()
	assert_eq(world.get_systems().size(), 1, "mexer na lista devolvida não desregistra sistema")
