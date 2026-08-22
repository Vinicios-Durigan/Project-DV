class_name InspetorTile
extends VBoxContainer

## O estado cru do tile mirado, lido do `snapshot()` (GAMEPLAY §11).
##
## Vale o dobro num esboço: é como se confere que a sim está fazendo o que a
## gente acha que está, sem confiar no desenho. Se o quadrado verde diz uma
## coisa e o inspetor diz outra, o bug é do desenho.
##
## ---
##
## ## Padrão 3 — escutar avisos
##
## Este painel não pergunta nada à sim e não guarda referência de state: ele
## mostra o `snapshot()`, o mesmo dicionário que vai para o arquivo de save.
## Zero API nova — e o inspetor de save sai de graça.
##
## Desde a wave 11 ele mora na coluna da direita e não mostra mais "você está":
## esse rótulo virou grupo do rail. O que ficou aqui é o tile.

const LARGURA: float = 224.0

var _bridge: SimBridge
var _mundo: MundoEsboco
var _mira: MiraFerramentas
var _alvo: Label
var _campos: Label
var _ultimo_texto: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(LARGURA, 0)
	add_child(_titulo("Tile mirado"))
	_alvo = Label.new()
	_alvo.theme_type_variation = &"Dado"
	add_child(_alvo)
	_campos = Label.new()
	_campos.theme_type_variation = &"Dado"
	_campos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_campos)
	set_process(false)

func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_mundo = _acha_mundo()
	if _mundo != null:
		_mira = _mundo.get_node_or_null("MiraFerramentas") as MiraFerramentas
	_bridge.sim_event.connect(_on_sim_event)
	set_process(true)
	_atualiza()


func _process(_delta: float) -> void:
	# Andar não emite evento da sim (posição é apresentação), então a mira
	# muda sem aviso: o painel acompanha por comparação de texto, sem
	# reconstruir Label a cada frame.
	_atualiza()

func _on_sim_event(_event: SimEvent) -> void:
	_atualiza()


func _atualiza() -> void:
	if _bridge == null or _mundo == null:
		return

	# Segue o mesmo alvo da mira — mouse quando ele manda, facing quando não.
	var canteiro := _mundo.canteiro_no_tile(_tile_alvo())
	if canteiro.x < 0:
		_alvo.text = "fora dos canteiros"
		_texto_campos("—")
		return

	_alvo.text = "canteiro %d,%d" % [canteiro.x, canteiro.y]
	var plot: Dictionary = _mundo.plot_em(canteiro)
	if plot.is_empty():
		_texto_campos("solo virgem\n(nunca arado)")
		return
	_texto_campos(_descreve(plot))

## O dicionário cru, campo a campo, mais a única leitura derivada: se está
## pronta. Quem sabe o estágio de colheita é o `CropDef` — não este arquivo.
func _descreve(plot: Dictionary) -> String:
	var crop_id := String(plot.get("crop_id", ""))
	var linhas: Array[String] = []
	linhas.append("regada: %s" % ("sim" if bool(plot.get("regada", false)) else "não"))
	if crop_id.is_empty():
		linhas.append("cultura: —")
		return "\n".join(linhas)

	var estagio := int(plot.get("estagio", 0))
	linhas.append("cultura: %s" % crop_id)
	var def := _bridge.get_crop_catalog().get_def(crop_id)
	if def == null:
		linhas.append("estágio: %d" % estagio)
		return "\n".join(linhas)

	linhas.append("estágio: %d / %d" % [estagio, def.estagio_pronta()])
	linhas.append("dias no estágio: %d" % int(plot.get("dias_no_estagio", 0)))
	linhas.append("pronta: %s" % ("SIM — colha" if estagio >= def.estagio_pronta() else "não"))
	return "\n".join(linhas)

func _texto_campos(texto: String) -> void:
	if texto == _ultimo_texto:
		return
	_ultimo_texto = texto
	_campos.text = texto

## O mundo de esboço: sobe-se a árvore até achar quem sabe respondê-lo (a
## casca do playground). Caminho de nó dentro do painel quebraria no dia
## seguinte a mexer no layout — e a wave 11 mexeu.
func _acha_mundo() -> MundoEsboco:
	var no := get_parent()
	while no != null:
		if no.has_method("get_mundo"):
			return no.call("get_mundo") as MundoEsboco
		no = no.get_parent()
	return null

## O alvo da mira, com o facing como reserva enquanto ela não chegou.
func _tile_alvo() -> Vector2i:
	if _mira != null:
		return _mira.tile_alvo()
	return _mundo.tile_mirado()

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label
