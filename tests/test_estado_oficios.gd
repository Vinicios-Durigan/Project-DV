extends GutTest

## A caderneta do jogador: quanto XP cada ofício acumulou, que nível isso virou,
## quantos pontos sobraram e o que já foi comprado com eles.
##
## ## O state é burro
##
## Ele não sabe que arar dá 4 de XP, que o nível 2 de Lavoura pede 300, nem que
## Mãos leves custa 1 ponto e para no teto 2. Tudo isso é tabela do
## `SistemaOficios`. Aqui só se soma, se guarda o nível que mandaram guardar, se
## credita e se desconta ponto — com piso em zero, como o `EstadoCorpo`.
##
## ## Ponto preso no ofício
##
## Não existe "pontos do jogador": existem pontos de Lavoura e pontos de Campo,
## em contas separadas. É o que faz abrir o tabuleiro inteiro obrigar a variar o
## trabalho.
##
## ## Jogador ausente é folha em branco
##
## Mesma decisão do `EstadoCorpo`: quem nunca trabalhou não tem entrada, e o save
## de antes desta wave carrega sem nível nenhum. É o que dispensa migração.

const JOGADOR: int = 0
const OUTRO: int = 1

const LAVOURA: String = "lavoura"
const CAMPO: String = "campo"
const MAOS_LEVES: String = "maos_leves"
const COSTAS_LARGAS: String = "costas_largas"

var _estado: EstadoOficios


func before_each() -> void:
	_estado = EstadoOficios.new()


# --- Defaults ---

func test_jogador_nunca_visto_esta_zerado() -> void:
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 0, "quem nunca trabalhou não praticou")
	assert_eq(_estado.nivel_de(JOGADOR, LAVOURA), 0)
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 0)
	assert_eq(_estado.jogadores(), [] as Array[int],
			"e não ocupa uma linha no save por isso")

func test_ninguem_nasce_com_vantagem() -> void:
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 0)
	assert_eq(_estado.vantagens_de(JOGADOR), {} as Dictionary)

func test_ninguem_nasce_especializado() -> void:
	assert_eq(_estado.cultura_de(JOGADOR), "",
			"a cultura da especialização só existe depois da escolha")


# --- XP ---

func test_somar_xp_acumula_e_devolve_o_total() -> void:
	assert_eq(_estado.soma_xp(JOGADOR, LAVOURA, 4), 4, "devolve o acumulado")
	assert_eq(_estado.soma_xp(JOGADOR, LAVOURA, 2), 6)
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 6)

func test_xp_de_um_oficio_nao_entra_no_outro() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 100)
	assert_eq(_estado.xp_de(JOGADOR, CAMPO), 0,
			"quem planta não fica bom em derrubar árvore")

func test_xp_de_um_jogador_nao_entra_no_outro() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 50)
	assert_eq(_estado.xp_de(OUTRO, LAVOURA), 0)

func test_xp_negativo_e_ignorado() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 40)
	_estado.soma_xp(JOGADOR, LAVOURA, -100)
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 40,
			"trabalho não desensina — XP só sobe")


# --- Nível ---

## Quem cruza os limiares é o sistema; o state guarda o número que mandaram
## guardar. Mesma divisão do custo de arar no `EstadoCorpo`.
func test_define_nivel_guarda_o_que_o_sistema_decidiu() -> void:
	_estado.define_nivel(JOGADOR, LAVOURA, 3)
	assert_eq(_estado.nivel_de(JOGADOR, LAVOURA), 3)

func test_nivel_nunca_desce() -> void:
	_estado.define_nivel(JOGADOR, LAVOURA, 3)
	_estado.define_nivel(JOGADOR, LAVOURA, 1)
	assert_eq(_estado.nivel_de(JOGADOR, LAVOURA), 3,
			"o que foi aprendido não se desaprende")

func test_nivel_negativo_e_ignorado() -> void:
	_estado.define_nivel(JOGADOR, LAVOURA, -2)
	assert_eq(_estado.nivel_de(JOGADOR, LAVOURA), 0)


# --- Pontos, presos no ofício ---

func test_creditar_ponto_deixa_o_ponto_disponivel() -> void:
	_estado.credita_pontos(JOGADOR, LAVOURA, 2)
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 2)
	assert_eq(_estado.gastos_de(JOGADOR, LAVOURA), 0)

func test_ponto_de_lavoura_nao_aparece_no_campo() -> void:
	_estado.credita_pontos(JOGADOR, LAVOURA, 3)
	assert_eq(_estado.pontos_de(JOGADOR, CAMPO), 0,
			"ponto é preso no ofício que o ganhou")

func test_gastar_desconta_e_conta_o_gasto() -> void:
	_estado.credita_pontos(JOGADOR, LAVOURA, 3)
	_estado.gasta_pontos(JOGADOR, LAVOURA, 2)
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 1, "sobrou um")
	assert_eq(_estado.gastos_de(JOGADOR, LAVOURA), 2, "e dois foram embora")

## Quem recusa a compra sem ponto é o sistema. O state só protege a invariante:
## ponto não fica negativo, como o cansaço não fica.
func test_gasto_tem_piso_em_zero() -> void:
	_estado.credita_pontos(JOGADOR, LAVOURA, 1)
	_estado.gasta_pontos(JOGADOR, LAVOURA, 5)
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 0, "ponto não fica negativo")

func test_credito_negativo_e_ignorado() -> void:
	_estado.credita_pontos(JOGADOR, LAVOURA, 2)
	_estado.credita_pontos(JOGADOR, LAVOURA, -5)
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 2,
			"tirar ponto de volta seria desfazer nível — e nível não desce")


# --- Vantagens ---

func test_comprar_sobe_o_nivel_da_vantagem() -> void:
	assert_eq(_estado.compra_vantagem(JOGADOR, MAOS_LEVES), 1, "devolve o nível novo")
	assert_eq(_estado.compra_vantagem(JOGADOR, MAOS_LEVES), 2)
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 2)

func test_vantagem_de_um_nao_e_do_outro() -> void:
	_estado.compra_vantagem(JOGADOR, MAOS_LEVES)
	assert_eq(_estado.nivel_da_vantagem(OUTRO, MAOS_LEVES), 0)

## O teto é do sistema, não daqui: o state deixa comprar quantas vezes mandarem.
## A regra existe uma vez só, e ela mora onde estão os custos.
func test_o_state_nao_conhece_teto() -> void:
	for _i in 5:
		_estado.compra_vantagem(JOGADOR, MAOS_LEVES)
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 5,
			"quem segura o teto é o SistemaOficios")

func test_vantagens_saem_ordenadas() -> void:
	_estado.compra_vantagem(JOGADOR, MAOS_LEVES)
	_estado.compra_vantagem(JOGADOR, COSTAS_LARGAS)
	assert_eq(_estado.vantagens_de(JOGADOR).keys(), [COSTAS_LARGAS, MAOS_LEVES],
			"a ordem é contrato: o save tem que sair igual duas vezes")


# --- A cultura da especialização ---

func test_define_cultura_guarda_a_escolha() -> void:
	_estado.define_cultura(JOGADOR, "rabanete")
	assert_eq(_estado.cultura_de(JOGADOR), "rabanete")

func test_a_cultura_escolhida_nao_troca() -> void:
	_estado.define_cultura(JOGADOR, "rabanete")
	_estado.define_cultura(JOGADOR, "morango")
	assert_eq(_estado.cultura_de(JOGADOR), "rabanete",
			"escolha permanente: quem decide isso é o state, e ele não volta atrás")

func test_cultura_vazia_nao_apaga_a_escolha() -> void:
	_estado.define_cultura(JOGADOR, "rabanete")
	_estado.define_cultura(JOGADOR, "")
	assert_eq(_estado.cultura_de(JOGADOR), "rabanete")


# --- Save ---

func test_jogadores_saem_ordenados() -> void:
	_estado.soma_xp(OUTRO, LAVOURA, 1)
	_estado.soma_xp(JOGADOR, LAVOURA, 1)
	assert_eq(_estado.jogadores(), [JOGADOR, OUTRO] as Array[int],
			"a ordem é contrato: o save tem que sair igual duas vezes")

func test_oficios_saem_ordenados() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 1)
	_estado.soma_xp(JOGADOR, CAMPO, 1)
	assert_eq(_estado.oficios_de(JOGADOR), [CAMPO, LAVOURA] as Array[String])

func test_snapshot_leva_xp_nivel_e_pontos() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 120)
	_estado.define_nivel(JOGADOR, LAVOURA, 1)
	_estado.credita_pontos(JOGADOR, LAVOURA, 1)
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]["oficios"][LAVOURA]
	assert_eq(int(bloco["xp"]), 120)
	assert_eq(int(bloco["nivel"]), 1)
	assert_eq(int(bloco["pontos"]), 1)

func test_snapshot_leva_vantagens_e_cultura() -> void:
	_estado.compra_vantagem(JOGADOR, MAOS_LEVES)
	_estado.define_cultura(JOGADOR, "morango")
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]
	assert_eq(int(bloco["vantagens"][MAOS_LEVES]), 1)
	assert_eq(String(bloco["cultura"]), "morango")

func test_caderneta_intocada_nao_ocupa_o_save() -> void:
	assert_eq(_estado.to_dict()["jogadores"], {},
			"quem não trabalhou não escreve nada — é o que dispensa migração")

func test_ida_e_volta_pelo_save() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 340)
	_estado.define_nivel(JOGADOR, LAVOURA, 2)
	_estado.credita_pontos(JOGADOR, LAVOURA, 2)
	_estado.gasta_pontos(JOGADOR, LAVOURA, 1)
	_estado.compra_vantagem(JOGADOR, MAOS_LEVES)
	_estado.define_cultura(JOGADOR, "rabanete")
	_estado.soma_xp(OUTRO, CAMPO, 30)

	var outro := EstadoOficios.new()
	outro.from_dict(_estado.to_dict())
	assert_eq(outro.xp_de(JOGADOR, LAVOURA), 340)
	assert_eq(outro.nivel_de(JOGADOR, LAVOURA), 2)
	assert_eq(outro.pontos_de(JOGADOR, LAVOURA), 1, "o ponto que sobrou continua lá")
	assert_eq(outro.gastos_de(JOGADOR, LAVOURA), 1, "e o gasto não some")
	assert_eq(outro.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 1)
	assert_eq(outro.cultura_de(JOGADOR), "rabanete")
	assert_eq(outro.xp_de(OUTRO, CAMPO), 30)

func test_bloco_ausente_carrega_folha_em_branco() -> void:
	_estado.soma_xp(JOGADOR, LAVOURA, 500)
	_estado.from_dict({})
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 0,
			"save de antes da wave 17 é um jogador sem ofício — sem migração")
	assert_eq(_estado.jogadores(), [] as Array[int])

func test_save_editado_a_mao_nao_tem_xp_negativo() -> void:
	_estado.from_dict({"jogadores": {"0": {"oficios": {LAVOURA: {"xp": -50, "nivel": -3}}}}})
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 0, "menos que nada não é prática")
	assert_eq(_estado.nivel_de(JOGADOR, LAVOURA), 0)

func test_save_editado_a_mao_nao_tem_ponto_negativo() -> void:
	_estado.from_dict({"jogadores": {"0": {"oficios": {LAVOURA: {"pontos": -2, "gastos": -9}}}}})
	assert_eq(_estado.pontos_de(JOGADOR, LAVOURA), 0)
	assert_eq(_estado.gastos_de(JOGADOR, LAVOURA), 0)

func test_save_com_lixo_no_lugar_do_oficio_e_ignorado() -> void:
	_estado.from_dict({"jogadores": {"0": {"oficios": {LAVOURA: 7}}}})
	assert_eq(_estado.xp_de(JOGADOR, LAVOURA), 0, "entrada torta não derruba o carregamento")
