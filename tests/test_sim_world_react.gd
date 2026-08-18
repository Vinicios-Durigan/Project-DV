extends GutTest

## Redistribuição de eventos: fila do SimWorld, ordem fixa e término garantido.

class EventoMarcado extends SimEvent:
	var marca: String = ""

	func _init(marca_: String = "") -> void:
		marca = marca_


class SistemaEmissor extends SimSystem:
	var marca: String = ""

	func _init(marca_: String) -> void:
		marca = marca_

	func tick() -> Array[SimEvent]:
		var out: Array[SimEvent] = []
		out.append(EventoMarcado.new(marca))
		return out

	func handle(_action: SimAction) -> Array[SimEvent]:
		var out: Array[SimEvent] = []
		out.append(EventoMarcado.new(marca))
		return out


## Reage a "raiz" com um eco, e ao próprio eco com um segundo — prova cascata
## que termina sozinha.
class SistemaEco extends SimSystem:
	var sufixo: String = ""

	func _init(sufixo_: String) -> void:
		sufixo = sufixo_

	func react(event: SimEvent) -> Array[SimEvent]:
		var out: Array[SimEvent] = []
		var marcado := event as EventoMarcado
		if marcado == null:
			return out
		if marcado.marca == "raiz":
			out.append(EventoMarcado.new("eco" + sufixo))
		elif marcado.marca == "eco" + sufixo:
			out.append(EventoMarcado.new("eco2" + sufixo))
		return out


class SistemaEspiao extends SimSystem:
	var vistos: Array[String] = []

	func react(event: SimEvent) -> Array[SimEvent]:
		var marcado := event as EventoMarcado
		if marcado != null:
			vistos.append(marcado.marca)
		return []


func _marcas(events: Array[SimEvent]) -> Array[String]:
	var marcas: Array[String] = []
	for event in events:
		marcas.append((event as EventoMarcado).marca)
	return marcas


func test_sem_reator_a_saida_e_a_da_wave_01() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaEmissor.new("raiz"))
	assert_eq(_marcas(world.advance(1)), ["raiz"], "sem react, nada muda")

func test_evento_emitido_e_oferecido_a_todos_os_sistemas() -> void:
	var world := SimWorld.new()
	var espiao := SistemaEspiao.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(espiao)
	world.advance(1)
	assert_eq(espiao.vistos, ["raiz"], "todo sistema recebe todo evento, inclusive o de outro")

func test_o_proprio_emissor_tambem_recebe_o_evento() -> void:
	var world := SimWorld.new()
	var espiao := SistemaEspiao.new()
	world.register_system(espiao)
	world.register_system(SistemaEmissor.new("raiz"))
	world.advance(1)
	assert_eq(espiao.vistos, ["raiz"], "a fila é do mundo, não do emissor")

func test_reacao_sai_depois_do_evento_que_a_causou() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(SistemaEco.new("A"))
	assert_eq(_marcas(world.advance(1)), ["raiz", "ecoA", "eco2A"], "saída preserva a ordem de acontecimento")

func test_cascata_esvazia_a_fila_e_para() -> void:
	var world := SimWorld.new()
	var espiao := SistemaEspiao.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(SistemaEco.new("A"))
	world.register_system(espiao)
	world.advance(1)
	assert_eq(espiao.vistos, ["raiz", "ecoA", "eco2A"], "reação de reação também volta para a fila")

func test_reatores_respeitam_a_ordem_fixa() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(SistemaEco.new("A"))
	world.register_system(SistemaEco.new("B"))
	var esperado := ["raiz", "ecoA", "ecoB", "eco2A", "eco2B"]
	assert_eq(_marcas(world.advance(1)), esperado, "a ordem de registro decide a ordem das reações")

func test_handle_tambem_passa_pela_fila() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(SistemaEco.new("A"))
	assert_eq(_marcas(world.handle(SimAction.new())), ["raiz", "ecoA", "eco2A"], "ação emite e a reação vem junto")

func test_ticks_nao_se_misturam() -> void:
	var world := SimWorld.new()
	world.register_system(SistemaEmissor.new("raiz"))
	world.register_system(SistemaEco.new("A"))
	var esperado := ["raiz", "ecoA", "eco2A", "raiz", "ecoA", "eco2A"]
	assert_eq(_marcas(world.advance(2)), esperado, "a fila de um tick esvazia antes do próximo")
