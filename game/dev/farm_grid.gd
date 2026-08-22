class_name FarmGrid
extends VBoxContainer

## A fazenda como 8×6 botões. Escolhe a ferramenta, clica no canteiro, a sim
## faz o resto.
##
## ---
##
## ## Padrão 2 — mandar ordens
##
## O clique não muda nada na tela. Ele monta uma `SimAction`, entrega para a
## bridge e acaba ali: quem decide se o tile pode ser arado, se a semente
## existe e se a cultura está madura é a sim. O que aparece no botão depois é
## consequência do `snapshot()`, não do clique.
##
## Nenhum `if` de regra mora neste arquivo. As duas únicas perguntas que ele
## faz — `pode_plantar()` e o estágio de colheita — são respondidas pela sim
## (`FarmSystem` e `CropDef`); este nó só repassa a resposta.
##
## Copie daqui: `docs/receitas/mandar-ordens.md`.

## Tamanho da fazenda jogável no playground. O mundo de verdade é maior; aqui é
## o que cabe na tela sem rolagem.
const COLUNAS: int = 8
const LINHAS: int = 6

## Tamanho mínimo do botão-canteiro, em pixels.
const TAMANHO_CANTEIRO: Vector2 = Vector2(72, 44)

## Símbolos do canteiro. Terra crua, terra arada, terra molhada e cultura
## pronta — é o "sprite" do playground.
const SIMBOLO_VAZIO: String = "·"
const SIMBOLO_ARADA: String = "▤"
const SIMBOLO_REGADA: String = "≈"
const SIMBOLO_PRONTA: String = "★"

## As quatro ferramentas do dia a dia, na ordem em que se usam.
enum Ferramenta {
	ARAR,
	PLANTAR,
	REGAR,
	COLHER,
}

const NOMES_FERRAMENTA: Dictionary = {
	Ferramenta.ARAR: "Arar",
	Ferramenta.PLANTAR: "Plantar",
	Ferramenta.REGAR: "Regar",
	Ferramenta.COLHER: "Colher",
}

var _bridge: SimBridge
var _ferramenta: Ferramenta = Ferramenta.ARAR
var _canteiros: Dictionary = {}
var _culturas: OptionButton
var _aviso: Label

func _ready() -> void:
	_monta_barra_de_ferramentas()
	_monta_grid()
	_aviso = Label.new()
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)

## Padrão 1: o fio chega, e só a partir daqui os botões falam com a sim.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_preenche_culturas()
	_atualiza()

# --- Montagem ---

func _monta_barra_de_ferramentas() -> void:
	var titulo := Label.new()
	titulo.text = "Fazenda"
	add_child(titulo)

	var linha := HBoxContainer.new()
	add_child(linha)

	var grupo := ButtonGroup.new()
	for ferramenta: Ferramenta in NOMES_FERRAMENTA.keys():
		var botao := Button.new()
		botao.text = String(NOMES_FERRAMENTA[ferramenta])
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.button_pressed = ferramenta == _ferramenta
		botao.pressed.connect(_on_ferramenta_pressed.bind(ferramenta))
		linha.add_child(botao)

	_culturas = OptionButton.new()
	_culturas.tooltip_text = "Cultura que a ferramenta Plantar usa"
	linha.add_child(_culturas)

func _monta_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = COLUNAS
	add_child(grid)
	for y in LINHAS:
		for x in COLUNAS:
			var botao := Button.new()
			botao.custom_minimum_size = TAMANHO_CANTEIRO
			botao.pressed.connect(_on_canteiro_pressed.bind(x, y))
			grid.add_child(botao)
			_canteiros[FarmState.plot_id(x, y)] = botao

## O catálogo é leitura livre: montar o menu com o conteúdo de `data/` não é
## decidir regra, é mostrar o que existe.
func _preenche_culturas() -> void:
	_culturas.clear()
	for crop_id in _bridge.get_crop_catalog().ids():
		var def := _bridge.get_crop_catalog().get_def(crop_id)
		_culturas.add_item("%s (%d moedas)" % [def.nome, def.preco_semente])
		_culturas.set_item_metadata(_culturas.item_count - 1, crop_id)
	if _culturas.item_count > 0:
		_culturas.select(0)

# --- Clique vira ação ---

func _on_ferramenta_pressed(ferramenta: Ferramenta) -> void:
	_ferramenta = ferramenta

## O coração do padrão 2: monta a ação da ferramenta e despacha. Sem `match` de
## regra, sem checar estado antes — a sim aceita ou rejeita, e o diário conta.
func _on_canteiro_pressed(x: int, y: int) -> void:
	_aviso.text = ""
	match _ferramenta:
		Ferramenta.ARAR:
			var arar := TillPlotAction.new()
			arar.x = x
			arar.y = y
			_bridge.dispatch(arar)
		Ferramenta.PLANTAR:
			_planta(x, y)
		Ferramenta.REGAR:
			var regar := WaterPlotAction.new()
			regar.x = x
			regar.y = y
			_bridge.dispatch(regar)
		Ferramenta.COLHER:
			var colher := HarvestCropAction.new()
			colher.x = x
			colher.y = y
			_bridge.dispatch(colher)

## Plantar é a única ordem que se pergunta antes de mandar, e a pergunta é da
## sim: `PlantCropAction` é uma `RemoveItemAction`, então a semente sai da
## mochila **antes** de o `FarmSystem` olhar o tile. Despachar em tile inválido
## cobraria a semente à toa.
func _planta(x: int, y: int) -> void:
	var crop_id := _cultura_selecionada()
	if crop_id.is_empty():
		return
	var farm := _farm_system()
	if farm != null and not farm.pode_plantar(crop_id, x, y):
		_aviso.text = "A sim disse não: pode_plantar(%s, %d, %d)" % [crop_id, x, y]
		return

	var def := _bridge.get_crop_catalog().get_def(crop_id)
	var plantar := PlantCropAction.new()
	plantar.crop_id = crop_id
	plantar.item_id = def.item_semente_id()
	plantar.qtd = 1
	plantar.x = x
	plantar.y = y
	_bridge.dispatch(plantar)

func _cultura_selecionada() -> String:
	if _culturas.selected < 0:
		return ""
	return String(_culturas.get_item_metadata(_culturas.selected))

## O sistema é dono da pergunta; achar quem responde é problema de quem
## pergunta. `game/` nunca guarda referência de state — só de quem sabe.
func _farm_system() -> FarmSystem:
	for system in _bridge.get_world().get_systems():
		if system is FarmSystem:
			return system as FarmSystem
	return null

# --- Evento vira texto ---

## Minuto que passa não mexe em canteiro: a fazenda muda por ação e na virada
## do dia. Ignorar o tick evita redesenhar 48 botões 60 vezes por segundo em
## ×60.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	_atualiza()

## Redesenha a partir do `snapshot()`, nunca do state vivo: o que o botão
## mostra é exatamente o que iria para o arquivo de save.
func _atualiza() -> void:
	var plots: Dictionary = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_FARM, {}) \
		.get("plots", {})
	for plot_id: String in _canteiros.keys():
		var botao := _canteiros[plot_id] as Button
		var bruto: Variant = plots.get(plot_id, {})
		var plot: Dictionary = bruto if bruto is Dictionary else {}
		botao.text = _texto_do_canteiro(plot)
		botao.tooltip_text = "%s\n%s" % [plot_id, JSON.stringify(plot)]

func _texto_do_canteiro(plot: Dictionary) -> String:
	if plot.is_empty():
		return SIMBOLO_VAZIO
	var agua := SIMBOLO_REGADA if bool(plot.get("regada", false)) else " "
	var crop_id := String(plot.get("crop_id", ""))
	if crop_id.is_empty():
		return "%s%s" % [SIMBOLO_ARADA, agua]

	var estagio := int(plot.get("estagio", 0))
	var def := _bridge.get_crop_catalog().get_def(crop_id)
	if def == null:
		return "%s? %d" % [agua, estagio]
	# quem sabe qual estágio é o de colher é o `CropDef`, em `sim/`. Este nó só
	# repassa a resposta para dentro do texto do botão.
	var pronta := SIMBOLO_PRONTA if estagio >= def.estagio_pronta() else ""
	return "%s%s %d/%d%s" % [
		agua, crop_id.substr(0, 3), estagio + 1, def.total_estagios(), pronta,
	]
