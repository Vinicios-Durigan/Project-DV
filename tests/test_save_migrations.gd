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


func test_versao_atual_e_a_do_sim_world() -> void:
	assert_eq(_migrations.target_version(), SimWorld.SAVE_VERSION, "quem manda na versão é o SimWorld")

func test_dict_sem_carimbo_e_versao_zero() -> void:
	assert_eq(SaveMigrations.version_of(_v0()), 0, "save sem carimbo é anterior ao versionamento")

func test_dict_carimbado_reporta_a_propria_versao() -> void:
	assert_eq(SaveMigrations.version_of(_v1()), 1, "o carimbo é a fonte da versão")

func test_migrar_save_da_versao_atual_e_identidade() -> void:
	var dado := _v1()
	var saida := _migrations.migrate(dado) as Dictionary
	assert_eq(JSON.stringify(saida), JSON.stringify(dado), "save atual atravessa sem ser tocado")

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
	assert_eq(int(saida["save_version"]), 1, "quem migra sai carimbado com a versão de destino")
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
