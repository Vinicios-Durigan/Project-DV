class_name ActionRecorder
extends RefCounted

## Rastro de tudo que entrou na simulação: cada ação despachada vira uma linha
## com tipo, campos e hora de jogo. É o bug report determinístico — a ordem mais
## o payload completo bastam para refazer a sessão inteira.
##
## Os campos saem por reflection (`get_property_list`), não por `to_dict` escrito
## à mão em cada ação: ação nova é gravada no dia em que nasce, sem ninguém
## lembrar de registrar nada. Ação continua sendo dado puro, sem método.
##
## O relógio é injetado só para leitura da hora. O gravador não é um `SimSystem`:
## não tick, não emite evento, não muda estado de ninguém.

## Campos de `Object` que a reflection expõe e não interessam ao rastro.
const CAMPOS_IGNORADOS: Array[String] = ["script", "Built-in script"]

var _entries: Array[Dictionary] = []
var _time: TimeState
var _enabled: bool = true

## O relógio é opcional: sem ele a hora sai zerada e a gravação continua. Teste e
## ferramenta solta não precisam montar um mundo só para gravar uma ação.
func _init(time: TimeState = null) -> void:
	_time = time

## Desligar zera o custo em release — `record` vira no-op.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func is_enabled() -> bool:
	return _enabled

## Grava a ação e devolve a entrada criada, ou `null` se nada foi gravado
## (gravador desligado ou ação nula).
func record(action: SimAction) -> Variant:
	if not _enabled or action == null:
		return null
	var entrada := {
		"i": _entries.size(),
		"acao": _nome_da_classe(action),
		"dia": _time.dia if _time != null else 0,
		"minuto": _time.minuto if _time != null else 0,
		"estacao": _time.estacao if _time != null else "",
		"campos": _campos(action),
	}
	_entries.append(entrada)
	return entrada

## Quantas ações a sessão gravou até agora.
func count() -> int:
	return _entries.size()

## O rastro gravado, em ordem de despacho. Cópia: quem lê não mexe no original.
func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)

## Começa uma sessão nova.
func clear() -> void:
	_entries.clear()

## O rastro em JSONL, uma ação por linha — formato de log, não de save: linha
## nova só concatena, e um arquivo cortado no meio continua legível até a última
## linha inteira.
func to_jsonl() -> String:
	var linhas := PackedStringArray()
	for entrada in _entries:
		linhas.append(JSON.stringify(entrada))
	return "\n".join(linhas)

## `class_name` da ação, que é o que identifica a intenção. Sem `class_name` no
## script sobra o nome do arquivo — nunca "RefCounted", que não diria nada.
func _nome_da_classe(action: SimAction) -> String:
	var script := action.get_script() as Script
	if script == null:
		return action.get_class()
	var nome := script.get_global_name()
	return nome if not nome.is_empty() else script.resource_path.get_file().get_basename()

## Campos declarados da ação, próprios e herdados da base, por reflection.
func _campos(action: SimAction) -> Dictionary:
	var campos := {}
	for prop: Dictionary in action.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var nome := String(prop["name"])
		if nome.begins_with("_") or CAMPOS_IGNORADOS.has(nome):
			continue
		campos[nome] = _valor_json(action.get(nome))
	return campos

## Valor que o JSON aceita. Tipo exótico vira texto em vez de derrubar a linha
## inteira — log que some é pior que log com um campo feio.
func _valor_json(valor: Variant) -> Variant:
	match typeof(valor):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return valor
		TYPE_ARRAY, TYPE_DICTIONARY:
			return valor
		_:
			return str(valor)
