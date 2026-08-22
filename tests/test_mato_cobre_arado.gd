extends GutTest

## O preparo que ninguém usou volta a ser mato — e a planta em pé nunca.
##
## ## A decisão travada desta wave
##
## O mato cobre tile **arado**, nunca tile **plantado**. O que se perde é
## preparo que você não usou, e arar de novo é um swing. Perder uma abóbora de
## 13 dias seria outro jogo, e romperia a regra que vale desde a wave 03: a
## punição **pausa**, não destrói — a mesma filosofia da planta não regada.
##
## ## Quem desara não é o terreno
##
## O `SistemaTerreno` não escreve no `FarmState`. Ele emite `TerrenoMudouEvent`
## e o dono do plot reage, exatamente como o `InventorySystem` reage ao
## `ItemGrantedEvent`. Dois sistemas escrevendo no mesmo tile seria a primeira
## corrida de escrita do projeto.
##
## Este teste roda pelo `SimWorld` de propósito: o que ele prende é a **cascata**
## — o evento saindo de um sistema e chegando ao outro pela fila — e não o
## `react` isolado, que passaria mesmo se a fila estivesse quebrada.

const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _factory: SimFactory
var _world: SimWorld
var _farm: FarmState
var _terreno: EstadoTerreno


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	_farm = _factory.get_farm_state()
	_terreno = _factory.get_estado_terreno()
	# A geração inicial espalha entulho; estes testes falam de tiles específicos.
	_terreno.from_dict({"semente": _terreno.semente})

func _ara(x: int, y: int) -> void:
	var acao := TillPlotAction.new()
	acao.player_id = JOGADOR
	acao.x = x
	acao.y = y
	_world.handle(acao)

func _planta(x: int, y: int) -> void:
	var acao := PlantCropAction.new()
	acao.player_id = JOGADOR
	acao.crop_id = "rabanete"
	acao.item_id = "semente_rabanete"
	acao.x = x
	acao.y = y
	_world.handle(acao)

## A noite passando, como o `TimeSystem` a anuncia — pela fila do mundo, para a
## cascata acontecer de verdade.
func _vira_o_dia() -> Array[SimEvent]:
	return _world.handle(SleepAction.new())


func test_o_arado_que_ninguem_usou_se_perde() -> void:
	_ara(1, 1)
	for _dia in SistemaTerreno.DIAS_PARA_FECHAR:
		_vira_o_dia()

	assert_eq(_terreno.cobertura(1, 1), EstadoTerreno.MATO, "o mato tomou de volta")
	assert_false(_farm.peek_plot(1, 1).arada,
			"e o preparo se perdeu junto — arar de novo é um swing")

func test_a_planta_em_pe_nao_e_coberta() -> void:
	_ara(2, 2)
	_planta(2, 2)
	for _dia in 12:
		_vira_o_dia()

	assert_true(_terreno.e_livre(2, 2), "planta em pé segura o tile")
	assert_true(_farm.peek_plot(2, 2).tem_cultura(), "e a cultura continua lá")

## O caso que mais dói se sair errado: a cultura lenta, que passa quase duas
## semanas ocupando o tile sem nada acontecer.
func test_a_cultura_lenta_atravessa_a_estacao_inteira() -> void:
	_ara(3, 3)
	_planta(3, 3)
	for _dia in 13:
		_vira_o_dia()
	assert_true(_farm.peek_plot(3, 3).tem_cultura(),
			"13 dias parados não são abandono — são o ciclo da abóbora")

func test_colher_devolve_o_tile_para_o_relogio_do_mato() -> void:
	_ara(4, 4)
	_planta(4, 4)
	_farm.get_plot(4, 4).limpa_cultura()
	for _dia in SistemaTerreno.DIAS_PARA_FECHAR:
		_vira_o_dia()
	assert_eq(_terreno.cobertura(4, 4), EstadoTerreno.MATO,
			"colheu e deixou parado: o relógio volta a correr")

## Qualquer cobertura desara, não só o mato. Se um dia uma pedra rolar para o
## canteiro, o arado embaixo dela não sobrevive.
func test_qualquer_cobertura_desara_o_tile() -> void:
	_ara(5, 5)
	var evento := TerrenoMudouEvent.new()
	evento.x = 5
	evento.y = 5
	evento.de = EstadoTerreno.LIVRE
	evento.para = EstadoTerreno.PEDRA
	evento.motivo = TerrenoMudouEvent.POR_GERACAO
	for sistema in _world.get_systems():
		if sistema is FarmSystem:
			sistema.react(evento)

	assert_false(_farm.peek_plot(5, 5).arada, "o que fecha o tile desara o tile")

func test_limpar_o_tile_nao_ara_de_volta() -> void:
	_ara(6, 5)
	for _dia in SistemaTerreno.DIAS_PARA_FECHAR:
		_vira_o_dia()
	var evento := TerrenoMudouEvent.new()
	evento.x = 6
	evento.y = 5
	evento.de = EstadoTerreno.MATO
	evento.para = EstadoTerreno.LIVRE
	evento.motivo = TerrenoMudouEvent.POR_LIMPEZA
	for sistema in _world.get_systems():
		if sistema is FarmSystem:
			sistema.react(evento)

	assert_false(_farm.peek_plot(6, 5).arada,
			"abrir o tile devolve o chão, não o trabalho — a enxada é que ara")
