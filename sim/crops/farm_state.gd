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
	## Quantas viradas de dia a mais esta rega aguenta. Zero é a rega comum, que
	## seca na primeira noite — o default é o comportamento de antes da wave 17.
	##
	## Quem enche este número é a Rega funda, e quem decide **quais** canteiros
	## ganham é o jogador, pela ordem em que rega.
	var dias_de_agua: int = 0

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
			and estagio == 0 and dias_no_estagio == 0 and dias_de_agua == 0

	func to_dict() -> Dictionary:
		return {
			"arada": arada,
			"regada": regada,
			"crop_id": crop_id,
			"estagio": estagio,
			"dias_no_estagio": dias_no_estagio,
			"dias_de_agua": dias_de_agua,
		}

	func from_dict(data: Dictionary) -> void:
		arada = bool(data.get("arada", false))
		regada = bool(data.get("regada", false))
		crop_id = String(data.get("crop_id", ""))
		estagio = int(data.get("estagio", 0))
		dias_no_estagio = int(data.get("dias_no_estagio", 0))
		# Campo novo da wave 17: ausente é rega comum, que é como toda rega era.
		dias_de_agua = maxi(int(data.get("dias_de_agua", 0)), 0)


var _plots: Dictionary = {}

## A cópia local das vantagens que **a lavoura** cobra: vantagem_id -> nível.
## Chega por `VantagemEscolhidaEvent` e mora aqui, e não no state dos ofícios,
## porque nenhum sistema lê state alheio. O que cada uma faz é tabela do
## `FarmSystem`.
var _vantagens: Dictionary = {}

## A cultura da Colheita especializada, vinda no evento. Vazia é ninguém
## especializado — o default de antes da wave 17.
var _cultura_especializada: String = ""

## Quantos canteiros já beberam água funda hoje. Zera na virada do dia, e é o que
## faz a cota ser do dia e não da partida.
var _regas_fundas_hoje: int = 0

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


# --- As vantagens da lavoura (wave 17) ---

## Que nível desta vantagem a lavoura recebeu. Zero é não ter, e é o default que
## preserva o comportamento de antes da wave 17.
func nivel_da_vantagem(vantagem_id: String) -> int:
	return int(_vantagens.get(vantagem_id, 0))

## Guarda o nível de uma vantagem que este sistema cobra. Nível menor é ignorado:
## escolha comprada não volta, e um evento repetido não pode rebaixar ninguém.
func guarda_vantagem(vantagem_id: String, nivel: int) -> void:
	if nivel <= 0 or nivel_da_vantagem(vantagem_id) >= nivel:
		return
	_vantagens[vantagem_id] = nivel

## A cultura que rende a mais, ou `""` se ninguém se especializou.
func cultura_especializada() -> String:
	return _cultura_especializada

## Carimba a cultura da especialização. A primeira escolha é a única — a mesma
## permanência que o `EstadoOficios` guarda do outro lado.
func define_cultura_especializada(cultura: String) -> void:
	if cultura.is_empty() or not _cultura_especializada.is_empty():
		return
	_cultura_especializada = cultura

## Quantos canteiros já beberam água funda hoje.
func regas_fundas_hoje() -> int:
	return _regas_fundas_hoje

## Mais um canteiro na cota do dia. Quem decide se ainda cabe é o `FarmSystem`,
## que é quem conhece o tamanho da cota — o state só conta.
func conta_rega_funda() -> void:
	_regas_fundas_hoje += 1

## Cota cheia de novo. É o que a virada do dia faz.
func zera_regas_fundas() -> void:
	_regas_fundas_hoje = 0


## Snapshot para o save. Plot intocado fica de fora.
func to_dict() -> Dictionary:
	var plots := {}
	for id in plot_ids():
		var plot := _plots[id] as Plot
		if plot.is_default():
			continue
		plots[id] = plot.to_dict()
	return {
		"plots": plots,
		"vantagens": _vantagens.duplicate(),
		"cultura_especializada": _cultura_especializada,
		"regas_fundas_hoje": _regas_fundas_hoje,
	}

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai
## no default — é assim que campo novo entra sem migração.
func from_dict(data: Dictionary) -> void:
	_plots.clear()

	# Campos novos da wave 17. Ausentes é lavoura sem vantagem nenhuma — o estado
	# de todo save anterior, e é o que dispensa migração.
	_vantagens = {}
	var compradas: Dictionary = data.get("vantagens", {})
	for chave: Variant in compradas:
		var nivel := maxi(int(compradas[chave]), 0)
		if nivel <= 0:
			continue
		_vantagens[String(chave)] = nivel
	_cultura_especializada = String(data.get("cultura_especializada", ""))
	_regas_fundas_hoje = maxi(int(data.get("regas_fundas_hoje", 0)), 0)

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
