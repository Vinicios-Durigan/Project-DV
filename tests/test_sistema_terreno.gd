extends GutTest

## O terreno: entulho que trava a expansão, e mato que volta se você preparou
## mais chão do que dá conta.
##
## ## O que esta wave conserta
##
## Arar → plantar → regar → colher era uma sequência linear onde nada podia dar
## errado (PRINCIPIOS §7). O espaço não era escasso e o layout não importava.
## Aqui o chão vira recurso: limpar custa golpe, e o que você limpa e não usa o
## mato toma de volta.
##
## ## Propagação, não chance por tile
##
## "2% de nascer mato em cada quadrado livre" transformaria a fazenda em
## manutenção — o jogador varrendo o mapa atrás de ruído que apareceu sozinho.
## Aqui o mato só nasce **encostado em mato**, então limpar em bloco compacto se
## defende sozinho e limpar espalhado deixa você cercado. O layout da limpeza
## vira decisão de longo prazo, sem arte nova.
##
## ## Determinístico depois de criado
##
## A semente mora no save. Duas partidas com a mesma semente têm a mesma
## fazenda e a mesma sequência de invasões — replay e bug report continuam
## confiáveis.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _estado: EstadoTerreno
var _farm: FarmState
var _items: ItemCatalog
var _sistema: SistemaTerreno


func before_each() -> void:
	_estado = EstadoTerreno.new()
	_farm = FarmState.new()
	_items = ItemCatalog.new()
	_items.register(_ferramenta("enxada", [EstadoTerreno.MATO]))
	_items.register(_ferramenta("picareta", [EstadoTerreno.PEDRA]))
	_items.register(_ferramenta("machado", [EstadoTerreno.ARVORE, EstadoTerreno.TOCO]))
	_items.register(_ferramenta("regador", []))
	_sistema = SistemaTerreno.new(_estado, _farm, _items)

func _ferramenta(id: String, alvos: Array[String]) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = id
	def.alvos_de_limpeza = alvos
	return def

func _limpa(x: int, y: int, item_id: String) -> Array[SimEvent]:
	var acao := LimparTerrenoAction.new()
	acao.player_id = JOGADOR
	acao.x = x
	acao.y = y
	acao.item_id = item_id
	return _sistema.handle(acao)

## A virada do dia, como o `TimeSystem` a emite.
func _vira_o_dia(dia: int) -> Array[SimEvent]:
	var evento := DayEndedEvent.new()
	evento.dia_novo = dia
	return _sistema.react(evento)

## Um tile arado e vazio — o que o mato toma de volta.
func _arado_vazio(x: int, y: int) -> void:
	_farm.get_plot(x, y).arada = true

func _com_cultura(x: int, y: int) -> void:
	var plot := _farm.get_plot(x, y)
	plot.arada = true
	plot.crop_id = "rabanete"

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null

func _recusa(eventos: Array[SimEvent]) -> ActionRejectedEvent:
	return _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent

func _mudancas(eventos: Array[SimEvent]) -> Array[TerrenoMudouEvent]:
	var out: Array[TerrenoMudouEvent] = []
	for evento in eventos:
		if evento is TerrenoMudouEvent:
			out.append(evento as TerrenoMudouEvent)
	return out

func _conta(cobertura: String) -> int:
	var total := 0
	for id in _estado.ids():
		var partes := id.split(":")
		if _estado.cobertura(int(partes[0]), int(partes[1])) == cobertura:
			total += 1
	return total


# --- Limpar ---

func test_a_enxada_capina() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	var evento := _primeiro(_limpa(2, 2, "enxada"), TerrenoMudouEvent) as TerrenoMudouEvent
	assert_not_null(evento, "limpar tem evento próprio")
	assert_eq(evento.de, EstadoTerreno.MATO, "de onde saiu")
	assert_eq(evento.para, EstadoTerreno.LIVRE, "para onde foi")
	assert_eq(evento.motivo, TerrenoMudouEvent.POR_LIMPEZA, "e quem fez")
	assert_true(_estado.e_livre(2, 2), "o tile abriu")

func test_o_machado_derruba_em_dois_golpes() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.ARVORE)
	_limpa(2, 2, "machado")
	assert_eq(_estado.cobertura(2, 2), EstadoTerreno.TOCO, "primeiro cai a árvore")
	_limpa(2, 2, "machado")
	assert_true(_estado.e_livre(2, 2), "depois sai o toco")

func test_ferramenta_que_nao_serve_e_recusada() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.PEDRA)
	var recusa := _recusa(_limpa(2, 2, "enxada"))
	assert_not_null(recusa, "enxada não quebra pedra")
	assert_eq(recusa.motivo, SistemaTerreno.MOTIVO_FERRAMENTA_ERRADA, "e o motivo diz isso")
	assert_eq(_estado.cobertura(2, 2), EstadoTerreno.PEDRA, "e a pedra continua lá")

func test_ferramenta_que_nao_limpa_nada_e_recusada() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	var recusa := _recusa(_limpa(2, 2, "regador"))
	assert_not_null(recusa, "o regador não tira nada do caminho")
	assert_eq(recusa.motivo, SistemaTerreno.MOTIVO_FERRAMENTA_ERRADA)

func test_limpar_chao_limpo_e_recusado() -> void:
	var recusa := _recusa(_limpa(2, 2, "enxada"))
	assert_not_null(recusa, "não há o que tirar")
	assert_eq(recusa.motivo, SistemaTerreno.MOTIVO_NADA_A_LIMPAR)

func test_a_agua_nao_sai_com_ferramenta_nenhuma() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.AGUA)
	for ferramenta in ["enxada", "picareta", "machado"]:
		var recusa := _recusa(_limpa(2, 2, ferramenta))
		assert_not_null(recusa, "%s não seca o poço" % ferramenta)
	assert_eq(_estado.cobertura(2, 2), EstadoTerreno.AGUA)

func test_entulho_limpo_nao_volta() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.PEDRA)
	_limpa(2, 2, "picareta")
	for dia in range(2, 30):
		_vira_o_dia(dia)
	assert_ne(_estado.cobertura(2, 2), EstadoTerreno.PEDRA,
			"a pedra que você quebrou não volta na semana que vem (PRINCIPIOS §8)")

func test_pode_limpar_responde_antes_do_clique() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.PEDRA)
	assert_false(_sistema.pode_limpar(2, 2, "enxada"), "ferramenta errada")
	assert_true(_sistema.pode_limpar(2, 2, "picareta"), "ferramenta certa")
	assert_false(_sistema.pode_limpar(9, 9, "picareta"), "chão limpo")


# --- O arado que ninguém usou ---

func test_arado_vazio_fecha_depois_de_tres_dias() -> void:
	_arado_vazio(3, 3)
	var eventos: Array[SimEvent] = []
	for dia in range(2, 2 + SistemaTerreno.DIAS_PARA_FECHAR):
		eventos.append_array(_vira_o_dia(dia))
	assert_eq(_estado.cobertura(3, 3), EstadoTerreno.MATO,
			"preparo que você não usou o mato toma de volta")
	var evento := _primeiro(eventos, TerrenoMudouEvent) as TerrenoMudouEvent
	assert_eq(evento.motivo, TerrenoMudouEvent.POR_FECHAMENTO, "e o motivo distingue da invasão")

func test_arado_nao_fecha_antes_do_prazo() -> void:
	_arado_vazio(3, 3)
	_vira_o_dia(2)
	assert_true(_estado.e_livre(3, 3), "um dia parado ainda é preparo, não abandono")

func test_tile_com_cultura_nunca_fecha() -> void:
	_com_cultura(3, 3)
	for dia in range(2, 20):
		_vira_o_dia(dia)
	assert_true(_estado.e_livre(3, 3),
			"perder uma abóbora de 13 dias seria outro jogo — punição pausa, não destrói")

func test_plantar_zera_o_relogio_do_arado() -> void:
	_arado_vazio(3, 3)
	_vira_o_dia(2)
	_vira_o_dia(3)
	_com_cultura(3, 3)
	_vira_o_dia(4)
	_vira_o_dia(5)
	assert_true(_estado.e_livre(3, 3), "o contador só corre enquanto o tile está vazio")


# --- A propagação da noite ---

func test_o_mato_pula_para_um_vizinho() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	for dia in range(2, 12):
		_vira_o_dia(dia)
	assert_gt(_conta(EstadoTerreno.MATO), 1,
			"mato encostado em mato é o que faz o layout da limpeza importar")

func test_o_mato_nao_nasce_do_nada() -> void:
	for dia in range(2, 30):
		_vira_o_dia(dia)
	assert_eq(_conta(EstadoTerreno.MATO), 0,
			"sem fonte, sem mato — chance por tile viraria manutenção, não decisão")

func test_o_mato_nao_cobre_cultura() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	_com_cultura(2, 3)
	_com_cultura(3, 2)
	for dia in range(2, 30):
		_vira_o_dia(dia)
	assert_true(_estado.e_livre(2, 3), "planta em pé não vira mato")
	assert_true(_estado.e_livre(3, 2), "nem a do lado")

func test_a_noite_tem_teto_de_mudancas() -> void:
	for x in range(0, 6):
		_estado.define_cobertura(x, 0, EstadoTerreno.MATO)
	for x in range(0, 6):
		_arado_vazio(x, 4)
	var mudou := _mudancas(_vira_o_dia(2))
	assert_lte(mudou.size(), SistemaTerreno.MUDANCAS_POR_DIA,
			"sem teto, um save deixado em ×60 vira floresta")

func test_a_propagacao_e_deterministica() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	for dia in range(2, 10):
		_vira_o_dia(dia)
	var primeira := _estado.ids()

	before_each()
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	for dia in range(2, 10):
		_vira_o_dia(dia)

	assert_eq(_estado.ids(), primeira,
			"mesma semente, mesma fazenda — é o que mantém o replay confiável")

func test_semente_diferente_muda_a_fazenda() -> void:
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	for dia in range(2, 10):
		_vira_o_dia(dia)
	var com_padrao := _estado.ids()

	before_each()
	_estado.semente = 7
	_estado.define_cobertura(2, 2, EstadoTerreno.MATO)
	for dia in range(2, 10):
		_vira_o_dia(dia)

	assert_ne(_estado.ids(), com_padrao, "cada save tem a sua fazenda")


# --- A fazenda que nasce ---

func test_a_geracao_espalha_entulho_em_manchas() -> void:
	var eventos := _sistema.gera()
	assert_gt(_estado.ids().size(), 0, "a fazenda nova não nasce vazia")
	assert_eq(_mudancas(eventos).size(), _estado.ids().size(),
			"todo tile gerado sai como evento — o mapa desenha pelo que ouviu")
	for evento in _mudancas(eventos):
		assert_eq(evento.motivo, TerrenoMudouEvent.POR_GERACAO)

func test_a_geracao_deixa_chao_para_plantar() -> void:
	_sistema.gera()
	var area := _sistema.largura() * _sistema.altura()
	assert_lt(_estado.ids().size(), area / 2,
			"entulho é atrito, não bloqueio — sobra chão para começar")

func test_a_geracao_e_deterministica() -> void:
	_sistema.gera()
	var primeira := _estado.to_dict()

	before_each()
	_sistema.gera()

	assert_eq(_estado.to_dict(), primeira, "mesma semente, mesma fazenda")

func test_gerar_duas_vezes_nao_empilha() -> void:
	_sistema.gera()
	var quanto := _estado.ids().size()
	_sistema.gera()
	assert_eq(_estado.ids().size(), quanto,
			"gerar de novo redesenha a mesma fazenda, não põe entulho por cima")
