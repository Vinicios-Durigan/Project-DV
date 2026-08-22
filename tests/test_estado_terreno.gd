extends GutTest

## O que cobre cada tile da fazenda — e o que sai do caminho com qual golpe.
##
## ## Por que a cobertura mora fora do `FarmState`
##
## O plot é o que o jogador **fez** com o tile: arou, plantou, regou. A
## cobertura é o que o mundo pôs lá — mato que voltou, pedra que sempre esteve.
## São dois donos diferentes escrevendo no mesmo endereço, e é por isso que o
## `SistemaTerreno` lê o `FarmState` mas nunca escreve nele.
##
## ## Tile ausente é livre
##
## Mesma escolha do plot ausente ser intocado: um mapa recém-criado não tem
## entrada nenhuma, e o save de antes desta wave carrega como fazenda limpa.
## Guardar `livre` explicitamente encheria o arquivo de nada.
##
## ## Limpar é uma tabela, não um `if`
##
## Árvore vira toco, toco vira livre, pedra e mato somem de uma vez. Água não
## sai — e não sair é diferente de "ainda não sei tirar": nenhuma ferramenta
## futura seca um poço.

var _estado: EstadoTerreno


func before_each() -> void:
	_estado = EstadoTerreno.new()


# --- Defaults ---

func test_fazenda_nova_esta_toda_livre() -> void:
	assert_eq(_estado.cobertura(3, 4), EstadoTerreno.LIVRE,
			"tile sem entrada é livre, como plot sem entrada é intocado")
	assert_true(_estado.e_livre(3, 4))
	assert_eq(_estado.ids(), [] as Array[String], "e o dicionário nasce vazio")

func test_nasce_com_a_semente_padrao() -> void:
	assert_eq(_estado.semente, EstadoTerreno.SEMENTE_PADRAO,
			"a semente tem default — a sim nunca sorteia sozinha")

func test_a_chave_do_tile_e_a_mesma_do_plot() -> void:
	assert_eq(EstadoTerreno.tile_id(12, 7), FarmState.plot_id(12, 7),
			"dois endereços diferentes para o mesmo tile seria bug garantido")


# --- Escrever cobertura ---

func test_define_cobertura_guarda() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.PEDRA)
	assert_eq(_estado.cobertura(2, 2), EstadoTerreno.PEDRA)
	assert_false(_estado.e_livre(2, 2))

func test_voltar_para_livre_apaga_a_entrada() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	_estado.define_cobertura(2, 2, EstadoTerreno.LIVRE)
	assert_eq(_estado.ids(), [] as Array[String],
			"livre é ausência — guardar encheria o save de nada")

func test_cobertura_desconhecida_nao_entra() -> void:
	_estado.define_cobertura(2, 2, "lava")
	assert_true(_estado.e_livre(2, 2), "só as coberturas da lista existem")

func test_ids_saem_ordenados() -> void:
	_estado.define_cobertura(5, 1, EstadoTerreno.MATO)
	_estado.define_cobertura(0, 0, EstadoTerreno.PEDRA)
	assert_eq(_estado.ids(), ["0:0", "5:1"] as Array[String],
			"a ordem é contrato: o save tem que sair igual duas vezes")


# --- Limpar ---

func test_arvore_vira_toco_e_toco_vira_livre() -> void:
	_estado.define_cobertura(1, 1, EstadoTerreno.ARVORE)
	assert_eq(_estado.limpa(1, 1), EstadoTerreno.TOCO, "o primeiro golpe derruba")
	assert_eq(_estado.limpa(1, 1), EstadoTerreno.LIVRE, "o segundo arranca o toco")
	assert_true(_estado.e_livre(1, 1), "e o chão fica seu para sempre")

func test_pedra_e_mato_saem_de_uma_vez() -> void:
	_estado.define_cobertura(1, 1, EstadoTerreno.PEDRA)
	assert_eq(_estado.limpa(1, 1), EstadoTerreno.LIVRE)
	_estado.define_cobertura(2, 1, EstadoTerreno.MATO)
	assert_eq(_estado.limpa(2, 1), EstadoTerreno.LIVRE)

func test_agua_nao_se_limpa() -> void:
	_estado.define_cobertura(1, 1, EstadoTerreno.AGUA)
	assert_false(_estado.pode_limpar(1, 1), "nenhuma ferramenta seca um poço")
	assert_eq(_estado.limpa(1, 1), "", "e tentar não muda nada")
	assert_eq(_estado.cobertura(1, 1), EstadoTerreno.AGUA)

func test_limpar_o_que_ja_esta_livre_e_no_op() -> void:
	assert_false(_estado.pode_limpar(1, 1))
	assert_eq(_estado.limpa(1, 1), "", "não há o que tirar do caminho")

func test_o_que_vira_e_consultavel_sem_aplicar() -> void:
	_estado.define_cobertura(1, 1, EstadoTerreno.ARVORE)
	assert_eq(_estado.vira_ao_limpar(1, 1), EstadoTerreno.TOCO, "responde…")
	assert_eq(_estado.cobertura(1, 1), EstadoTerreno.ARVORE, "…sem mexer no tile")


# --- O relógio do arado ocioso ---

func test_o_arado_ocioso_conta_dias() -> void:
	_estado.marca_ocioso(4, 4, 2)
	assert_eq(_estado.dias_ocioso(4, 4), 2,
			"é o contador que decide quando o mato fecha o preparo não usado")

func test_tile_que_ninguem_arou_tem_zero_dia() -> void:
	assert_eq(_estado.dias_ocioso(9, 9), 0)

func test_zerar_apaga_a_entrada() -> void:
	_estado.marca_ocioso(4, 4, 3)
	_estado.marca_ocioso(4, 4, 0)
	assert_eq(_estado.dias_ocioso(4, 4), 0, "plantou, o relógio para")
	assert_false(_estado.to_dict().get("ociosos", {}).has("4:4"),
			"e some do save — contador zerado é ausência")


# --- Save ---

func test_ida_e_volta_preserva_tudo() -> void:
	_estado.semente = 99
	_estado.define_cobertura(1, 2, EstadoTerreno.MATO)
	_estado.define_cobertura(3, 4, EstadoTerreno.ARVORE)
	_estado.marca_ocioso(5, 5, 2)

	var outro := EstadoTerreno.new()
	outro.from_dict(_estado.to_dict())

	assert_eq(outro.semente, 99, "a semente viaja — a fazenda é a mesma no reload")
	assert_eq(outro.cobertura(1, 2), EstadoTerreno.MATO)
	assert_eq(outro.cobertura(3, 4), EstadoTerreno.ARVORE)
	assert_eq(outro.dias_ocioso(5, 5), 2, "o relógio do arado não reinicia ao carregar")

func test_bloco_ausente_e_fazenda_limpa() -> void:
	_estado.define_cobertura(1, 2, EstadoTerreno.MATO)
	_estado.from_dict({})
	assert_true(_estado.e_livre(1, 2),
			"save de antes da wave 14 carrega como terreno limpo, sem migração")
	assert_eq(_estado.semente, EstadoTerreno.SEMENTE_PADRAO)

func test_cobertura_invalida_no_save_e_descartada() -> void:
	_estado.from_dict({"tiles": {"1:2": "lava", "3:4": EstadoTerreno.PEDRA}})
	assert_true(_estado.e_livre(1, 2), "lixo de save não vira cobertura")
	assert_eq(_estado.cobertura(3, 4), EstadoTerreno.PEDRA, "o resto continua carregando")

func test_chave_malformada_no_save_e_descartada() -> void:
	_estado.from_dict({"tiles": {"nao_e_tile": EstadoTerreno.MATO}})
	assert_eq(_estado.ids(), [] as Array[String])
