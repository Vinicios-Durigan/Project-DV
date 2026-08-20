extends GutTest

## Dict ↔ JSON ↔ disco. O que este teste protege é a promessa de que queda de
## energia no meio do save não corrompe o arquivo do jogador.

const DIR_TESTE: String = "user://test_saves"

var _manager: SaveManager


func before_each() -> void:
	_limpa_diretorio()
	_manager = SaveManager.new(DIR_TESTE)


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


func _dado_rico() -> Dictionary:
	return {
		"save_version": 1,
		"time": {"dia": 12, "minuto": 700, "estacao": "verao"},
		"inventory": {"1": {"slots": [{"item_id": "cenoura", "qtd": 5}], "capacity": 24, "dinheiro": 1234}},
		"farm": {"plots": {"2:3": {"arada": true, "regada": false, "crop_id": "cenoura", "estagio": 1, "dias_no_estagio": 0}}},
		"shipping": {"itens": [{"item_id": "rabanete", "qtd": 9}]},
	}


func test_slot_inexistente_devolve_null() -> void:
	assert_null(_manager.load_slot("slot_1"), "jogo novo: não existe save para carregar")

func test_has_slot_e_falso_antes_de_salvar() -> void:
	assert_false(_manager.has_slot("slot_1"), "sem arquivo, sem slot")

func test_salvar_e_carregar_devolve_o_mesmo_dicionario() -> void:
	var dado := _dado_rico()
	assert_true(_manager.save_slot(dado, "slot_1"), "save reporta sucesso")

	var lido: Variant = _manager.load_slot("slot_1")
	assert_typeof(lido, TYPE_DICTIONARY, "o que volta do disco é dicionário")

	var saida := lido as Dictionary
	var chaves_saida: Array = saida.keys()
	var chaves_dado: Array = dado.keys()
	chaves_saida.sort()
	chaves_dado.sort()
	assert_eq(chaves_saida, chaves_dado, "os mesmos blocos voltaram")
	assert_eq(int(saida["save_version"]), 1, "o carimbo atravessou")
	assert_eq(String((saida["time"] as Dictionary)["estacao"]), "verao", "texto atravessa sem conversão")
	assert_eq(int((saida["time"] as Dictionary)["dia"]), 12, "número atravessa com o valor intacto")
	assert_true((saida["farm"] as Dictionary).has("plots"), "estrutura aninhada atravessou")
	assert_eq(((saida["shipping"] as Dictionary)["itens"] as Array).size(), 1, "lista atravessou")

func test_numero_volta_do_disco_como_float() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	var saida := _manager.load_slot("slot_1") as Dictionary

	# JSON não tem inteiro: o dicionário do disco NÃO é igual ao que foi salvo.
	# Quem devolve o tipo é o from_dict de cada state — este teste existe para
	# que ninguém confie em comparação direta de snapshot com o dado do disco.
	assert_typeof((saida["time"] as Dictionary)["dia"], TYPE_FLOAT, "número volta como float")
	assert_typeof((saida["time"] as Dictionary)["estacao"], TYPE_STRING, "texto volta como texto")

func test_o_mundo_conserta_os_tipos_ao_restaurar() -> void:
	var world := SimWorld.new()
	var time := TimeState.new()
	world.register_state("time", time)
	_manager.save_slot(_dado_rico(), "slot_1")

	world.restore(_manager.load_slot("slot_1") as Dictionary)

	assert_typeof(time.dia, TYPE_INT, "o state tipa de volta o que o JSON afrouxou")
	assert_eq(time.dia, 12, "e sem perder o valor")
	assert_eq(JSON.stringify(world.snapshot()["time"]), JSON.stringify(_dado_rico()["time"]), "o bloco fecha o ciclo idêntico")

func test_has_slot_depois_de_salvar() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	assert_true(_manager.has_slot("slot_1"), "arquivo escrito é slot existente")

func test_o_arquivo_fica_no_caminho_do_slot() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	assert_eq(_manager.path_for("slot_1"), "%s/slot_1.json" % DIR_TESTE, "um slot, um arquivo .json")
	assert_true(FileAccess.file_exists(_manager.path_for("slot_1")), "o arquivo está onde o caminho diz")

func test_escrita_atomica_nao_deixa_temporario_para_tras() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	assert_eq(_arquivos(), ["slot_1.json"], "o temporário vira o definitivo — não sobra lixo no diretório")

func test_salvar_por_cima_substitui_o_conteudo() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	_manager.save_slot({"save_version": 1, "time": {"dia": 99}}, "slot_1")

	var lido := _manager.load_slot("slot_1") as Dictionary
	assert_eq(int((lido["time"] as Dictionary)["dia"]), 99, "o save novo mandou")
	assert_false(lido.has("farm"), "o arquivo foi substituído, não emendado")
	assert_eq(_arquivos(), ["slot_1.json"], "sobrescrever também não deixa temporário")

func test_slots_diferentes_nao_se_misturam() -> void:
	_manager.save_slot({"save_version": 1, "time": {"dia": 1}}, "slot_1")
	_manager.save_slot({"save_version": 1, "time": {"dia": 2}}, "slot_2")

	var um := _manager.load_slot("slot_1") as Dictionary
	var dois := _manager.load_slot("slot_2") as Dictionary
	assert_eq(int((um["time"] as Dictionary)["dia"]), 1, "slot_1 guardou o dele")
	assert_eq(int((dois["time"] as Dictionary)["dia"]), 2, "slot_2 guardou o dele")

func test_delete_slot_apaga_o_arquivo() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	assert_true(_manager.delete_slot("slot_1"), "apagar slot existente dá certo")
	assert_false(_manager.has_slot("slot_1"), "depois de apagar, é jogo novo de novo")

func test_delete_de_slot_inexistente_nao_quebra() -> void:
	assert_false(_manager.delete_slot("slot_9"), "apagar o que não existe apenas reporta falso")

func test_slot_vazio_e_recusado() -> void:
	assert_false(_manager.save_slot(_dado_rico(), ""), "slot sem nome não vira arquivo")
	assert_eq(_arquivos(), [], "nada foi escrito")

func test_arquivo_corrompido_devolve_null() -> void:
	_manager.save_slot(_dado_rico(), "slot_1")
	var arquivo := FileAccess.open(_manager.path_for("slot_1"), FileAccess.WRITE)
	arquivo.store_string("{isso nao e json")
	arquivo.close()

	assert_null(_manager.load_slot("slot_1"), "save ilegível é tratado como ausente, nunca como meio-carregado")

func test_roundtrip_do_mundo_pelo_disco() -> void:
	var world := SimWorld.new()
	var time := TimeState.new()
	var shipping := ShippingState.new()
	world.register_state("time", time)
	world.register_state("shipping", shipping)
	time.dia = 8
	time.estacao = "outono"
	shipping.add("morango", 4)

	_manager.save_slot(world.snapshot(), "slot_1")

	var destino := SimWorld.new()
	var time_destino := TimeState.new()
	var shipping_destino := ShippingState.new()
	destino.register_state("time", time_destino)
	destino.register_state("shipping", shipping_destino)
	destino.restore(_manager.load_slot("slot_1") as Dictionary)

	assert_eq(time_destino.dia, 8, "o dia atravessou o disco")
	assert_eq(time_destino.estacao, "outono", "a estação atravessou o disco")
	assert_eq(shipping_destino.count("morango"), 4, "o caixote atravessou o disco")
