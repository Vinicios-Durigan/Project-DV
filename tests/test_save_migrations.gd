extends GutTest

## O trilho de migração. Hoje v1 é a versão atual e migrar é identidade — o que
## este teste protege é o caminho que vai ser usado daqui a seis meses, quando
## um save antigo tiver que atravessar duas versões para voltar a abrir.

var _migrations: SaveMigrations


func before_each() -> void:
	_migrations = SaveMigrations.new()


func _v1() -> Dictionary:
	return {
		"save_version": 1,
		"time": {"dia": 3, "minuto": 400, "estacao": "primavera"},
		"shipping": {"itens": [{"item_id": "cenoura", "qtd": 2}]},
	}


## Save pré-versionamento: dicionário sem carimbo nenhum.
func _v0() -> Dictionary:
	return {"time": {"dia": 3}}

## A versão atual. Um save v2 já tem as ferramentas na mochila.
func _v2() -> Dictionary:
	return {
		"save_version": 2,
		"time": {"dia": 3, "minuto": 400, "estacao": "primavera"},
		"inventory": {"0": {
			"slots": [{"item_id": "enxada", "qtd": 1}],
			"capacity": 24,
			"dinheiro": 500,
			"slot_na_mao": 0,
		}},
	}

func _slots_de(data: Dictionary, player: String = "0") -> Array:
	return data.get("inventory", {}).get(player, {}).get("slots", [])

func _tem_item(data: Dictionary, item_id: String) -> bool:
	for entrada: Variant in _slots_de(data):
		var slot: Dictionary = entrada
		if String(slot.get("item_id", "")) == item_id:
			return true
	return false


func test_versao_atual_e_a_do_sim_world() -> void:
	assert_eq(_migrations.target_version(), SimWorld.SAVE_VERSION, "quem manda na versão é o SimWorld")

func test_dict_sem_carimbo_e_versao_zero() -> void:
	assert_eq(SaveMigrations.version_of(_v0()), 0, "save sem carimbo é anterior ao versionamento")

func test_dict_carimbado_reporta_a_propria_versao() -> void:
	assert_eq(SaveMigrations.version_of(_v1()), 1, "o carimbo é a fonte da versão")

func test_migrar_save_da_versao_atual_e_identidade() -> void:
	var dado := _v2()
	var saida := _migrations.migrate(dado) as Dictionary
	assert_eq(JSON.stringify(saida), JSON.stringify(dado), "save atual atravessa sem ser tocado")


# --- v1 → v2: as ferramentas ---

## O bug que criou este passo: a wave 11.2 fez arar e regar dependerem do item
## na mão. Partida nova recebe as ferramentas; save antigo carrega por cima da
## entrega inicial e o jogador reabria o jogo sem conseguir fazer nada — e sem
## nada na tela explicando por quê.
func test_save_v1_ganha_as_ferramentas() -> void:
	var migrado := _migrations.migrate(_v1_com_mochila([])) as Dictionary

	assert_not_null(migrado, "save v1 tem que chegar até a versão atual")
	for item_id in SimFactory.FERRAMENTAS_INICIAIS:
		assert_true(_tem_item(migrado, item_id),
			"%s: sem ela o save antigo vira uma partida que não joga" % item_id)

func test_quem_ja_tem_a_ferramenta_nao_ganha_outra() -> void:
	var migrado := _migrations.migrate(
		_v1_com_mochila([{"item_id": "enxada", "qtd": 1}])) as Dictionary

	var enxadas := 0
	for entrada: Variant in _slots_de(migrado):
		var slot: Dictionary = entrada
		if String(slot.get("item_id", "")) == "enxada":
			enxadas += 1
	assert_eq(enxadas, 1, "a migração duplicou a ferramenta")

func test_a_migracao_preserva_o_resto_do_save() -> void:
	var migrado := _migrations.migrate(_v1_com_mochila(
		[{"item_id": "morango", "qtd": 5}])) as Dictionary

	assert_true(_tem_item(migrado, "morango"), "a colheita do jogador sumiu")
	assert_eq(int(migrado["inventory"]["0"]["dinheiro"]), 3450, "o dinheiro mudou")
	assert_eq(int(migrado["time"]["dia"]), 7, "o calendário andou sozinho")

func test_mochila_cheia_nao_estoura_a_capacidade() -> void:
	# Melhor um item a menos que um save corrompido — e o playground tem botão
	# para recomeçar.
	var cheia: Array = []
	for i in 3:
		cheia.append({"item_id": "morango", "qtd": 5})
	var save := _v1_com_mochila(cheia)
	save["inventory"]["0"]["capacity"] = 3

	var migrado := _migrations.migrate(save) as Dictionary

	assert_eq(_slots_de(migrado).size(), 3, "a migração passou por cima da capacidade")

## Um save como o que o jogo gravava antes da wave 11.2.
func _v1_com_mochila(slots: Array) -> Dictionary:
	return {
		"save_version": 1,
		"time": {"dia": 7, "minuto": 360, "estacao": "primavera"},
		"inventory": {"0": {"slots": slots, "capacity": 24, "dinheiro": 3450}},
	}

func test_migrar_nao_altera_o_dicionario_de_entrada() -> void:
	var dado := _v1()
	var antes := JSON.stringify(dado)
	var migrations := SaveMigrations.new(2)
	migrations.register_step(1, func(data: Dictionary) -> Dictionary:
		data["time"] = {"dia": 999}
		return data)

	migrations.migrate(dado)
	assert_eq(JSON.stringify(dado), antes, "o dicionário original não é mexido pelo passo")

func test_sem_passo_registrado_save_antigo_nao_carrega() -> void:
	assert_null(_migrations.migrate(_v0()), "sem trilho, save velho é recusado — nunca carregado pela metade")

func test_passo_registrado_atravessa_e_carimba() -> void:
	_migrations.register_step(0, func(data: Dictionary) -> Dictionary:
		data["shipping"] = {"itens": []}
		return data)

	var saida := _migrations.migrate(_v0()) as Dictionary
	assert_eq(int(saida["save_version"]), SimWorld.SAVE_VERSION,
		"quem migra sai carimbado com a versão de destino")
	assert_true(saida.has("shipping"), "o passo preencheu o bloco que faltava")
	assert_eq(int((saida["time"] as Dictionary)["dia"]), 3, "o que já estava lá continua lá")

func test_migracoes_sao_aplicadas_em_cadeia() -> void:
	var migrations := SaveMigrations.new(3)
	migrations.register_step(0, func(data: Dictionary) -> Dictionary:
		data["trilho"] = "0"
		return data)
	migrations.register_step(1, func(data: Dictionary) -> Dictionary:
		data["trilho"] = String(data["trilho"]) + ">1"
		return data)
	migrations.register_step(2, func(data: Dictionary) -> Dictionary:
		data["trilho"] = String(data["trilho"]) + ">2"
		return data)

	var saida := migrations.migrate(_v0()) as Dictionary
	assert_eq(String(saida["trilho"]), "0>1>2", "os passos rodam em ordem, um por versão")
	assert_eq(int(saida["save_version"]), 3, "chegou carimbado na versão final")

func test_cadeia_comeca_na_versao_do_save_e_nao_do_zero() -> void:
	var migrations := SaveMigrations.new(3)
	migrations.register_step(1, func(data: Dictionary) -> Dictionary:
		data["trilho"] = "1"
		return data)
	migrations.register_step(2, func(data: Dictionary) -> Dictionary:
		data["trilho"] = String(data["trilho"]) + ">2"
		return data)

	var saida := migrations.migrate(_v1()) as Dictionary
	assert_eq(String(saida["trilho"]), "1>2", "save v1 não passa pelo passo do v0")

func test_buraco_no_meio_da_cadeia_recusa_o_save() -> void:
	var migrations := SaveMigrations.new(3)
	migrations.register_step(0, func(data: Dictionary) -> Dictionary: return data)
	# falta o passo 1 → 2
	assert_null(migrations.migrate(_v0()), "cadeia furada não carrega — melhor jogo novo que save torto")

func test_save_do_futuro_e_recusado() -> void:
	var futuro := _v1()
	futuro["save_version"] = SimWorld.SAVE_VERSION + 1
	assert_null(_migrations.migrate(futuro), "save de uma versão mais nova do que o jogo não abre")

func test_passo_que_nao_devolve_dicionario_recusa_o_save() -> void:
	var migrations := SaveMigrations.new(1)
	migrations.register_step(0, func(_data: Dictionary) -> Variant: return null)
	assert_null(migrations.migrate(_v0()), "passo quebrado não deixa lixo virar save")

func test_register_step_recusa_versao_fora_do_trilho() -> void:
	var passo := func(data: Dictionary) -> Dictionary: return data
	_migrations.register_step(-1, passo)
	_migrations.register_step(SimWorld.SAVE_VERSION, passo)
	assert_false(_migrations.has_step(-1), "não existe passo antes do zero")
	assert_false(_migrations.has_step(SimWorld.SAVE_VERSION), "não existe passo saindo da versão atual")

func test_can_migrate_responde_antes_de_tentar() -> void:
	assert_true(_migrations.can_migrate(_v1()), "save atual é carregável")
	assert_false(_migrations.can_migrate(_v0()), "save sem trilho não é carregável")

func test_save_migrado_ainda_restaura_no_mundo() -> void:
	var migrations := SaveMigrations.new()
	var world := SimWorld.new()
	var time := TimeState.new()
	world.register_state("time", time)

	var saida := migrations.migrate(_v1()) as Dictionary
	world.restore(saida)

	assert_eq(time.dia, 3, "o que sai da migração é o que o mundo restaura")
	assert_eq(time.estacao, "primavera", "nenhum campo se perdeu no caminho")
