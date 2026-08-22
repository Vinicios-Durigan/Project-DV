class_name EventFeed
extends VBoxContainer

## O diário de avisos: tudo o que a sim contou, em ordem, com a hora de jogo.
##
## É o painel mais barato do playground e o mais útil: enquanto não existe
## sprite, o diário é o jogo acontecendo. Também é o primeiro lugar onde uma
## regra errada aparece — evento que não sai, ou sai fora de ordem, é bug de
## `sim/` visível a olho nu.
##
## ---
##
## ## Padrão 3 — escutar avisos
##
## Um `connect` só, no fio que a bridge entregou, e o nó reage ao que chega.
## Nada de perguntar de tempos em tempos se algo mudou: a sim avisa.
##
## Este nó é o caso extremo do padrão — mostra **todo** evento, sem filtrar por
## tipo. Um nó de jogo faz o contrário: filtra o tipo que é dele e ignora o
## resto em silêncio.
##
## O evento é gordo de propósito: tudo o que a linha mostra veio dentro dele,
## por reflection. Nenhuma consulta a state, nenhum catálogo, nenhuma conta.
##
## Copie daqui: `docs/receitas/escutar-avisos.md`.

## Linhas guardadas na tela. Passou disso, a mais velha sai — em ×60 o diário
## ganha 60 linhas por segundo e um `RichTextLabel` infinito engasga.
const MAX_LINHAS: int = 400

## Tamanho mínimo do diário, em pixels. Desde a wave 11 ele é a faixa de baixo:
## a largura é piso, a altura é o que se lê sem rolar.
const LARGURA: float = 380.0
const ALTURA: float = 132.0

## Campos que não viram texto: `SimEvent` não declara nenhum, mas o motor
## acrescenta os seus.
const CAMPOS_IGNORADOS: Array[String] = ["script", "Built-in script"]


var _bridge: SimBridge
var _texto: RichTextLabel
var _mostrar_minutos: CheckBox
var _dia: int = TimeState.DIA_DEFAULT
var _minuto: int = TimeState.MINUTO_DEFAULT

func _ready() -> void:
	custom_minimum_size = Vector2(LARGURA, 0)

	# O título do diário é o botão de colapsar, montado pela casca — aqui só
	# ficam os controles do painel.
	var linha := HBoxContainer.new()
	add_child(linha)

	_mostrar_minutos = CheckBox.new()
	_mostrar_minutos.text = "minutos"
	_mostrar_minutos.tooltip_text = "MinuteTickedEvent sai uma vez por minuto de jogo"
	linha.add_child(_mostrar_minutos)

	var limpar := Button.new()
	limpar.text = "Limpar"
	limpar.pressed.connect(func() -> void: _texto.clear())
	linha.add_child(limpar)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.scroll_following = true
	_texto.selection_enabled = true
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.custom_minimum_size = Vector2(LARGURA, ALTURA)
	_texto.theme_type_variation = &"Diario"
	add_child(_texto)

## Padrão 3 em duas linhas: recebe o fio, conecta no sinal. Não existe passo
## três.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_bridge.time_scale_changed.connect(_on_time_scale_changed)
	_le_relogio_do_snapshot()
	var time: Dictionary = _bridge.get_world().snapshot().get(SimFactory.CHAVE_TIME, {})
	_escreve(Paleta.TINTA, "sessão", "dia=%d estacao=%s" % [
		_dia, String(time.get("estacao", TimeState.ESTACAO_DEFAULT)),
	])

# --- Evento vira texto ---

## O tick traz a própria hora dentro dele, então acertar o relógio sai de
## graça; qualquer outro evento é raro o bastante para o `snapshot()` pagar.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		var tick := event as MinuteTickedEvent
		_dia = tick.dia
		_minuto = tick.minuto
		if not _mostrar_minutos.button_pressed:
			return
		_escreve(Paleta.TINTA_3, _nome_da_classe(event), "")
		return

	_le_relogio_do_snapshot()
	_escreve(_cor_do_evento(event), _nome_da_classe(event), _detalhes(event))

func _on_time_scale_changed(de: float, para: float) -> void:
	_escreve(Paleta.CEU, "velocidade", "de=×%s para=×%s" % [de, para])

## A cor do assunto do evento: fazenda no verde, tempo no céu, cidade na terra,
## recusa no alerta, dinheiro no ouro. Quem não se encaixa sai na tinta — linha
## nova nunca some do diário por falta de cor.
##
## É uma cadeia de `if` e não uma tabela `const` de propósito: referência de
## classe (`ActionRejectedEvent`) não é expressão constante fora do editor, e
## uma tabela dessas quebra o jogo ao rodar, não ao testar.
##
## A ordem importa numa linha só: a recusa vem antes de tudo, porque uma ação
## de fazenda recusada é recusa, não fazenda.
func _cor_do_evento(event: SimEvent) -> Color:
	if event is ActionRejectedEvent:
		return Paleta.ALERTA
	if event is MoneyChangedEvent or event is ItemsSoldEvent or event is SeedBoughtEvent:
		return Paleta.OURO
	if event is DayEndedEvent:
		return Paleta.CEU
	if event is JogadorViajouEvent:
		return Paleta.TERRA
	if event is PlotTilledEvent or event is PlotWateredEvent or event is CropPlantedEvent:
		return Paleta.VERDE
	if event is CropGrewEvent or event is CropHarvestedEvent or event is CropDiedEvent:
		return Paleta.VERDE
	return Paleta.TINTA

## Uma linha: hora de jogo, nome real do evento, campos.
func _escreve(cor: Color, nome: String, detalhes: String) -> void:
	_texto.append_text("[color=%s]%s[/color] [color=%s]%s[/color] %s\n" % [
		Paleta.hex(Paleta.TINTA_3), _hora(), Paleta.hex(cor), nome, _escapa(detalhes),
	])
	while _texto.get_paragraph_count() > MAX_LINHAS:
		_texto.remove_paragraph(0)

func _hora() -> String:
	return "d%02d %02d:%02d" % [_dia, _minuto / 60, _minuto % 60]

func _le_relogio_do_snapshot() -> void:
	var time: Dictionary = _bridge.get_world().snapshot().get(SimFactory.CHAVE_TIME, {})
	_dia = int(time.get("dia", _dia))
	_minuto = int(time.get("minuto", _minuto))

## `class_name` do evento — o nome real, o mesmo que está no `sim/EVENTOS.md` e
## no log JSONL. Nome inventado pelo painel viraria dialeto do playground.
func _nome_da_classe(event: SimEvent) -> String:
	var script := event.get_script() as Script
	if script == null:
		return event.get_class()
	var nome := script.get_global_name()
	return nome if not nome.is_empty() else script.resource_path.get_file().get_basename()

## Todo campo declarado do evento, por reflection: painel novo não precisa
## aprender evento novo. Se o texto ficou pobre, o evento é que está magro.
func _detalhes(event: SimEvent) -> String:
	var partes: Array[String] = []
	for prop: Dictionary in event.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var nome := String(prop["name"])
		if nome.begins_with("_") or CAMPOS_IGNORADOS.has(nome):
			continue
		partes.append("%s=%s" % [nome, _valor(event.get(nome))])
	return " ".join(partes)

## Lista de sub-objetos (as linhas do resumo de venda) vira contagem: o detalhe
## de cada uma cabe no evento, não na linha.
func _valor(valor: Variant) -> String:
	match typeof(valor):
		TYPE_ARRAY:
			return "(%d)" % (valor as Array).size()
		TYPE_DICTIONARY:
			return "{%d}" % (valor as Dictionary).size()
		_:
			return str(valor)

## Colchete de id vira texto, não tag de bbcode.
func _escapa(texto: String) -> String:
	return texto.replace("[", "[lb]")
