class_name FarmSystem
extends SimSystem

## Dono da fazenda: as 4 ações do loop diário (arar, plantar, regar, colher) e
## o crescimento na virada do dia.
##
## Roda depois do InventorySystem na ordem fixa — quando a ação chega aqui, a
## semente já foi cobrada (ou a ação já veio rejeitada e é ignorada).
##
## Ação inválida não muda nada e não emite nada. A exceção é plantar: a cadeia
## já cobrou a semente, então o tile inválido vira `ActionRejectedEvent` para
## `game/` ter o que dizer. Para o retículo nunca chegar nesse ponto, `game/`
## pergunta antes com `pode_*()`.
##
## Crescimento é na virada do dia, nunca contínuo: o sistema reage a
## `DayEndedEvent` e emite a cascata da manhã na ordem dos plots.

## As vantagens que **a lavoura** paga (wave 17). O id é o mesmo do tabuleiro do
## `SistemaOficios`, escrito aqui de novo de propósito: a lavoura não referencia
## o sistema que a ensina, senão os dois passariam a se conhecer em círculo. Quem
## prende os dois lados é o teste — id divergente desligaria o efeito em
## silêncio, depois de o jogador já ter pago o ponto.
const REGA_FUNDA: String = "rega_funda"
const COLHEITA_ESPECIALIZADA: String = "colheita_especializada"

## Quantos canteiros por dia cada nível de Rega funda alcança: 4 no primeiro
## ponto, 8 no segundo. É cota, e não interruptor — a vantagem compra rota, e a
## decisão de **quais** canteiros molhar continua sendo do jogador.
const CANTEIROS_POR_NIVEL: int = 4

## Quantas viradas de dia a mais a água funda aguenta. Uma: regou hoje, cresce
## hoje à noite e amanhã à noite. Duas seriam a rega deixando de existir como
## rota, e a rota é metade do dia (wave 14.1).
const DIAS_EXTRA_DE_AGUA: int = 1

## Quanto a Colheita especializada soma na cultura escolhida. O bônus nasce na
## **colheita**, nunca no preço: trigo a 2× de preço mataria o moinho e, com ele,
## a tese do jogo (PRINCIPIOS §2).
const BONUS_DA_ESPECIALIZACAO: int = 1

const MOTIVO_TILE_NAO_ARADO: String = "tile_nao_arado"
const MOTIVO_TILE_OCUPADO: String = "tile_ocupado"
const MOTIVO_CULTURA_DESCONHECIDA: String = "cultura_desconhecida"

var _state: FarmState
var _catalog: CropCatalog

func _init(state: FarmState = null, catalog: CropCatalog = null) -> void:
	_state = state if state != null else FarmState.new()
	_catalog = catalog if catalog != null else CropCatalog.new()

func get_state() -> FarmState:
	return _state

func get_catalog() -> CropCatalog:
	return _catalog

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is TillPlotAction:
		return _till(action as TillPlotAction)
	if action is PlantCropAction:
		return _plant(action as PlantCropAction)
	if action is WaterPlotAction:
		return _water(action as WaterPlotAction)
	if action is HarvestCropAction:
		return _harvest(action as HarvestCropAction)
	return []

## O dia virou: quem estava regada cresce, a rega reseta e, no fim da estação,
## o que ficou no chão morre.
##
## E o tile que fechou perde o arado: quem cobre é o `SistemaTerreno`, que não
## escreve aqui — ele avisa, e o dono do plot reage.
func react(event: SimEvent) -> Array[SimEvent]:
	if event is DayEndedEvent:
		return _advance_day(event as DayEndedEvent)
	if event is TerrenoMudouEvent:
		return _perde_o_arado(event as TerrenoMudouEvent)
	if event is VantagemEscolhidaEvent:
		return _aprende(event as VantagemEscolhidaEvent)
	return []


## A lavoura aprendeu alguma coisa (wave 17). O efeito chega por evento e a cópia
## fica aqui: ela nunca abre o state dos ofícios, e é isso que mantém "ninguém lê
## state alheio" de pé com dois sistemas dependendo de um terceiro.
##
## Vantagem que não é deste sistema passa direto — a fila oferece todo evento a
## todo mundo, e ignorar o que não é seu é o normal.
func _aprende(event: VantagemEscolhidaEvent) -> Array[SimEvent]:
	if event.vantagem_id != REGA_FUNDA and event.vantagem_id != COLHEITA_ESPECIALIZADA:
		return []

	_state.guarda_vantagem(event.vantagem_id, event.nivel)
	if event.vantagem_id == COLHEITA_ESPECIALIZADA:
		_state.define_cultura_especializada(event.cultura)
	return []


# --- As vantagens da lavoura (consultas) ---

## Quantos canteiros por dia a Rega funda alcança. Zero sem a vantagem.
func cota_de_rega_funda() -> int:
	return _state.nivel_da_vantagem(REGA_FUNDA) * CANTEIROS_POR_NIVEL

## Quantos canteiros já beberam água funda hoje.
func regas_fundas_hoje() -> int:
	return _state.regas_fundas_hoje()

## Ainda cabe água funda hoje? É o que decide se a próxima rega segura ou seca.
func tem_cota_de_rega_funda() -> bool:
	return _state.regas_fundas_hoje() < cota_de_rega_funda()

## A cultura que rende a mais, ou `""` se ninguém se especializou.
func cultura_especializada() -> String:
	return _state.cultura_especializada()

## Quanto esta cultura rende por colheita, já com a especialização. É a pergunta
## que a tela faz, e ela é de regra: quem soma o +1 é o dono da colheita.
func rendimento_de(crop_id: String) -> int:
	var def := _catalog.get_def(crop_id)
	if def == null:
		return 0
	var bonus := BONUS_DA_ESPECIALIZACAO if crop_id == _state.cultura_especializada() else 0
	return def.rende_por_colheita + bonus

## O terreno fechou por cima de um tile arado: o preparo se perde.
##
## **Não emite evento.** É a única mudança de estado deste arquivo que não emite,
## e o motivo é que ela não é um fato novo: o `TerrenoMudouEvent` que a causou já
## conta a história inteira para quem escuta — um tile que deixou de ser livre
## não tem mais como estar arado, e a tela já se redesenha por causa dele. Um
## `PlotDesaradoEvent` seria a mesma frase dita duas vezes, na mesma cascata.
##
## Cultura em pé não é coberta (o terreno nem tenta), então aqui não há caso a
## tratar: se chegou, é tile vazio.
func _perde_o_arado(terreno: TerrenoMudouEvent) -> Array[SimEvent]:
	if terreno.para == EstadoTerreno.LIVRE:
		return []
	var plot := _state.peek_plot(terreno.x, terreno.y)
	if not plot.arada or plot.tem_cultura():
		return []
	_state.get_plot(terreno.x, terreno.y).arada = false
	return []

# --- Consultas para o retículo de game/ (leitura pura, não criam plot) ---

func pode_arar(x: int, y: int) -> bool:
	var plot := _state.peek_plot(x, y)
	return not plot.arada and not plot.tem_cultura()

func pode_plantar(crop_id: String, x: int, y: int) -> bool:
	if not _catalog.has(crop_id):
		return false
	var plot := _state.peek_plot(x, y)
	return plot.arada and not plot.tem_cultura()

func pode_regar(x: int, y: int) -> bool:
	var plot := _state.peek_plot(x, y)
	return plot.arada and not plot.regada

func pode_colher(x: int, y: int) -> bool:
	var plot := _state.peek_plot(x, y)
	if not plot.tem_cultura():
		return false
	var def := _catalog.get_def(plot.crop_id)
	return def != null and plot.estagio >= def.estagio_pronta()

# --- Ações ---

func _till(action: TillPlotAction) -> Array[SimEvent]:
	if not pode_arar(action.x, action.y):
		return []
	_state.get_plot(action.x, action.y).arada = true

	var event := PlotTilledEvent.new()
	event.player_id = action.player_id
	event.plot_id = FarmState.plot_id(action.x, action.y)
	event.x = action.x
	event.y = action.y
	return [event]

## A semente já saiu da mochila lá atrás: tile inválido aqui é rejeição com
## motivo, não silêncio.
func _plant(action: PlantCropAction) -> Array[SimEvent]:
	var def := _catalog.get_def(action.crop_id)
	if def == null:
		return [_rejeitada(action, MOTIVO_CULTURA_DESCONHECIDA)]
	var alvo := _state.peek_plot(action.x, action.y)
	if not alvo.arada:
		return [_rejeitada(action, MOTIVO_TILE_NAO_ARADO)]
	if alvo.tem_cultura():
		return [_rejeitada(action, MOTIVO_TILE_OCUPADO)]

	var plot := _state.get_plot(action.x, action.y)
	plot.crop_id = def.id
	plot.estagio = 0
	plot.dias_no_estagio = 0

	var event := CropPlantedEvent.new()
	event.player_id = action.player_id
	event.plot_id = FarmState.plot_id(action.x, action.y)
	event.x = action.x
	event.y = action.y
	event.crop_id = def.id
	event.estagio_pronta = def.estagio_pronta()
	return [event]

## Rega. Com Rega funda comprada, os primeiros canteiros do dia guardam água para
## a noite seguinte também — e **quais** são eles é decisão do jogador, pela
## ordem em que ele rega. Determinístico de propósito: sorte no resultado foi
## descartada no GAMEPLAY com motivo.
##
## A cota só é gasta por rega que aconteceu de verdade: tile seco não bebe água
## nem consome o dia de ninguém.
func _water(action: WaterPlotAction) -> Array[SimEvent]:
	if not pode_regar(action.x, action.y):
		return []
	var plot := _state.get_plot(action.x, action.y)
	plot.regada = true
	if tem_cota_de_rega_funda():
		plot.dias_de_agua = DIAS_EXTRA_DE_AGUA
		_state.conta_rega_funda()

	var event := PlotWateredEvent.new()
	event.player_id = action.player_id
	event.plot_id = FarmState.plot_id(action.x, action.y)
	event.x = action.x
	event.y = action.y
	event.crop_id = plot.crop_id
	return [event]

## Colher emite `CropHarvestedEvent`, que é um `ItemGrantedEvent`: o inventário
## reage adicionando sem saber que existe agricultura.
func _harvest(action: HarvestCropAction) -> Array[SimEvent]:
	if not pode_colher(action.x, action.y):
		return []
	var plot := _state.get_plot(action.x, action.y)
	var def := _catalog.get_def(plot.crop_id)

	var event := CropHarvestedEvent.new()
	event.player_id = action.player_id
	event.plot_id = FarmState.plot_id(action.x, action.y)
	event.x = action.x
	event.y = action.y
	event.crop_id = plot.crop_id
	event.item_id = def.item_colheita_id()
	# A Colheita especializada soma aqui, na colheita, e nunca no preço: o bônus
	# tem que passar pelo moinho como qualquer outro punhado (PRINCIPIOS §2).
	event.qtd = rendimento_de(plot.crop_id)
	event.rebrota = def.colheitas_infinitas

	if def.colheitas_infinitas:
		plot.estagio = def.estagio_rebrota()
		plot.dias_no_estagio = 0
	else:
		plot.limpa_cultura()
	return [event]

# --- Virada do dia ---

## Duas passadas, ambas na ordem dos plots (linha a linha, esquerda para a
## direita) — a ordem é contrato: `game/` anima a cascata da manhã assim.
##
## 1. Crescimento: regada avança, seca pausa (não morre). A rega reseta em todo
##    plot, com ou sem planta — quem conta essa história para `game/` é o
##    próprio `DayEndedEvent`.
## 2. Fim de estação: o que sobrou no chão morre, mesmo tendo crescido nesta
##    mesma noite. É a sequência de dormir do GAMEPLAY, na ordem.
func _advance_day(day: DayEndedEvent) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	var ids := _state.plot_ids()

	for id in ids:
		var plot := _state.get_plot_by_id(id)
		var grew := _grow(plot, day)
		if grew != null:
			events.append(grew)
		# A terra funda gasta um dia de reserva em vez de secar. Sem reserva, é a
		# rega de sempre: seca toda noite.
		if plot.dias_de_agua > 0:
			plot.dias_de_agua -= 1
		else:
			plot.regada = false

	# Cota cheia de novo: a Rega funda é do dia, não da partida.
	_state.zera_regas_fundas()

	if day.fim_de_estacao:
		for id in ids:
			var plot := _state.get_plot_by_id(id)
			if not plot.tem_cultura():
				continue
			events.append(_die(plot, day))
			plot.limpa_cultura()
	return events

## Um evento por planta que avançou, com o estágio final da noite — estágio de
## 0 dia (`dias_por_estagio` com 0) encadeia dentro do mesmo evento.
func _grow(plot: FarmState.Plot, day: DayEndedEvent) -> CropGrewEvent:
	if not plot.tem_cultura() or not plot.regada:
		return null
	var def := _catalog.get_def(plot.crop_id)
	if def == null:
		return null
	var pronta := def.estagio_pronta()
	if plot.estagio >= pronta:
		return null

	var de := plot.estagio
	plot.dias_no_estagio += 1
	while plot.estagio < pronta and plot.dias_no_estagio >= def.dias_do_estagio(plot.estagio):
		plot.dias_no_estagio -= def.dias_do_estagio(plot.estagio)
		plot.estagio += 1
	if plot.estagio >= pronta:
		plot.dias_no_estagio = 0
	if plot.estagio == de:
		return null

	var event := CropGrewEvent.new()
	event.plot_id = FarmState.plot_id(plot.x, plot.y)
	event.x = plot.x
	event.y = plot.y
	event.crop_id = plot.crop_id
	event.estagio_de = de
	event.estagio_para = plot.estagio
	event.pronta = plot.estagio >= pronta
	event.dia = day.dia_novo
	event.estacao = day.estacao
	return event

func _die(plot: FarmState.Plot, day: DayEndedEvent) -> CropDiedEvent:
	var event := CropDiedEvent.new()
	event.plot_id = FarmState.plot_id(plot.x, plot.y)
	event.x = plot.x
	event.y = plot.y
	event.crop_id = plot.crop_id
	event.estagio = plot.estagio
	event.motivo = CropDiedEvent.MOTIVO_FIM_DE_ESTACAO
	event.dia = day.dia_novo
	event.estacao = day.estacao
	return event

func _rejeitada(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var event := ActionRejectedEvent.new()
	event.player_id = action.player_id
	event.acao = action.get_script().get_global_name()
	event.motivo = motivo
	return event
