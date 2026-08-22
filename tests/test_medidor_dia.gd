extends GutTest

## O medidor do dia: quanto dos 15 minutos foi gasto andando, na fazenda, na
## cidade e parado.
##
## Ele existe para responder a uma pergunta de design com número em vez de
## achismo — "a cidade está longe demais?" (wave 10, "em aberto"). É por isso
## que os testes olham a contabilidade, não a tela.
##
## ## A parte que precisa ficar clara
##
## O medidor cronometra **tempo de parede da sessão**, não tempo de jogo. É
## apresentação pura: nada disso entra em `sim/`, nada disso vira evento, e
## `game.md` proíbe justamente o contrário — acumular `delta` para mexer em
## regra. Aqui o `delta` só conta quanto tempo o dev passou fazendo o quê.

var _medidor: MedidorDia


func before_each() -> void:
	_medidor = MedidorDia.new()
	autofree(_medidor)


func test_nasce_zerado() -> void:
	for categoria: String in MedidorDia.CATEGORIAS:
		assert_eq(_medidor.segundos_em(categoria), 0.0, "categoria '%s' suja" % categoria)
	assert_eq(_medidor.total(), 0.0)

func test_cada_segundo_cai_em_uma_categoria_so() -> void:
	_medidor.acumula(2.0, MedidorDia.ANDANDO)
	assert_eq(_medidor.segundos_em(MedidorDia.ANDANDO), 2.0)
	assert_eq(_medidor.segundos_em(MedidorDia.PARADO), 0.0,
		"o mesmo segundo não pode ser contado duas vezes")
	assert_eq(_medidor.total(), 2.0)

func test_o_total_e_a_soma_de_tudo() -> void:
	_medidor.acumula(1.0, MedidorDia.ANDANDO)
	_medidor.acumula(2.0, MedidorDia.NA_FAZENDA)
	_medidor.acumula(3.0, MedidorDia.NA_CIDADE)
	_medidor.acumula(4.0, MedidorDia.PARADO)
	assert_eq(_medidor.total(), 10.0)

func test_andar_ganha_do_lugar_onde_se_esta() -> void:
	# Andando na fazenda conta como ANDANDO: a pergunta que o medidor responde
	# é "quanto do dia foi deslocamento", e deslocamento na fazenda também é
	# deslocamento.
	assert_eq(_medidor.categoria_de(EstadoLocais.FAZENDA, true), MedidorDia.ANDANDO)
	assert_eq(_medidor.categoria_de(EstadoLocais.CIDADE, true), MedidorDia.ANDANDO)

func test_parado_na_fazenda_e_na_fazenda() -> void:
	assert_eq(_medidor.categoria_de(EstadoLocais.FAZENDA, false), MedidorDia.NA_FAZENDA)
	assert_eq(_medidor.categoria_de(EstadoLocais.CIDADE, false), MedidorDia.NA_CIDADE)

func test_parado_no_caminho_e_parado() -> void:
	# O caminho não é local (wave 10). Quem está nele e não anda está parado.
	assert_eq(_medidor.categoria_de("", false), MedidorDia.PARADO)

func test_a_virada_do_dia_zera_o_relogio() -> void:
	_medidor.acumula(5.0, MedidorDia.NA_FAZENDA)
	var dia := DayEndedEvent.new()
	dia.dia_encerrado = 3
	dia.dia_novo = 4

	_medidor._on_sim_event(dia)

	assert_eq(_medidor.total(), 0.0, "o dia novo começa com o cronômetro zerado")

func test_o_resumo_guarda_o_dia_que_acabou() -> void:
	_medidor.acumula(60.0, MedidorDia.NA_FAZENDA)
	_medidor.acumula(20.0, MedidorDia.ANDANDO)
	var dia := DayEndedEvent.new()
	dia.dia_encerrado = 3

	_medidor._on_sim_event(dia)

	var resumo := _medidor.ultimo_resumo()
	assert_eq(int(resumo.get("dia", 0)), 3, "o resumo é do dia que acabou")
	assert_eq(float(resumo.get(MedidorDia.NA_FAZENDA, 0.0)), 60.0)
	assert_eq(float(resumo.get(MedidorDia.ANDANDO, 0.0)), 20.0)

func test_o_resumo_de_vendas_entra_junto() -> void:
	# "Mostra o resumo ao dormir junto do resumo de vendas" — as duas metades
	# chegam em eventos diferentes e o painel junta as duas.
	var venda := ItemsSoldEvent.new()
	venda.linhas = [ItemsSoldEvent.Linha.new("cenoura", 3, 35)] as Array[ItemsSoldEvent.Linha]
	venda.total = 105
	venda.total_itens = 3
	_medidor._on_sim_event(venda)

	var dia := DayEndedEvent.new()
	dia.dia_encerrado = 2
	_medidor._on_sim_event(dia)

	var resumo := _medidor.ultimo_resumo()
	assert_eq(int(resumo.get("vendas_total", -1)), 105, "o dinheiro do dia sumiu do resumo")
	assert_eq((resumo.get("vendas_linhas", []) as Array).size(), 1)

func test_a_venda_de_ontem_nao_vaza_para_hoje() -> void:
	var venda := ItemsSoldEvent.new()
	venda.total = 105
	_medidor._on_sim_event(venda)
	_medidor._on_sim_event(DayEndedEvent.new())

	# Dorme de novo, sem ter vendido nada.
	var outro := DayEndedEvent.new()
	outro.dia_encerrado = 4
	_medidor._on_sim_event(outro)

	assert_eq(int(_medidor.ultimo_resumo().get("vendas_total", -1)), 0,
		"dia sem venda tem que mostrar zero, não o total de ontem")

func test_a_porcentagem_e_do_total_do_dia() -> void:
	_medidor.acumula(30.0, MedidorDia.ANDANDO)
	_medidor.acumula(70.0, MedidorDia.NA_FAZENDA)
	assert_almost_eq(_medidor.fracao_de(MedidorDia.ANDANDO), 0.30, 0.001)

func test_dia_vazio_nao_divide_por_zero() -> void:
	assert_eq(_medidor.fracao_de(MedidorDia.ANDANDO), 0.0)
