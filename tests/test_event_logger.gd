extends GutTest

## Log de eventos: o que este teste protege é a promessa de que toda sessão
## deixa rastro em arquivo — o que a sim disse que aconteceu, na ordem, com a
## hora de jogo, sem depender de ninguém estar olhando o console.

const DIR_TESTE: String = "user://test_logs"

var _logger: EventLogger
var _time: TimeState


func before_each() -> void:
	_limpa_diretorio()
	_time = TimeState.new()
	_logger = EventLogger.new(_time, DIR_TESTE)


func after_each() -> void:
	if _logger != null:
		_logger.close()


func after_all() -> void:
	_limpa_diretorio()


func _limpa_diretorio() -> void:
	if not DirAccess.dir_exists_absolute(DIR_TESTE):
		return
	var dir := DirAccess.open(DIR_TESTE)
	if dir == null:
		return
	for arquivo in dir.get_files():
		dir.remove(arquivo)


func _arquivos() -> Array[String]:
	if not DirAccess.dir_exists_absolute(DIR_TESTE):
		return []
	var dir := DirAccess.open(DIR_TESTE)
	if dir == null:
		return []
	var nomes: Array[String] = []
	for arquivo in dir.get_files():
		nomes.append(arquivo)
	nomes.sort()
	return nomes


func _linhas() -> PackedStringArray:
	var arquivo := FileAccess.open(_logger.get_path(), FileAccess.READ)
	if arquivo == null:
		return PackedStringArray()
	var texto := arquivo.get_as_text()
	arquivo.close()
	return texto.split("\n", false)


func _evento_item(item_id: String, qtd: int) -> ItemAddedEvent:
	var evento := ItemAddedEvent.new()
	evento.item_id = item_id
	evento.qtd = qtd
	return evento


func test_nao_cria_arquivo_antes_do_primeiro_evento() -> void:
	assert_eq(_arquivos().size(), 0, "sessão sem evento não deixa arquivo vazio no disco")

func test_primeiro_evento_cria_o_arquivo_da_sessao() -> void:
	_logger.log(_evento_item("cenoura", 1))
	assert_eq(_arquivos().size(), 1, "um arquivo por sessão")
	assert_true(_logger.get_path().ends_with(".jsonl"), "formato de log, não de save")

func test_grava_tipo_do_evento() -> void:
	_logger.log(_evento_item("cenoura", 1))
	var linha: Variant = JSON.parse_string(_linhas()[0])
	assert_eq(linha["evento"], "ItemAddedEvent", "o tipo diz o que a sim afirmou")

func test_grava_campos_por_reflection() -> void:
	_logger.log(_evento_item("cenoura", 4))
	var campos: Dictionary = JSON.parse_string(_linhas()[0])["campos"]
	assert_eq(campos["item_id"], "cenoura", "campo do evento entra sozinho")
	assert_eq(int(campos["qtd"]), 4, "campo do evento entra sozinho")

func test_grava_hora_de_jogo() -> void:
	_time.dia = 9
	_time.minuto = 480
	_time.estacao = "outono"
	_logger.log(_evento_item("cenoura", 1))
	var linha: Variant = JSON.parse_string(_linhas()[0])
	assert_eq(int(linha["dia"]), 9, "hora de jogo é o que liga o log ao bug relatado")
	assert_eq(int(linha["minuto"]), 480, "hora de jogo é o que liga o log ao bug relatado")
	assert_eq(linha["estacao"], "outono", "estação faz parte do relógio")

func test_uma_linha_por_evento_na_ordem_de_emissao() -> void:
	_logger.log(_evento_item("a", 1))
	_logger.log(_evento_item("b", 1))
	_logger.log(_evento_item("c", 1))
	var linhas := _linhas()
	assert_eq(linhas.size(), 3, "JSONL: um evento por linha")
	assert_eq(JSON.parse_string(linhas[0])["campos"]["item_id"], "a", "ordem de emissão é regra de jogo")
	assert_eq(JSON.parse_string(linhas[2])["campos"]["item_id"], "c", "ordem de emissão é regra de jogo")

func test_indice_ancora_a_ordem() -> void:
	_logger.log(_evento_item("a", 1))
	_logger.log(_evento_item("b", 1))
	var linhas := _linhas()
	assert_eq(int(JSON.parse_string(linhas[0])["i"]), 0, "índice ancora a ordem dentro do arquivo")
	assert_eq(int(JSON.parse_string(linhas[1])["i"]), 1, "índice ancora a ordem dentro do arquivo")

func test_log_batch_grava_a_saida_de_um_tick_inteiro() -> void:
	var eventos: Array[SimEvent] = [_evento_item("a", 1), _evento_item("b", 1)]
	assert_eq(_logger.log_batch(eventos), 2, "o lote devolve quantos entraram")
	assert_eq(_linhas().size(), 2, "a saída de handle/advance vai inteira para o log")

func test_evento_nulo_e_ignorado() -> void:
	assert_false(_logger.log(null), "nada para logar não vira linha")
	assert_eq(_logger.count(), 0, "evento nulo não suja o log")

func test_desligado_nao_escreve_nada() -> void:
	_logger.set_enabled(false)
	assert_false(_logger.log(_evento_item("cenoura", 1)), "logger desligado não grava")
	assert_eq(_arquivos().size(), 0, "release roda sem tocar o disco")
	assert_eq(_logger.count(), 0, "desligado não conta evento")

func test_religar_volta_a_gravar() -> void:
	_logger.set_enabled(false)
	_logger.log(_evento_item("a", 1))
	_logger.set_enabled(true)
	_logger.log(_evento_item("b", 1))
	assert_eq(_linhas().size(), 1, "só o que passou com o logger ligado está no arquivo")

func test_evento_fica_legivel_sem_fechar_o_logger() -> void:
	_logger.log(_evento_item("cenoura", 1))
	assert_eq(_linhas().size(), 1, "crash não pode levar o log junto: cada linha vai para o disco na hora")

func test_count_conta_o_que_foi_escrito() -> void:
	_logger.log(_evento_item("a", 1))
	_logger.log(_evento_item("b", 1))
	assert_eq(_logger.count(), 2, "dois eventos logados")

func test_sessoes_diferentes_nao_se_sobrescrevem() -> void:
	_logger.log(_evento_item("a", 1))
	var primeiro := _logger.get_path()
	_logger.close()
	var outro := EventLogger.new(_time, DIR_TESTE, "sessao_2")
	outro.log(_evento_item("b", 1))
	assert_ne(outro.get_path(), primeiro, "um arquivo por sessão, sem sobrescrever o anterior")
	assert_eq(_arquivos().size(), 2, "as duas sessões continuam no disco")
	outro.close()

func test_funciona_sem_relogio() -> void:
	var solto := EventLogger.new(null, DIR_TESTE, "sem_relogio")
	assert_true(solto.log(_evento_item("cenoura", 1)), "sem relógio injetado o log continua gravando")
	var linha: Variant = JSON.parse_string(_linhas_de(solto)[0])
	assert_eq(int(linha["dia"]), 0, "sem relógio a hora sai zerada, não quebra")
	solto.close()


func _linhas_de(logger: EventLogger) -> PackedStringArray:
	var arquivo := FileAccess.open(logger.get_path(), FileAccess.READ)
	if arquivo == null:
		return PackedStringArray()
	var texto := arquivo.get_as_text()
	arquivo.close()
	return texto.split("\n", false)
