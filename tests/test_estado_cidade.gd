extends GutTest

## O que a cidade lembra do jogador, estabelecimento por estabelecimento.
##
## Três coisas moram aqui, e cada uma existe por uma decisão de design:
##
## - **o relógio monotônico** (`dia × 1440 + minuto`). Uma unidade só resolve "4
##   horas" e "3 dias" sem caso especial para a noite: dormir empurra o relógio
##   e a encomenda avança junto, sem ninguém escutar a virada do dia;
## - **a constância** — dias com entrega e o último dia creditado. Duas entregas
##   no mesmo dia contam uma; faltar não zera (PRINCIPIOS §6);
## - **as encomendas**, que ocupam cota desde a entrega até a **retirada**, e
##   não até ficarem prontas. É isso que faz o produto esquecido entupir o
##   estabelecimento — buscar custa o dia, e é de propósito (PRINCIPIOS §9).
##
## O state é burro: ele não sabe o que é moinho nem quanto custa moer. A taxa
## viaja **dentro** da encomenda porque o preço combinado na entrega é o que se
## paga na retirada, mesmo que o `.tres` seja rebalanceado no meio.
##
## Todo campo tem default e entra no bloco `cidade` do save por
## `to_dict`/`from_dict`.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"

var _estado: EstadoCidade


func before_each() -> void:
	_estado = EstadoCidade.new()

## Uma encomenda pronta para agendar, com números reconhecíveis no assert.
func _encomenda(item_id: String, qtd: int, qtd_entrada: int, taxa: int,
		conclusao: int) -> EstadoCidade.Encomenda:
	var enc := EstadoCidade.Encomenda.new()
	enc.item_id = item_id
	enc.qtd = qtd
	enc.qtd_entrada = qtd_entrada
	enc.taxa = taxa
	enc.minuto_conclusao = conclusao
	return enc


# --- Defaults ---

func test_cidade_nova_nao_conhece_ninguem() -> void:
	assert_eq(_estado.ids(), [], "ninguém entregou nada ainda")
	assert_eq(_estado.dias_com_entrega(MOINHO), 0)
	assert_eq(_estado.cota_usada(MOINHO), 0)
	assert_eq(_estado.encomendas(MOINHO), [])
	assert_eq(_estado.prontas(MOINHO), [])

func test_o_relogio_comeca_no_primeiro_dia_as_seis() -> void:
	assert_eq(_estado.relogio,
		EstadoCidade.minuto_monotonico(TimeState.DIA_DEFAULT, TimeState.MINUTO_DEFAULT),
		"o relógio da cidade nasce no mesmo instante que o do mundo")
	assert_eq(_estado.relogio, EstadoCidade.RELOGIO_DEFAULT)


# --- O relógio monotônico ---

## A armadilha: o relógio do mundo vira à meia-noite, mas o **dia** só vira ao
## dormir. Somando `dia × 1440 + minuto` cru, 00:00 valeria 1439 minutos a menos
## que 23:59 — o tempo andaria para trás uma vez por noite, e toda encomenda da
## madrugada ficaria pronta cedo demais.
func test_a_meia_noite_nao_faz_o_tempo_andar_para_tras() -> void:
	var antes := EstadoCidade.minuto_monotonico(1, 1439)   # d1 23:59
	var depois := EstadoCidade.minuto_monotonico(1, 0)     # d1 00:00, ainda a mesma noite
	assert_eq(depois - antes, 1, "um minuto passou, e é isso que o número tem que dizer")

func test_uma_hora_e_sessenta_minutos_em_qualquer_beirada() -> void:
	assert_eq(
		EstadoCidade.minuto_monotonico(1, 60) - EstadoCidade.minuto_monotonico(1, 1380),
		120, "23:00 até 01:00 são duas horas")

func test_o_colapso_das_duas_empurra_o_relogio_para_a_frente() -> void:
	var antes := EstadoCidade.minuto_monotonico(1, 119)    # d1 01:59
	var acordou := EstadoCidade.minuto_monotonico(2, TimeSystem.MINUTO_ACORDAR)
	assert_eq(acordou - antes, 241, "01:59 até as 06:00 do dia seguinte são 4h01")

func test_dormir_as_dez_da_noite_custa_oito_horas() -> void:
	var dormiu := EstadoCidade.minuto_monotonico(1, 1320)  # d1 22:00
	var acordou := EstadoCidade.minuto_monotonico(2, TimeSystem.MINUTO_ACORDAR)
	assert_eq(acordou - dormiu, 480, "22:00 até 06:00 são 8 horas de encomenda avançando")

## O dia útil vai das 06:00 às 01:59 e é tudo o mesmo dia — senão a segunda
## entrega da mesma noite creditaria constância duas vezes.
func test_o_dia_de_jogo_cobre_a_madrugada_inteira() -> void:
	for minuto in [360, 1320, 1439, 0, 119]:
		_estado.relogio = EstadoCidade.minuto_monotonico(3, minuto)
		assert_eq(_estado.dia_do_jogo(), 3, "%02d:%02d ainda é o dia 3" % [minuto / 60, minuto % 60])

	_estado.relogio = EstadoCidade.minuto_monotonico(4, TimeSystem.MINUTO_ACORDAR)
	assert_eq(_estado.dia_do_jogo(), 4, "acordou, virou o dia")

func test_perguntar_nao_cria_registro() -> void:
	_estado.dias_com_entrega(MOINHO)
	_estado.cota_usada(PADARIA)
	assert_eq(_estado.ids(), [],
		"leitura que cria registro encheria o save de estabelecimento nunca visitado")


# --- Constância ---

func test_uma_entrega_credita_um_dia() -> void:
	assert_true(_estado.credita_dia(MOINHO, 3), "primeiro dia com entrega")
	assert_eq(_estado.dias_com_entrega(MOINHO), 1)

func test_duas_entregas_no_mesmo_dia_contam_uma() -> void:
	_estado.credita_dia(MOINHO, 3)
	assert_false(_estado.credita_dia(MOINHO, 3),
		"volume não compra relação — constância compra (PRINCIPIOS §6)")
	assert_eq(_estado.dias_com_entrega(MOINHO), 1)

func test_faltar_nao_zera() -> void:
	_estado.credita_dia(MOINHO, 1)
	_estado.credita_dia(MOINHO, 30)
	assert_eq(_estado.dias_com_entrega(MOINHO), 2,
		"29 dias sumido e a relação continua de pé — ela não zera")

func test_a_constancia_e_por_estabelecimento() -> void:
	_estado.credita_dia(MOINHO, 1)
	assert_eq(_estado.dias_com_entrega(PADARIA), 0,
		"amizade com o moleiro não é amizade com o padeiro")


# --- Encomendas e cota ---

func test_encomenda_agendada_ocupa_cota_pela_entrada() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 3, 6, 30, 2040))
	assert_eq(_estado.cota_usada(MOINHO), 6,
		"a cota conta o que entrou, não o que vai sair")
	assert_eq(_estado.encomendas(MOINHO).size(), 1)
	assert_eq(_estado.ids(), [MOINHO], "agendar é o que cria o registro")

func test_encomenda_so_fica_pronta_quando_o_minuto_chega() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2040))

	assert_eq(_estado.conclui_ate(MOINHO, 2039).size(), 0, "faltou um minuto")
	assert_eq(_estado.prontas(MOINHO).size(), 0)

	var concluidas := _estado.conclui_ate(MOINHO, 2040)
	assert_eq(concluidas.size(), 1, "o minuto chegou")
	assert_eq(concluidas[0].item_id, "farinha")
	assert_eq(_estado.prontas(MOINHO).size(), 1)

func test_concluir_de_novo_nao_conclui_duas_vezes() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2040))
	_estado.conclui_ate(MOINHO, 2040)
	assert_eq(_estado.conclui_ate(MOINHO, 9999).size(), 0,
		"encomenda pronta não conclui de novo — senão o evento sai a cada minuto")

func test_dormir_conclui_o_que_venceu_na_noite() -> void:
	# entregou às 22:00 do dia 2 um lote de 8 horas: vence às 06:00 do dia 3
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2 * 1440 + 1320 + 480))
	# acordou no dia 3 às 06:01, sem tick nenhum durante a noite
	assert_eq(_estado.conclui_ate(MOINHO, 3 * 1440 + 361).size(), 1,
		"o relógio monotônico dispensa escutar a virada do dia")

func test_a_cota_so_libera_na_retirada() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2040))
	_estado.conclui_ate(MOINHO, 2040)
	assert_eq(_estado.cota_usada(MOINHO), 2,
		"pronta e esquecida ainda ocupa o moinho — buscar custa o dia")

	var retiradas := _estado.retira(MOINHO)
	assert_eq(retiradas.size(), 1)
	assert_eq(_estado.cota_usada(MOINHO), 0, "retirou, liberou")
	assert_eq(_estado.encomendas(MOINHO).size(), 0)

func test_retirada_nao_leva_o_que_ainda_esta_no_forno() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2040))
	_estado.agenda(MOINHO, _encomenda("farinha", 2, 4, 20, 5000))
	_estado.conclui_ate(MOINHO, 2040)

	var retiradas := _estado.retira(MOINHO)
	assert_eq(retiradas.size(), 1, "só a que ficou pronta")
	assert_eq(_estado.cota_usada(MOINHO), 4, "a outra continua ocupando cota")

func test_retirar_sem_nada_pronto_nao_mexe_em_nada() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 2040))
	assert_eq(_estado.retira(MOINHO).size(), 0)
	assert_eq(_estado.encomendas(MOINHO).size(), 1)

func test_a_fila_sai_na_ordem_em_que_entrou() -> void:
	_estado.agenda(MOINHO, _encomenda("farinha", 1, 2, 10, 5000))
	_estado.agenda(MOINHO, _encomenda("farinha", 2, 4, 20, 3000))
	var fila := _estado.encomendas(MOINHO)
	assert_eq(fila[0].minuto_conclusao, 5000,
		"a fila é ordem de chegada, não de vencimento — quem espera vê a própria vez")


# --- Cota vigente ---

func test_cota_e_escrita_pelo_sistema_e_lida_pela_tela() -> void:
	assert_eq(_estado.cota(MOINHO), 0, "sem registro, sem cota")
	_estado.define_cota(MOINHO, 10)
	assert_eq(_estado.cota(MOINHO), 10)
	assert_eq(_estado.ids(), [MOINHO], "definir cota cria o registro")


# --- Save ---

func test_snapshot_leva_relogio_constancia_e_fila() -> void:
	_estado.relogio = 4321
	_estado.credita_dia(MOINHO, 3)
	_estado.define_cota(MOINHO, 10)
	_estado.agenda(MOINHO, _encomenda("farinha", 3, 6, 30, 2040))

	var data := _estado.to_dict()
	assert_eq(int(data["relogio"]), 4321)

	var moinho: Dictionary = data["estabelecimentos"][MOINHO]
	assert_eq(int(moinho["dias_com_entrega"]), 1)
	assert_eq(int(moinho["ultimo_dia_creditado"]), 3)
	assert_eq(int(moinho["cota"]), 10)

	var enc: Dictionary = moinho["encomendas"][0]
	assert_eq(String(enc["item_id"]), "farinha")
	assert_eq(int(enc["qtd"]), 3)
	assert_eq(int(enc["qtd_entrada"]), 6)
	assert_eq(int(enc["taxa"]), 30, "o preço combinado viaja com a encomenda")
	assert_eq(int(enc["minuto_conclusao"]), 2040)
	assert_false(bool(enc["pronta"]))

func test_ida_e_volta_pelo_save_nao_perde_nada() -> void:
	_estado.relogio = 4321
	_estado.credita_dia(PADARIA, 2)
	_estado.agenda(MOINHO, _encomenda("farinha", 3, 6, 30, 2040))
	_estado.agenda(PADARIA, _encomenda("pao", 1, 2, 20, 9000))
	_estado.conclui_ate(MOINHO, 2040)

	var outro := EstadoCidade.new()
	outro.from_dict(_estado.to_dict())

	assert_eq(outro.relogio, 4321)
	assert_eq(outro.ids(), [MOINHO, PADARIA])
	assert_eq(outro.dias_com_entrega(PADARIA), 1)
	assert_eq(outro.cota_usada(MOINHO), 6, "a encomenda pronta voltou ocupando cota")
	assert_eq(outro.prontas(MOINHO).size(), 1, "e voltou pronta")
	assert_eq(outro.prontas(PADARIA).size(), 0)
	assert_eq(outro.retira(MOINHO)[0].taxa, 30)

func test_save_sem_bloco_cidade_carrega_como_partida_nova() -> void:
	_estado.credita_dia(MOINHO, 1)
	_estado.from_dict({})
	assert_eq(_estado.ids(), [], "campo ausente cai no default, é assim que bloco novo entra")
	assert_eq(_estado.relogio, EstadoCidade.RELOGIO_DEFAULT)

func test_encomenda_sem_item_e_lixo_de_save_e_nao_volta() -> void:
	_estado.from_dict({
		"estabelecimentos": {
			MOINHO: {"encomendas": [
				{"item_id": "", "qtd": 3, "qtd_entrada": 6},
				{"item_id": "farinha", "qtd": 0, "qtd_entrada": 6},
				{"item_id": "farinha", "qtd": 3, "qtd_entrada": 6, "minuto_conclusao": 2040},
			]},
		},
	})
	assert_eq(_estado.encomendas(MOINHO).size(), 1,
		"encomenda sem item ou sem saída não vira nada — só ocuparia cota para sempre")

func test_ids_saem_em_ordem_alfabetica() -> void:
	_estado.credita_dia(PADARIA, 1)
	_estado.credita_dia(MOINHO, 1)
	assert_eq(_estado.ids(), [MOINHO, PADARIA],
		"a ordem não pode depender de quem foi visitado primeiro — o save tem que sair igual")
