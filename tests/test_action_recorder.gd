extends GutTest

## Gravação de ações: o que este teste protege é a promessa de bug report
## determinístico — a lista gravada tem tudo que a sim precisa para refazer a
## sessão na mesma ordem.

var _recorder: ActionRecorder
var _time: TimeState


func before_each() -> void:
	_time = TimeState.new()
	_recorder = ActionRecorder.new(_time)


func _acao_item(item_id: String, qtd: int) -> AddItemAction:
	var acao := AddItemAction.new()
	acao.item_id = item_id
	acao.qtd = qtd
	return acao


func test_comeca_vazio() -> void:
	assert_eq(_recorder.count(), 0, "sessão nova não gravou nada ainda")
	assert_eq(_recorder.get_entries().size(), 0, "sem entradas antes da primeira ação")

func test_grava_tipo_da_acao() -> void:
	_recorder.record(_acao_item("cenoura", 3))
	var entrada := _recorder.get_entries()[0]
	assert_eq(entrada["acao"], "AddItemAction", "o tipo da ação identifica o que aconteceu")

func test_grava_campos_por_reflection() -> void:
	_recorder.record(_acao_item("cenoura", 3))
	var campos: Dictionary = _recorder.get_entries()[0]["campos"]
	assert_eq(campos["item_id"], "cenoura", "campo próprio da ação entra sozinho")
	assert_eq(campos["qtd"], 3, "campo próprio da ação entra sozinho")

func test_grava_campos_herdados_da_base() -> void:
	var acao := _acao_item("cenoura", 1)
	acao.player_id = 7
	acao.rejeitada = true
	var campos: Dictionary = _recorder.record(acao)["campos"]
	assert_eq(campos["player_id"], 7, "player_id vem da base e é contexto de co-op")
	assert_true(campos["rejeitada"], "a flag de validação em cadeia faz parte do rastro")

func test_grava_acao_sem_campo_proprio() -> void:
	var campos: Dictionary = _recorder.record(SleepAction.new())["campos"]
	assert_eq(campos.keys().size(), 2, "SleepAction só tem os dois campos da base")

func test_grava_hora_de_jogo() -> void:
	_time.dia = 4
	_time.minuto = 615
	_time.estacao = "verao"
	var entrada: Dictionary = _recorder.record(SleepAction.new())
	assert_eq(entrada["dia"], 4, "a hora de jogo é o que torna o rastro reproduzível")
	assert_eq(entrada["minuto"], 615, "a hora de jogo é o que torna o rastro reproduzível")
	assert_eq(entrada["estacao"], "verao", "estação faz parte do relógio")

func test_hora_e_a_do_momento_da_acao() -> void:
	_time.dia = 1
	_recorder.record(SleepAction.new())
	_time.dia = 2
	_recorder.record(SleepAction.new())
	var entradas := _recorder.get_entries()
	assert_eq(entradas[0]["dia"], 1, "cada entrada carimba o relógio de quando ela entrou")
	assert_eq(entradas[1]["dia"], 2, "cada entrada carimba o relógio de quando ela entrou")

func test_grava_na_ordem_de_despacho() -> void:
	_recorder.record(_acao_item("a", 1))
	_recorder.record(_acao_item("b", 1))
	_recorder.record(_acao_item("c", 1))
	var ids: Array[String] = []
	for entrada in _recorder.get_entries():
		ids.append(entrada["campos"]["item_id"])
	assert_eq(ids, ["a", "b", "c"] as Array[String], "ordem é metade da reprodução")

func test_indice_sobe_a_cada_acao() -> void:
	assert_eq(_recorder.record(SleepAction.new())["i"], 0, "o índice ancora a ordem no arquivo")
	assert_eq(_recorder.record(SleepAction.new())["i"], 1, "o índice ancora a ordem no arquivo")
	assert_eq(_recorder.count(), 2, "duas ações gravadas")

func test_acao_nula_e_ignorada() -> void:
	assert_null(_recorder.record(null), "nada para gravar devolve nada")
	assert_eq(_recorder.count(), 0, "ação nula não suja o rastro")

func test_get_entries_devolve_copia() -> void:
	_recorder.record(SleepAction.new())
	var fora := _recorder.get_entries()
	fora.clear()
	assert_eq(_recorder.count(), 1, "mexer na cópia não apaga o rastro gravado")

func test_desligado_nao_grava() -> void:
	_recorder.set_enabled(false)
	assert_null(_recorder.record(SleepAction.new()), "gravador desligado não devolve entrada")
	assert_eq(_recorder.count(), 0, "release roda sem custo de gravação")

func test_clear_zera_a_sessao() -> void:
	_recorder.record(SleepAction.new())
	_recorder.clear()
	assert_eq(_recorder.count(), 0, "sessão nova começa do zero")

func test_exporta_jsonl_uma_linha_por_acao() -> void:
	_recorder.record(_acao_item("cenoura", 2))
	_recorder.record(SleepAction.new())
	var linhas := _recorder.to_jsonl().split("\n", false)
	assert_eq(linhas.size(), 2, "JSONL: uma ação por linha")
	var primeira: Variant = JSON.parse_string(linhas[0])
	assert_eq(primeira["acao"], "AddItemAction", "cada linha é um JSON completo")
	assert_eq(int(primeira["campos"]["qtd"]), 2, "o payload completo vai junto")

func test_jsonl_vazio_quando_nada_foi_gravado() -> void:
	assert_eq(_recorder.to_jsonl(), "", "sem ação, sem arquivo")

func test_funciona_sem_relogio() -> void:
	var solto := ActionRecorder.new()
	var entrada: Dictionary = solto.record(SleepAction.new())
	assert_eq(entrada["dia"], 0, "sem relógio injetado a hora sai zerada, não quebra")
	assert_eq(entrada["estacao"], "", "sem relógio injetado a estação sai vazia")
