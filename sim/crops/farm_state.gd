class_name FarmState
extends RefCounted

## Estado da fazenda, dono exclusivo do FarmSystem.
##
## Um plot por tile tocado, indexado por `"x:y"`. Tile que ninguém arou nunca
## vira plot: a fazenda guarda só o que mudou.
##
## O plot guarda `crop_id` + estágio: nenhum tipo concreto de cultura entra no
## state. Quem sabe quantos dias falta é o `CropDef` no catálogo.
##
## Todo campo tem default e entra no snapshot do save por to_dict/from_dict.


## Um tile da fazenda.
class Plot extends RefCounted:
	var x: int = 0
	var y: int = 0
	var arada: bool = false
	var regada: bool = false
	var crop_id: String = ""
	var estagio: int = 0
	var dias_no_estagio: int = 0

	func _init(x_: int = 0, y_: int = 0) -> void:
		x = x_
		y = y_

	func tem_cultura() -> bool:
		return not crop_id.is_empty()

	## Tira a planta do tile. A terra continua arada — colher não desfaz o
	## trabalho da enxada.
	func limpa_cultura() -> void:
		crop_id = ""
		estagio = 0
		dias_no_estagio = 0

	## Plot que nunca mudou não precisa ocupar espaço no save.
	func is_default() -> bool:
		return not arada and not regada and not tem_cultura() \
			and estagio == 0 and dias_no_estagio == 0

	func to_dict() -> Dictionary:
		return {
			"arada": arada,
			"regada": regada,
			"crop_id": crop_id,
			"estagio": estagio,
			"dias_no_estagio": dias_no_estagio,
		}

	func from_dict(data: Dictionary) -> void:
		arada = bool(data.get("arada", false))
		regada = bool(data.get("regada", false))
		crop_id = String(data.get("crop_id", ""))
		estagio = int(data.get("estagio", 0))
		dias_no_estagio = int(data.get("dias_no_estagio", 0))


var _plots: Dictionary = {}

## Chave do plot no dicionário e no save.
static func plot_id(x: int, y: int) -> String:
	return "%d:%d" % [x, y]

func has_plot(x: int, y: int) -> bool:
	return _plots.has(plot_id(x, y))

## Plot do tile, criado com os defaults na primeira vez que é pedido. Use para
## **mudar** o tile.
func get_plot(x: int, y: int) -> Plot:
	var id := plot_id(x, y)
	if not _plots.has(id):
		_plots[id] = Plot.new(x, y)
	return _plots[id] as Plot

## Plot já existente pela chave do dicionário. Usado por quem percorre
## `plot_ids()`; chave desconhecida devolve `null`.
func get_plot_by_id(id: String) -> Plot:
	return _plots.get(id, null) as Plot

## Plot do tile sem criar nada: tile intocado devolve um plot novo com os
## defaults, que não entra no state. Use para **consultar** (retículo, validação).
func peek_plot(x: int, y: int) -> Plot:
	var id := plot_id(x, y)
	if _plots.has(id):
		return _plots[id] as Plot
	return Plot.new(x, y)

## Plots existentes, ordenados por linha (`y`) e depois coluna (`x`).
##
## A ordem é contrato: a cascata da manhã em `game/` anima nessa sequência, e
## ela não pode depender de quem foi arado primeiro nem de como o save voltou.
func plot_ids() -> Array[String]:
	var plots: Array[Plot] = []
	for id: String in _plots.keys():
		plots.append(_plots[id] as Plot)
	plots.sort_custom(_linha_a_linha)
	var out: Array[String] = []
	for plot in plots:
		out.append(plot_id(plot.x, plot.y))
	return out

## Snapshot para o save. Plot intocado fica de fora.
func to_dict() -> Dictionary:
	var plots := {}
	for id in plot_ids():
		var plot := _plots[id] as Plot
		if plot.is_default():
			continue
		plots[id] = plot.to_dict()
	return {"plots": plots}

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai
## no default — é assim que campo novo entra sem migração.
func from_dict(data: Dictionary) -> void:
	_plots.clear()
	var plots: Dictionary = data.get("plots", {})
	for chave: Variant in plots.keys():
		var partes := String(chave).split(":")
		if partes.size() != 2:
			continue
		var plot := Plot.new(int(partes[0]), int(partes[1]))
		plot.from_dict(plots[chave] as Dictionary)
		# a chave é regravada pela convenção: save antigo com "12:07" continua válido
		_plots[plot_id(plot.x, plot.y)] = plot

## Critério da ordem dos plots: linha primeiro, coluna depois.
func _linha_a_linha(a: Plot, b: Plot) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
