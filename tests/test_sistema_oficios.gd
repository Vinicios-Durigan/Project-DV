extends GutTest

## A árvore do jogador: trabalhar ensina, ensinar sobe nível, e o nível vira
## ponto que compra vantagem — uma vez só, para sempre.
##
## ## XP é o custo de estamina
##
## Arar dá 4, regar 2, derrubar árvore 12: a mesma tabela do `SistemaCorpo`, lida
## de lá, sem uma segunda fonte de verdade. O que cansa mais ensina mais, e o
## freio do grind não é uma regra nova — é o corpo e o relógio, que já cobram
## cada gesto.
##
## ## Ele reage, não valida trabalho
##
## Pela mesma razão do corpo: XP só entra por evento consumado, então ação
## recusada não ensina ninguém. A única ação que passa por aqui é a compra.
##
## ## Ponto preso no ofício, escolha permanente
##
## Ponto de Lavoura só compra vantagem de Lavoura, e vantagem comprada não volta.
## É o que faz o ponto pesar na hora de gastar (PRINCIPIOS §7) e o que obriga a
## variar o trabalho para abrir o tabuleiro inteiro.

const JOGADOR: int = SimFactory.PLAYER_PADRAO
const OUTRO: int = 1

var _estado: EstadoOficios
var _crops: CropCatalog
var _sistema: SistemaOficios


func before_each() -> void:
	_estado = EstadoOficios.new()
	_crops = _catalogo()
	_sistema = SistemaOficios.new(_estado, _crops)

## Culturas de mentira: o tabuleiro não pode depender do conteúdo do jogo para
## ser testado.
func _catalogo() -> CropCatalog:
	var catalogo := CropCatalog.new()
	catalogo.register(_cultura("nabo_de_teste"))
	catalogo.register(_cultura("melao_de_teste"))
	return catalogo

func _cultura(id: String) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.nome = id
	return def


# --- Fabriquinhas de evento, como a sim os emite ---

func _arou(player_id: int = JOGADOR) -> PlotTilledEvent:
	var evento := PlotTilledEvent.new()
	evento.player_id = player_id
	return evento

func _regou() -> PlotWateredEvent:
	var evento := PlotWateredEvent.new()
	evento.player_id = JOGADOR
	return evento

func _plantou() -> CropPlantedEvent:
	var evento := CropPlantedEvent.new()
	evento.player_id = JOGADOR
	evento.crop_id = "nabo_de_teste"
	return evento

func _colheu() -> CropHarvestedEvent:
	var evento := CropHarvestedEvent.new()
	evento.player_id = JOGADOR
	evento.crop_id = "nabo_de_teste"
	return evento

func _limpou(de: String) -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.player_id = JOGADOR
	evento.de = de
	evento.para = EstadoTerreno.LIVRE
	evento.motivo = TerrenoMudouEvent.POR_LIMPEZA
	return evento

func _noite() -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.de = EstadoTerreno.LIVRE
	evento.para = EstadoTerreno.MATO
	evento.motivo = TerrenoMudouEvent.POR_INVASAO
	return evento

## Trabalha até o ofício ter `quantos` pontos disponíveis.
func _pontos_de_lavoura(quantos: int) -> void:
	while _sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA) < quantos:
		_sistema.react(_arou())

func _pontos_de_campo(quantos: int) -> void:
	while _sistema.pontos_de(JOGADOR, SistemaOficios.CAMPO) < quantos:
		_sistema.react(_limpou(EstadoTerreno.ARVORE))

## Compra pela porta da frente, como o `SimWorld` oferece a ação.
func _compra(vantagem_id: String, cultura: String = "") -> Array[SimEvent]:
	var acao := EscolherVantagemAction.new()
	acao.player_id = JOGADOR
	acao.vantagem_id = vantagem_id
	acao.cultura = cultura
	return _sistema.handle(acao)

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null


# --- A tabela de XP é a do corpo ---

func test_xp_do_trabalho_e_o_custo_de_estamina() -> void:
	assert_eq(_sistema.xp_do_trabalho(SistemaCorpo.ARAR), SistemaCorpo.CUSTO_ARAR,
			"a tabela é a mesma — o que cansa mais ensina mais")
	assert_eq(_sistema.xp_do_trabalho(SistemaCorpo.LIMPAR_ARVORE),
			SistemaCorpo.CUSTO_LIMPAR_ARVORE)

func test_trabalho_desconhecido_nao_ensina() -> void:
	assert_eq(_sistema.xp_do_trabalho("pescar"), 0,
			"mecânica que ainda não existe não pode dar nível")


# --- O trabalho ensina ---

func test_arar_da_xp_de_lavoura() -> void:
	var eventos := _sistema.react(_arou())
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.LAVOURA), SistemaCorpo.CUSTO_ARAR)
	var ganhou := _primeiro(eventos, ExperienciaGanhaEvent) as ExperienciaGanhaEvent
	assert_not_null(ganhou, "todo XP ganho é fato consumado, e fato consumado é evento")
	assert_eq(ganhou.oficio, SistemaOficios.LAVOURA)
	assert_eq(ganhou.trabalho, SistemaCorpo.ARAR)
	assert_eq(ganhou.xp, SistemaCorpo.CUSTO_ARAR)

func test_o_ciclo_do_canteiro_todo_e_lavoura() -> void:
	_sistema.react(_regou())
	_sistema.react(_plantou())
	_sistema.react(_colheu())
	var esperado := (SistemaCorpo.CUSTO_REGAR + SistemaCorpo.CUSTO_PLANTAR
			+ SistemaCorpo.CUSTO_COLHER)
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.LAVOURA), esperado)
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.CAMPO), 0,
			"quem cuida do canteiro não fica bom em derrubar árvore")

func test_limpar_da_xp_de_campo() -> void:
	_sistema.react(_limpou(EstadoTerreno.PEDRA))
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.CAMPO),
			SistemaCorpo.CUSTO_LIMPAR_PEDRA)
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.LAVOURA), 0)

## O mato que invadiu e o arado que fechou são trabalho da noite — e a noite não
## ensina ninguém, pelo mesmo motivo de não cansar ninguém.
func test_a_noite_nao_ensina() -> void:
	_sistema.react(_noite())
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.CAMPO), 0)

func test_cada_jogador_tem_a_propria_caderneta() -> void:
	_sistema.react(_arou(OUTRO))
	assert_eq(_sistema.xp_de(JOGADOR, SistemaOficios.LAVOURA), 0,
			"a prática de um não ensina o outro")
	assert_eq(_sistema.xp_de(OUTRO, SistemaOficios.LAVOURA), SistemaCorpo.CUSTO_ARAR)


# --- Os níveis ---

func test_o_dia_um_e_nivel_zero() -> void:
	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.LAVOURA), 0)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 0)

func test_cruzar_o_limiar_sobe_o_nivel_e_credita_um_ponto() -> void:
	var eventos: Array[SimEvent] = []
	while _sistema.nivel_de(JOGADOR, SistemaOficios.LAVOURA) < 1:
		eventos = _sistema.react(_arou())

	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.LAVOURA), 1)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 1,
			"cada nível dá um ponto")
	var subiu := _primeiro(eventos, OficioSubiuEvent) as OficioSubiuEvent
	assert_not_null(subiu, "subir de nível é o fato que a tela comemora")
	assert_eq(subiu.oficio, SistemaOficios.LAVOURA)
	assert_eq(subiu.de, 0)
	assert_eq(subiu.para, 1)
	assert_eq(subiu.pontos, 1)

func test_o_nivel_um_de_lavoura_custa_o_limiar_da_tabela() -> void:
	var limiar: int = SistemaOficios.LIMIARES_LAVOURA[0]
	while _sistema.xp_de(JOGADOR, SistemaOficios.LAVOURA) < limiar:
		_sistema.react(_arou())
	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.LAVOURA), 1,
			"bater o limiar é subir")

func test_campo_sobe_mais_barato_que_lavoura() -> void:
	assert_lt(SistemaOficios.LIMIARES_CAMPO[0], SistemaOficios.LIMIARES_LAVOURA[0],
			"pedra e árvore não voltam: a fonte é quase finita e a escada é menor")

## Um salto pode cruzar dois limiares de uma vez, e a escada não pode engolir o
## ponto do meio. Com a tabela de hoje o maior golpe (12) não alcança o vão de 30
## para 80, então o cenário se monta pelo state — que é exatamente a situação de
## um save carregado com XP adiante do nível.
func test_pulo_de_dois_niveis_credita_dois_pontos() -> void:
	var vespera: int = SistemaOficios.LIMIARES_CAMPO[1] - SistemaCorpo.CUSTO_LIMPAR_ARVORE
	_estado.soma_xp(JOGADOR, SistemaOficios.CAMPO, vespera)
	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.CAMPO), 0,
			"o state guarda XP; quem cruza limiar é o sistema")

	var eventos := _sistema.react(_limpou(EstadoTerreno.ARVORE))
	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.CAMPO), 2)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.CAMPO), 2,
			"dois níveis, dois pontos — a escada não engole nenhum")
	var subiu := _primeiro(eventos, OficioSubiuEvent) as OficioSubiuEvent
	assert_eq(subiu.de, 0)
	assert_eq(subiu.para, 2, "e um evento só conta o salto inteiro")
	assert_eq(subiu.pontos, 2)

func test_o_nivel_para_no_topo_da_tabela() -> void:
	for _i in 400:
		_sistema.react(_limpou(EstadoTerreno.ARVORE))
	assert_eq(_sistema.nivel_de(JOGADOR, SistemaOficios.CAMPO),
			SistemaOficios.LIMIARES_CAMPO.size(),
			"o topo da tabela é o teto — XP a mais não vira ponto infinito")
	assert_eq(_sistema.pontos_ganhos(JOGADOR, SistemaOficios.CAMPO),
			SistemaOficios.LIMIARES_CAMPO.size())


# --- O tabuleiro ---

func test_o_tabuleiro_so_oferece_vantagem_com_efeito() -> void:
	var todas := (_sistema.vantagens_do_oficio(SistemaOficios.LAVOURA)
			+ _sistema.vantagens_do_oficio(SistemaOficios.CAMPO))
	assert_eq(todas.size(), 4,
			"comprar vantagem morta é pior que não vendê-la — o resto entra na 17.1")
	assert_true(todas.has(SistemaOficios.MAOS_LEVES))
	assert_true(todas.has(SistemaOficios.REGA_FUNDA))
	assert_true(todas.has(SistemaOficios.COLHEITA_ESPECIALIZADA))
	assert_true(todas.has(SistemaOficios.COSTAS_LARGAS))

func test_cada_vantagem_sabe_seu_oficio_custo_e_teto() -> void:
	assert_eq(_sistema.oficio_da_vantagem(SistemaOficios.MAOS_LEVES),
			SistemaOficios.LAVOURA)
	assert_eq(_sistema.custo_da_vantagem(SistemaOficios.MAOS_LEVES), 1)
	assert_eq(_sistema.teto_da_vantagem(SistemaOficios.MAOS_LEVES), 2)
	assert_eq(_sistema.oficio_da_vantagem(SistemaOficios.COSTAS_LARGAS),
			SistemaOficios.CAMPO)

## A tensão que a wave quer: escolher uma coisa é abrir mão de outra. Ela vale
## dentro do ofício, que é onde o ponto está preso — a Lavoura inteira custa mais
## do que a Lavoura inteira dá, então nenhum ramo se compra sozinho.
##
## O tabuleiro só fecha na 17.1, quando as outras quatro vantagens ganharem dono:
## com as quatro desta fatia, 8 pontos empatam com 8 de custo, e quem maximizar
## os dois ofícios leva tudo. É o número a conferir na estação jogada.
func test_o_ramo_custa_mais_do_que_o_oficio_da() -> void:
	var custo_da_lavoura := 0
	for vantagem_id in _sistema.vantagens_do_oficio(SistemaOficios.LAVOURA):
		custo_da_lavoura += (_sistema.custo_da_vantagem(vantagem_id)
				* _sistema.teto_da_vantagem(vantagem_id))
	assert_gt(custo_da_lavoura, _sistema.nivel_maximo(SistemaOficios.LAVOURA),
			"nem o próprio ramo dá para ter inteiro — é o que faz o ponto pesar")


# --- Comprar ---

func test_comprar_gasta_o_ponto_e_marca_a_vantagem() -> void:
	_pontos_de_lavoura(1)
	var eventos := _compra(SistemaOficios.MAOS_LEVES)

	assert_eq(_sistema.nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 1)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 0, "o ponto foi")
	var escolheu := _primeiro(eventos, VantagemEscolhidaEvent) as VantagemEscolhidaEvent
	assert_not_null(escolheu, "quem cobra o efeito só sabe pelo evento")
	assert_eq(escolheu.vantagem_id, SistemaOficios.MAOS_LEVES)
	assert_eq(escolheu.oficio, SistemaOficios.LAVOURA)
	assert_eq(escolheu.nivel, 1)
	assert_eq(escolheu.custo, 1)
	assert_eq(escolheu.pontos_restantes, 0)

func test_comprar_de_novo_sobe_o_nivel_da_vantagem() -> void:
	_pontos_de_lavoura(2)
	_compra(SistemaOficios.MAOS_LEVES)
	var eventos := _compra(SistemaOficios.MAOS_LEVES)
	assert_eq(_sistema.nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 2)
	var escolheu := _primeiro(eventos, VantagemEscolhidaEvent) as VantagemEscolhidaEvent
	assert_eq(escolheu.nivel, 2, "o evento conta o nível novo, não o total gasto")

func test_vantagem_no_teto_e_recusada() -> void:
	_pontos_de_lavoura(3)
	_compra(SistemaOficios.MAOS_LEVES)
	_compra(SistemaOficios.MAOS_LEVES)
	var eventos := _compra(SistemaOficios.MAOS_LEVES)

	assert_eq(_sistema.nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 2,
			"o teto é o teto")
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 1,
			"e a recusa não pode cobrar o ponto")
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_not_null(recusa)
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_NO_TETO)

func test_sem_ponto_nao_compra() -> void:
	var eventos := _compra(SistemaOficios.MAOS_LEVES)
	assert_eq(_sistema.nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 0)
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_SEM_PONTO)

func test_vantagem_desconhecida_e_recusada() -> void:
	_pontos_de_lavoura(1)
	var eventos := _compra("voar")
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_VANTAGEM_DESCONHECIDA)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 1)

## O coração da wave: ponto de um ofício não abre o tabuleiro do outro.
func test_ponto_de_lavoura_nao_compra_vantagem_de_campo() -> void:
	_pontos_de_lavoura(2)
	var eventos := _compra(SistemaOficios.COSTAS_LARGAS)

	assert_eq(_sistema.nivel_da_vantagem(JOGADOR, SistemaOficios.COSTAS_LARGAS), 0,
			"você fica bom no que pratica")
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 2)
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_SEM_PONTO)

func test_vantagem_de_dois_pontos_cobra_dois() -> void:
	_pontos_de_campo(2)
	_compra(SistemaOficios.COSTAS_LARGAS)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.CAMPO), 1,
			"Costas largas custa 1; sobra o que sobrou")
	assert_eq(_sistema.gastos_de(JOGADOR, SistemaOficios.CAMPO), 1)

func test_a_acao_recusada_fica_carimbada() -> void:
	var acao := EscolherVantagemAction.new()
	acao.player_id = JOGADOR
	acao.vantagem_id = SistemaOficios.MAOS_LEVES
	_sistema.handle(acao)
	assert_true(acao.rejeitada,
			"validação em cadeia: quem detecta a impossibilidade carimba")

func test_acao_ja_rejeitada_e_ignorada() -> void:
	_pontos_de_lavoura(1)
	var acao := EscolherVantagemAction.new()
	acao.player_id = JOGADOR
	acao.vantagem_id = SistemaOficios.MAOS_LEVES
	acao.rejeitada = true
	assert_eq(_sistema.handle(acao), [] as Array[SimEvent])
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 1,
			"ação recusada antes não pode cobrar nada aqui")


# --- A especialização ---

func test_especializar_carimba_a_cultura() -> void:
	_pontos_de_lavoura(2)
	var eventos := _compra(SistemaOficios.COLHEITA_ESPECIALIZADA, "nabo_de_teste")

	assert_eq(_sistema.cultura_de(JOGADOR), "nabo_de_teste")
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 0, "custa dois")
	var escolheu := _primeiro(eventos, VantagemEscolhidaEvent) as VantagemEscolhidaEvent
	assert_eq(escolheu.cultura, "nabo_de_teste",
			"o evento leva a cultura — quem soma o +1 é o FarmSystem")

func test_especializar_sem_cultura_e_recusado() -> void:
	_pontos_de_lavoura(2)
	var eventos := _compra(SistemaOficios.COLHEITA_ESPECIALIZADA)
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_CULTURA_AUSENTE)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 2)

## Escolha permanente + cultura inexistente seria dois pontos queimados para
## sempre, num erro de digitação. Mesma razão de `pode_comer()` existir.
func test_especializar_em_cultura_que_nao_existe_e_recusado() -> void:
	_pontos_de_lavoura(2)
	var eventos := _compra(SistemaOficios.COLHEITA_ESPECIALIZADA, "banana")
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_CULTURA_DESCONHECIDA)
	assert_eq(_sistema.pontos_de(JOGADOR, SistemaOficios.LAVOURA), 2)

func test_a_cultura_escolhida_nao_troca() -> void:
	_pontos_de_lavoura(4)
	_compra(SistemaOficios.COLHEITA_ESPECIALIZADA, "nabo_de_teste")
	var eventos := _compra(SistemaOficios.COLHEITA_ESPECIALIZADA, "melao_de_teste")
	assert_eq(_sistema.cultura_de(JOGADOR), "nabo_de_teste",
			"escolha permanente: a especialização é de uma cultura só, e ela não volta")
	var recusa := _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent
	assert_eq(recusa.motivo, SistemaOficios.MOTIVO_NO_TETO)


# --- Consultas para a tela (game/ nunca calcula) ---

func test_pergunta_antes_de_comprar() -> void:
	assert_false(_sistema.pode_comprar(JOGADOR, SistemaOficios.MAOS_LEVES),
			"a aba pergunta antes de oferecer o botão")
	_pontos_de_lavoura(1)
	assert_true(_sistema.pode_comprar(JOGADOR, SistemaOficios.MAOS_LEVES))

func test_a_recusa_tem_motivo_antes_do_clique() -> void:
	assert_eq(_sistema.recusa_de(JOGADOR, SistemaOficios.MAOS_LEVES),
			SistemaOficios.MOTIVO_SEM_PONTO,
			"a tela mostra o porquê sem inventar a regra")

func test_o_xp_que_falta_para_o_proximo_nivel() -> void:
	assert_eq(_sistema.xp_do_nivel(SistemaOficios.LAVOURA, 1),
			SistemaOficios.LIMIARES_LAVOURA[0])
	_sistema.react(_arou())
	assert_eq(_sistema.xp_para_o_proximo(JOGADOR, SistemaOficios.LAVOURA),
			SistemaOficios.LIMIARES_LAVOURA[0] - SistemaCorpo.CUSTO_ARAR)

func test_a_fracao_da_barra_e_conta_de_regra() -> void:
	assert_almost_eq(_sistema.fracao_do_nivel(JOGADOR, SistemaOficios.LAVOURA),
			0.0, 0.001)
	while _sistema.nivel_de(JOGADOR, SistemaOficios.LAVOURA) < 1:
		_sistema.react(_arou())
	assert_lt(_sistema.fracao_do_nivel(JOGADOR, SistemaOficios.LAVOURA), 1.0,
			"nível novo recomeça a barra, não a deixa cheia")

func test_no_topo_a_barra_fica_cheia() -> void:
	for _i in 400:
		_sistema.react(_limpou(EstadoTerreno.ARVORE))
	assert_almost_eq(_sistema.fracao_do_nivel(JOGADOR, SistemaOficios.CAMPO),
			1.0, 0.001, "sem próximo nível, a barra não pode ficar vazia para sempre")
	assert_eq(_sistema.xp_para_o_proximo(JOGADOR, SistemaOficios.CAMPO), 0)

func test_o_estado_e_o_mesmo_que_o_sistema_escreve() -> void:
	_pontos_de_lavoura(1)
	_compra(SistemaOficios.MAOS_LEVES)
	assert_eq(_sistema.get_state(), _estado, "um dono por state")
	assert_eq(_estado.nivel_da_vantagem(JOGADOR, SistemaOficios.MAOS_LEVES), 1)
