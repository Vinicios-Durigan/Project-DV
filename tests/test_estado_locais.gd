extends GutTest

## Onde cada jogador está é regra de jogo: é o que decide se regar é aceito ou
## recusado. A posição em pixel mora em `game/`; aqui só existe o local.
##
## O default é a fazenda — save antigo, sem o bloco `locais`, carrega com todo
## mundo em casa e se comporta exatamente como antes da wave 10.

var _estado: EstadoLocais


func before_each() -> void:
	_estado = EstadoLocais.new()


func test_todo_jogador_comeca_na_fazenda() -> void:
	assert_eq(_estado.local_de(0), EstadoLocais.FAZENDA,
		"o jogo abre na fazenda — e save antigo sem o bloco também")
	assert_eq(_estado.local_de(7), EstadoLocais.FAZENDA,
		"jogador nunca visto também tem local: co-op não pode nascer sem default")

func test_define_e_le_o_local() -> void:
	_estado.define_local(0, EstadoLocais.CIDADE)
	assert_eq(_estado.local_de(0), EstadoLocais.CIDADE)
	assert_eq(_estado.local_de(1), EstadoLocais.FAZENDA,
		"o local é por jogador — mover um não move o outro")

func test_reconhece_os_locais_validos() -> void:
	assert_true(_estado.e_valido(EstadoLocais.FAZENDA))
	assert_true(_estado.e_valido(EstadoLocais.CIDADE))
	assert_false(_estado.e_valido("lua"),
		"destino desconhecido não pode virar estado")
	assert_false(_estado.e_valido(""),
		"string vazia também não")


func test_to_dict_e_from_dict_dao_a_volta_completa() -> void:
	_estado.define_local(0, EstadoLocais.CIDADE)
	_estado.define_local(1, EstadoLocais.FAZENDA)

	var copia := EstadoLocais.new()
	copia.from_dict(_estado.to_dict())

	assert_eq(copia.local_de(0), EstadoLocais.CIDADE)
	assert_eq(copia.local_de(1), EstadoLocais.FAZENDA)

func test_from_dict_vazio_cai_no_default() -> void:
	_estado.define_local(0, EstadoLocais.CIDADE)
	_estado.from_dict({})
	assert_eq(_estado.local_de(0), EstadoLocais.FAZENDA,
		"campo ausente no save cai no default — regra de save da wave 05")

func test_from_dict_ignora_local_invalido() -> void:
	_estado.from_dict({"jogadores": {"0": "lua"}})
	assert_eq(_estado.local_de(0), EstadoLocais.FAZENDA,
		"save editado à mão não pode injetar local que o jogo não conhece")

func test_chaves_do_save_sao_strings() -> void:
	_estado.define_local(0, EstadoLocais.CIDADE)
	var dados: Dictionary = _estado.to_dict()
	assert_true(dados["jogadores"].has("0"),
		"JSON não tem chave int — o formato do save usa string, como o inventory")
