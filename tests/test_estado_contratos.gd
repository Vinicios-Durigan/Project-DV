extends GutTest

## O que o `SistemaContratos` lembra — um contrato ativo por estabelecimento.
##
## Duas coisas moram aqui:
##
## - **o contrato**, que nasce oferecido, pode virar aceito e some quando
##   termina. Cumprido e falho **não ficam** no state: o evento carrega tudo o
##   que a tela precisa, e histórico no save só engordaria o arquivo;
## - **a constância conhecida** — a cópia de `dias_com_entrega` que chega pelo
##   `RelacaoSubiuEvent`. O sistema que pede não lê o state de quem vende
##   (regra da wave 02), então ele guarda o número no próprio state.
##
## `minuto_limite` é o mesmo campo nas duas fases da vida do contrato: enquanto
## oferecido é o prazo para **responder**, depois de aceito é o prazo para
## **cumprir**. Um campo só porque as duas datas nunca coexistem — aceitar
## reescreve o limite.
##
## A semente do RNG mora aqui e entra no save: mesmo save, mesma sequência de
## ofertas (decisão herdada da wave 09).

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _estado: EstadoContratos


func before_each() -> void:
	_estado = EstadoContratos.new()

## Um contrato pronto para oferecer, com números reconhecíveis no assert.
func _contrato(estabelecimento: String, item_id: String, qtd: int,
		pagamento: int, limite: int) -> EstadoContratos.Contrato:
	var con := EstadoContratos.Contrato.new()
	con.estabelecimento = estabelecimento
	con.item_id = item_id
	con.qtd = qtd
	con.pagamento = pagamento
	con.minuto_limite = limite
	return con


# --- Defaults ---

func test_nasce_sem_contrato_nenhum() -> void:
	assert_eq(_estado.ids(), [] as Array[String], "cidade nova não tem contrato")
	assert_false(_estado.tem_contrato(MOINHO), "o moinho ainda não pediu nada")
	assert_null(_estado.contrato(MOINHO), "sem contrato, sem ficha")

func test_nasce_com_a_semente_padrao() -> void:
	assert_eq(_estado.semente, EstadoContratos.SEMENTE_PADRAO,
			"a semente tem default — sorteio determinístico desde o boot")

func test_constancia_desconhecida_vale_zero() -> void:
	assert_eq(_estado.dias(MOINHO), 0,
			"estabelecimento de quem nunca ouvimos falar tem zero dia")

func test_o_relogio_comeca_junto_com_o_da_cidade() -> void:
	assert_eq(_estado.relogio, EstadoCidade.RELOGIO_DEFAULT,
			"dia 1 às 06:00 — os dois relógios saem do mesmo instante")

func test_o_dia_do_jogo_sai_do_relogio() -> void:
	_estado.relogio = EstadoCidade.minuto_monotonico(3, 720)
	assert_eq(_estado.dia_do_jogo(), 3, "meio-dia do dia 3")

func test_a_madrugada_ainda_e_o_dia_anterior() -> void:
	_estado.relogio = EstadoCidade.minuto_monotonico(3, 30)
	assert_eq(_estado.dia_do_jogo(), 3,
			"00:30 é a noite do dia 3 — senão o sorteio pularia um dia")


# --- Oferta ---

func test_oferece_guarda_o_contrato_do_estabelecimento() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	var con := _estado.contrato(MOINHO)
	assert_not_null(con, "o contrato oferecido fica guardado")
	assert_eq(con.item_id, "trigo", "o item pedido")
	assert_eq(con.qtd, 4, "a quantidade pedida")
	assert_eq(con.pagamento, 210, "o que ele paga")
	assert_false(con.aceito, "oferta nasce sem resposta")

func test_oferece_nao_atropela_contrato_que_ja_existe() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.oferece(_contrato(MOINHO, "trigo", 99, 999, 9999))
	assert_eq(_estado.contrato(MOINHO).qtd, 4,
			"um contrato ativo por estabelecimento — o segundo não entra")

func test_oferece_ignora_contrato_nulo() -> void:
	_estado.oferece(null)
	assert_eq(_estado.ids(), [] as Array[String], "nulo não vira ficha")

func test_cada_estabelecimento_tem_o_seu() -> void:
	_estado.oferece(_contrato(PADARIA, "farinha", 2, 180, 4320))
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	assert_eq(_estado.ids(), [MOINHO, PADARIA] as Array[String],
			"ids em ordem alfabética — o save tem que sair igual")


# --- Aceite ---

func test_aceitar_marca_e_reescreve_o_limite() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	assert_true(_estado.aceita(MOINHO, 8640), "aceitou")
	var con := _estado.contrato(MOINHO)
	assert_true(con.aceito, "o contrato agora é compromisso")
	assert_eq(con.minuto_limite, 8640,
			"o prazo de responder deu lugar ao prazo de cumprir")

func test_aceitar_duas_vezes_nao_estica_o_prazo() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.aceita(MOINHO, 8640)
	assert_false(_estado.aceita(MOINHO, 99999), "já estava aceito")
	assert_eq(_estado.contrato(MOINHO).minuto_limite, 8640,
			"o limite não se mexe — senão bastaria reclicar para ganhar prazo")

func test_aceitar_o_que_nao_existe_e_no_op() -> void:
	assert_false(_estado.aceita(MOINHO, 8640), "não há o que aceitar")
	assert_false(_estado.tem_contrato(MOINHO), "e nada foi criado")


# --- Fim ---

func test_encerrar_devolve_e_tira_da_ficha() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	var con := _estado.encerra(MOINHO)
	assert_not_null(con, "quem encerra recebe o contrato para montar o evento")
	assert_eq(con.qtd, 4, "é o contrato que estava lá")
	assert_false(_estado.tem_contrato(MOINHO),
			"cumprido ou falho não fica no state — o evento leva o que interessa")

func test_encerrar_o_que_nao_existe_devolve_nulo() -> void:
	assert_null(_estado.encerra(MOINHO), "nada a encerrar")


# --- Vencimento ---

func test_vencidos_pega_oferta_e_compromisso_no_limite() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.oferece(_contrato(PADARIA, "farinha", 2, 180, 5000))
	var vencidos := _estado.vencidos_ate(4320)
	assert_eq(vencidos.size(), 1, "só o do moinho chegou no limite")
	assert_eq(vencidos[0].estabelecimento, MOINHO, "e é ele mesmo")

func test_vencidos_sai_em_ordem_alfabetica() -> void:
	_estado.oferece(_contrato(PADARIA, "farinha", 2, 180, 4320))
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	var vencidos := _estado.vencidos_ate(9999)
	assert_eq(vencidos[0].estabelecimento, MOINHO,
			"a ordem dos eventos não pode depender de quem sorteou primeiro")

func test_vencidos_nao_tira_ninguem_da_ficha() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.vencidos_ate(4320)
	assert_true(_estado.tem_contrato(MOINHO),
			"quem lê não escreve — encerrar é decisão do sistema")


# --- Constância conhecida ---

func test_define_dias_guarda_a_copia_da_constancia() -> void:
	_estado.define_dias(MOINHO, 7)
	assert_eq(_estado.dias(MOINHO), 7,
			"o número chega pelo RelacaoSubiuEvent e fica guardado aqui")

func test_define_dias_nunca_fica_negativo() -> void:
	_estado.define_dias(MOINHO, -3)
	assert_eq(_estado.dias(MOINHO), 0, "constância não é dívida")


# --- Save ---

func test_ida_e_volta_preserva_tudo() -> void:
	_estado.semente = 4242
	_estado.relogio = EstadoCidade.minuto_monotonico(5, 600)
	_estado.define_dias(MOINHO, 7)
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.aceita(MOINHO, 8640)

	var outro := EstadoContratos.new()
	outro.from_dict(_estado.to_dict())

	assert_eq(outro.semente, 4242, "a semente viaja — o sorteio continua igual")
	assert_eq(outro.relogio, EstadoCidade.minuto_monotonico(5, 600),
			"o relógio viaja — aceitar logo após carregar conta o prazo de agora")
	assert_eq(outro.dias(MOINHO), 7, "a constância conhecida viaja")
	var con := outro.contrato(MOINHO)
	assert_not_null(con, "o contrato viaja")
	assert_eq(con.item_id, "trigo", "com o item")
	assert_eq(con.qtd, 4, "com a quantidade")
	assert_eq(con.pagamento, 210, "com o pagamento combinado")
	assert_true(con.aceito, "e sabendo que já foi aceito")
	assert_eq(con.minuto_limite, 8640, "com o prazo de cumprir")

func test_bloco_vazio_cai_nos_defaults() -> void:
	_estado.oferece(_contrato(MOINHO, "trigo", 4, 210, 4320))
	_estado.from_dict({})
	assert_eq(_estado.semente, EstadoContratos.SEMENTE_PADRAO, "semente padrão")
	assert_false(_estado.tem_contrato(MOINHO),
			"save sem o bloco é save de antes da wave 13 — nasce sem contrato")

func test_contrato_sem_item_e_lixo_de_save() -> void:
	_estado.from_dict({
		"semente": 1,
		"contratos": {MOINHO: {"item_id": "", "qtd": 4}},
	})
	assert_false(_estado.tem_contrato(MOINHO),
			"contrato sem item nunca poderia ser cumprido — some")

func test_contrato_sem_quantidade_e_lixo_de_save() -> void:
	_estado.from_dict({
		"semente": 1,
		"contratos": {MOINHO: {"item_id": "trigo", "qtd": 0}},
	})
	assert_false(_estado.tem_contrato(MOINHO), "pedido de zero unidade não é pedido")

func test_from_dict_ignora_entrada_que_nao_e_dicionario() -> void:
	_estado.from_dict({"contratos": {MOINHO: "trigo"}})
	assert_false(_estado.tem_contrato(MOINHO), "lixo não vira contrato")

func test_o_estabelecimento_vem_da_chave_do_save() -> void:
	_estado.from_dict({
		"contratos": {MOINHO: {"item_id": "trigo", "qtd": 4, "pagamento": 210}},
	})
	assert_eq(_estado.contrato(MOINHO).estabelecimento, MOINHO,
			"quem é o dono está na chave, não repetido dentro do bloco")
