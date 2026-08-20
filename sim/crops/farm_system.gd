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
func react(event: SimEvent) -> Array[SimEvent]:
	if not event is DayEndedEvent:
		return []
	return _advance_day(event as DayEndedEvent)

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

func _water(action: WaterPlotAction) -> Array[SimEvent]:
	if not pode_regar(action.x, action.y):
		return []
	var plot := _state.get_plot(action.x, action.y)
	plot.regada = true

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
	event.qtd = def.rende_por_colheita
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
		plot.regada = false

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
