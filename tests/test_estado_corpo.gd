extends GutTest

## O corpo do jogador: quanta estamina resta, quanto cabe, e o que sobra depois
## de um dia de trabalho.
##
## ## O state é burro
##
## Ele não sabe que arar custa 4 e derrubar árvore custa 12 — a tabela é do
## `SistemaCorpo`. Aqui só se guarda o número, se desconta com piso em zero e se
## restaura cheio ou pela metade. Mesma escolha do `EstadoCidade`, que não sabe
## o que é um moinho.
##
## ## Jogador ausente está inteiro
##
## Mesma decisão do `EstadoLocais`: quem nunca trabalhou não tem entrada, e o
## save de antes desta wave carrega com todo mundo descansado. É o que dispensa
## migração.

const JOGADOR: int = 0
const OUTRO: int = 1

var _estado: EstadoCorpo


func before_each() -> void:
	_estado = EstadoCorpo.new()


# --- Defaults ---

func test_jogador_nunca_visto_esta_inteiro() -> void:
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"quem nunca trabalhou está descansado")
	assert_eq(_estado.maxima_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO)
	assert_eq(_estado.jogadores(), [] as Array[int],
			"e não ocupa uma linha no save por isso")

func test_ninguem_nasce_desmaiado() -> void:
	assert_false(_estado.desmaiado(JOGADOR))


# --- Gastar ---

func test_gasta_desconta_e_devolve_o_que_sobrou() -> void:
	var resto := _estado.gasta(JOGADOR, 30)
	assert_eq(resto, EstadoCorpo.ESTAMINA_PADRAO - 30, "devolve o que ficou")
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 30)

func test_gasto_tem_piso_em_zero() -> void:
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO + 50)
	assert_eq(_estado.estamina_de(JOGADOR), 0, "cansaço não fica negativo")
	assert_true(_estado.desmaiado(JOGADOR), "e zero é desmaio")

func test_gasto_negativo_nao_enche() -> void:
	_estado.gasta(JOGADOR, 40)
	_estado.gasta(JOGADOR, -100)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 40,
			"descansar é assunto do restauro, nunca de um custo negativo")

func test_cada_jogador_tem_o_proprio_corpo() -> void:
	_estado.gasta(JOGADOR, 50)
	assert_eq(_estado.estamina_de(OUTRO), EstadoCorpo.ESTAMINA_PADRAO,
			"o cansaço de um não cansa o outro")


# --- Restaurar ---

func test_encher_devolve_o_maximo() -> void:
	_estado.gasta(JOGADOR, 150)
	_estado.enche(JOGADOR)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"dormir sempre enche — o dia de amanhã não depende do de ontem")

func test_encher_metade_e_o_preco_do_desmaio() -> void:
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
	_estado.enche_metade(JOGADOR)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO / 2,
			"quem desmaia hoje rende metade amanhã")

func test_metade_de_maxima_impar_arredonda_para_baixo() -> void:
	_estado.define_maxima(JOGADOR, 5)
	_estado.enche_metade(JOGADOR)
	assert_eq(_estado.estamina_de(JOGADOR), 2, "meia estamina nunca é meio ponto")

func test_encher_metade_nao_e_desmaio() -> void:
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
	_estado.enche_metade(JOGADOR)
	assert_false(_estado.desmaiado(JOGADOR),
			"acordar com metade não pode disparar outro desmaio")


# --- A máxima ---

func test_maxima_menor_encolhe_a_estamina_junto() -> void:
	_estado.define_maxima(JOGADOR, 40)
	assert_eq(_estado.maxima_de(JOGADOR), 40)
	assert_eq(_estado.estamina_de(JOGADOR), 40, "ninguém carrega mais do que cabe")

func test_maxima_invalida_e_ignorada() -> void:
	_estado.define_maxima(JOGADOR, 0)
	assert_eq(_estado.maxima_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"corpo com capacidade zero seria desmaio permanente")


# --- Restaurar de dentro do dia (wave 15.1) ---

func test_restaurar_devolve_estamina_e_o_que_ficou() -> void:
	_estado.gasta(JOGADOR, 100)
	var agora := _estado.restaura(JOGADOR, 40)
	assert_eq(agora, EstadoCorpo.ESTAMINA_PADRAO - 60, "devolve o corpo de agora")
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 60)

func test_restauro_tem_teto_na_maxima() -> void:
	_estado.gasta(JOGADOR, 10)
	_estado.restaura(JOGADOR, 999)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"ninguém carrega mais do que cabe — o resto do pão se perde")

func test_restauro_negativo_nao_cansa() -> void:
	_estado.gasta(JOGADOR, 50)
	_estado.restaura(JOGADOR, -30)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 50,
			"cansar é assunto do gasto, nunca de um restauro negativo")

## O corpo é burro: quem decide que desmaiado não come é o sistema. Aqui, se
## mandarem restaurar, restaura — senão a regra existiria em dois lugares.
func test_restaurar_nao_pergunta_se_o_corpo_esta_no_chao() -> void:
	_estado.gasta(JOGADOR, EstadoCorpo.ESTAMINA_PADRAO)
	_estado.restaura(JOGADOR, 20)
	assert_eq(_estado.estamina_de(JOGADOR), 20, "a recusa é do sistema, não do state")


# --- A saciedade é contada, nunca calculada aqui ---

## O state guarda **quantas** refeições houve; que a segunda vale metade é
## tabela do `SistemaCorpo`. Mesma divisão do custo de arar.
func test_o_dia_comeca_sem_refeicao() -> void:
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0)

func test_cada_refeicao_conta_uma() -> void:
	assert_eq(_estado.registra_refeicao(JOGADOR), 1, "devolve qual refeição foi esta")
	assert_eq(_estado.registra_refeicao(JOGADOR), 2)
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 2)

func test_a_mesa_de_um_nao_enche_o_outro() -> void:
	_estado.registra_refeicao(JOGADOR)
	assert_eq(_estado.refeicoes_hoje(OUTRO), 0)

func test_zerar_limpa_a_mesa_do_dia() -> void:
	_estado.registra_refeicao(JOGADOR)
	_estado.zera_refeicoes(JOGADOR)
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0, "dia novo, mesa limpa")

func test_zerar_nao_mexe_na_estamina() -> void:
	_estado.gasta(JOGADOR, 30)
	_estado.zera_refeicoes(JOGADOR)
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 30,
			"encher é enche(), zerar a mesa é outra coisa")


# --- Save ---

func test_jogadores_saem_ordenados() -> void:
	_estado.gasta(OUTRO, 1)
	_estado.gasta(JOGADOR, 1)
	assert_eq(_estado.jogadores(), [JOGADOR, OUTRO] as Array[int],
			"a ordem é contrato: o save tem que sair igual duas vezes")

func test_snapshot_leva_estamina_e_maxima() -> void:
	_estado.gasta(JOGADOR, 60)
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]
	assert_eq(int(bloco["estamina"]), EstadoCorpo.ESTAMINA_PADRAO - 60)
	assert_eq(int(bloco["maxima"]), EstadoCorpo.ESTAMINA_PADRAO)

func test_corpo_intocado_nao_ocupa_o_save() -> void:
	assert_eq(_estado.to_dict()["jogadores"], {},
			"quem não trabalhou não escreve nada — é o que dispensa migração")

func test_ida_e_volta_pelo_save() -> void:
	_estado.gasta(JOGADOR, 75)
	_estado.define_maxima(OUTRO, 120)
	var outro := EstadoCorpo.new()
	outro.from_dict(_estado.to_dict())
	assert_eq(outro.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO - 75)
	assert_eq(outro.maxima_de(OUTRO), 120)

func test_bloco_ausente_carrega_todo_mundo_descansado() -> void:
	_estado.gasta(JOGADOR, 100)
	_estado.from_dict({})
	assert_eq(_estado.estamina_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO,
			"save de antes da wave 15 é um jogador inteiro")
	assert_eq(_estado.jogadores(), [] as Array[int])

func test_save_editado_a_mao_nao_estoura_a_maxima() -> void:
	_estado.from_dict({"jogadores": {"0": {"estamina": 9999, "maxima": 200}}})
	assert_eq(_estado.estamina_de(JOGADOR), 200, "ninguém carrega mais do que cabe")

func test_save_com_maxima_zerada_cai_no_padrao() -> void:
	_estado.from_dict({"jogadores": {"0": {"estamina": 10, "maxima": 0}}})
	assert_eq(_estado.maxima_de(JOGADOR), EstadoCorpo.ESTAMINA_PADRAO)
	assert_eq(_estado.estamina_de(JOGADOR), 10, "e o que estava dentro continua lá")

## Campo novo no bloco que já existe. Save da wave 15 não tem esta chave e cai
## no default — mesa limpa, que é o estado certo de quem acabou de acordar.
func test_a_mesa_do_dia_entra_no_save() -> void:
	_estado.registra_refeicao(JOGADOR)
	_estado.registra_refeicao(JOGADOR)
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]
	assert_eq(int(bloco["refeicoes_hoje"]), 2)

func test_save_da_wave_15_carrega_com_a_mesa_limpa() -> void:
	_estado.from_dict({"jogadores": {"0": {"estamina": 80, "maxima": 200}}})
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0,
			"campo ausente cai no default — sem migração")
	assert_eq(_estado.estamina_de(JOGADOR), 80, "e o que já existia continua lá")

func test_a_mesa_sobrevive_a_ida_e_volta() -> void:
	_estado.registra_refeicao(JOGADOR)
	var outro := EstadoCorpo.new()
	outro.from_dict(_estado.to_dict())
	assert_eq(outro.refeicoes_hoje(JOGADOR), 1,
			"salvar no meio do dia não pode devolver a refeição cheia")

func test_save_editado_a_mao_nao_tem_refeicao_negativa() -> void:
	_estado.from_dict({"jogadores": {"0": {"refeicoes_hoje": -5}}})
	assert_eq(_estado.refeicoes_hoje(JOGADOR), 0, "menos que nada não é refeição")

## Comer é o que cria a entrada de quem nunca trabalhou — e ele passa a ocupar
## uma linha no save, como quem cansou.
func test_quem_so_comeu_tambem_entra_no_save() -> void:
	_estado.registra_refeicao(JOGADOR)
	assert_eq(_estado.jogadores(), [JOGADOR] as Array[int])


# --- A cópia local das vantagens (wave 17) ---

## O corpo guarda o que **ele** cobra, não o tabuleiro inteiro: o efeito chega
## por `VantagemEscolhidaEvent` e o state dos ofícios continua fechado.

const MAOS_LEVES: String = "maos_leves"

func test_corpo_sem_vantagem_e_o_de_sempre() -> void:
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 0,
			"o default é o comportamento de antes da wave 17")

func test_guardar_vantagem_anota_o_nivel() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 1)
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 1)
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 2)
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 2)

func test_vantagem_nao_regride() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 2)
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 1)
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 2,
			"escolha comprada não volta, e evento repetido não rebaixa ninguém")

func test_vantagem_de_um_nao_e_do_outro() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 1)
	assert_eq(_estado.nivel_da_vantagem(OUTRO, MAOS_LEVES), 0)

func test_a_vantagem_entra_no_save() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 2)
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]
	assert_eq(int(bloco["vantagens"][MAOS_LEVES]), 2)

func test_save_da_wave_15_carrega_sem_vantagem() -> void:
	_estado.from_dict({"jogadores": {"0": {"estamina": 80, "maxima": 200}}})
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 0,
			"campo ausente cai no default — sem migração")
	assert_eq(_estado.estamina_de(JOGADOR), 80, "e o que já existia continua lá")

func test_a_vantagem_sobrevive_a_ida_e_volta() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 1)
	var outro := EstadoCorpo.new()
	outro.from_dict(_estado.to_dict())
	assert_eq(outro.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 1,
			"carregar o save não pode cobrar o ponto de novo")

func test_save_editado_a_mao_nao_tem_vantagem_de_nivel_zero() -> void:
	_estado.from_dict({"jogadores": {"0": {"vantagens": {MAOS_LEVES: 0}}}})
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 0)
	assert_eq(_estado.to_dict()["jogadores"]["0"]["vantagens"], {},
			"nível zero não é vantagem — não ocupa linha no save")

## O snapshot é cópia: escrever no que saiu não pode escrever no corpo.
func test_o_snapshot_nao_e_a_caderneta_viva() -> void:
	_estado.guarda_vantagem(JOGADOR, MAOS_LEVES, 1)
	var bloco: Dictionary = _estado.to_dict()["jogadores"]["0"]["vantagens"]
	bloco[MAOS_LEVES] = 99
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, MAOS_LEVES), 1)
