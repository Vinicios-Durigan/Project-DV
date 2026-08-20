class_name EventLogger
extends RefCounted

## Rastro de tudo que saiu da simulação: cada evento emitido vira uma linha em
## `user://logs/`, com tipo, campos e hora de jogo. Junto com o `ActionRecorder`
## fecha o bug report determinístico — o que entrou e o que a sim afirmou.
##
## JSONL de propósito: linha nova só concatena (nada é reescrito), cada linha vai
## para o disco na hora, e um arquivo cortado por um crash continua legível até a
## última linha inteira. Log serve justamente para o caso em que o jogo não
## terminou bem.
##
## Um arquivo por sessão: sessão nova nunca sobrescreve o log da sessão em que o
## bug aconteceu.
##
## Os campos saem por reflection, não por `to_dict` em cada evento: evento novo é
## logado no dia em que nasce. Evento continua sendo dado puro, sem método.
##
## Não é um `SimSystem`: não tick, não emite evento, não muda estado de ninguém.
## Quem loga é quem chama — `game/` passa a saída de `handle`/`advance` para cá.

const DIRETORIO_PADRAO: String = "user://logs"
const EXTENSAO: String = ".jsonl"
const PREFIXO_SESSAO: String = "sessao_"

## Campos de `Object` que a reflection expõe e não interessam ao log.
const CAMPOS_IGNORADOS: Array[String] = ["script", "Built-in script"]

var _time: TimeState
var _diretorio: String
var _sessao: String
var _arquivo: FileAccess
var _count: int = 0
var _enabled: bool = true

## Relógio, diretório e nome da sessão são todos injetáveis: o teste não escreve
## no log do jogador, e sem relógio a hora sai zerada em vez de quebrar.
func _init(time: TimeState = null, diretorio: String = DIRETORIO_PADRAO, sessao: String = "") -> void:
	_time = time
	_diretorio = diretorio.trim_suffix("/")
	_sessao = sessao if not sessao.is_empty() else _nome_de_sessao()

## Arquivo desta sessão. Existe como caminho antes de existir em disco: o
## arquivo só nasce no primeiro evento, para sessão sem nada logado não deixar
## lixo vazio.
func get_path() -> String:
	return "%s/%s%s" % [_diretorio, _sessao, EXTENSAO]

## Desligar zera o custo em release — `log` vira no-op e o disco nem é tocado.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func is_enabled() -> bool:
	return _enabled

## Quantos eventos esta sessão escreveu.
func count() -> int:
	return _count

## Escreve o evento. Devolve `false` quando nada foi escrito — desligado, evento
## nulo ou disco indisponível. Falha de log nunca derruba a sim: quem chama pode
## ignorar o retorno com segurança.
func log(event: SimEvent) -> bool:
	if not _enabled or event == null:
		return false
	if not _garante_arquivo():
		return false
	var linha := {
		"i": _count,
		"evento": _nome_da_classe(event),
		"dia": _time.dia if _time != null else 0,
		"minuto": _time.minuto if _time != null else 0,
		"estacao": _time.estacao if _time != null else "",
		"campos": _campos(event),
	}
	_arquivo.store_line(JSON.stringify(linha))
	# flush por linha: o log só vale se sobreviver ao crash que ele explica
	_arquivo.flush()
	_count += 1
	return true

## Escreve a saída inteira de um `handle` ou `advance`, na ordem em que os
## eventos aconteceram. Devolve quantos entraram no arquivo.
func log_batch(events: Array[SimEvent]) -> int:
	var escritos := 0
	for event in events:
		# self. explícito: `log` sem ele resolve para a função global de logaritmo
		if self.log(event):
			escritos += 1
	return escritos

## Fecha o arquivo da sessão. Chamar de novo não faz nada.
func close() -> void:
	if _arquivo == null:
		return
	_arquivo.close()
	_arquivo = null

## Abre o arquivo no primeiro evento e o mantém aberto pelo resto da sessão.
func _garante_arquivo() -> bool:
	if _arquivo != null:
		return true
	if not DirAccess.dir_exists_absolute(_diretorio):
		if DirAccess.make_dir_recursive_absolute(_diretorio) != OK:
			return false
	# WRITE trunca, e é o que se quer: o nome carrega a sessão, então cada arquivo
	# nasce vazio e ninguém sobrescreve o log de outra sessão
	_arquivo = FileAccess.open(get_path(), FileAccess.WRITE)
	return _arquivo != null

## Nome de sessão default: a hora do relógio do sistema, que é o que o jogador
## sabe dizer ao mandar o log ("travou umas nove da noite").
func _nome_de_sessao() -> String:
	var agora := Time.get_datetime_string_from_system(false, true)
	return PREFIXO_SESSAO + agora.replace(":", "-").replace(" ", "_")

## `class_name` do evento, que é o que identifica o fato consumado.
func _nome_da_classe(event: SimEvent) -> String:
	var script := event.get_script() as Script
	if script == null:
		return event.get_class()
	var nome := script.get_global_name()
	return nome if not nome.is_empty() else script.resource_path.get_file().get_basename()

## Campos declarados do evento, próprios e herdados, por reflection.
##
## Espelha o `_campos` do `ActionRecorder` de propósito: são dois rastros
## independentes (o que entra e o que sai), e um helper comum acoplaria o log de
## eventos ao gravador de ações sem ninguém ganhar nada.
func _campos(event: SimEvent) -> Dictionary:
	var campos := {}
	for prop: Dictionary in event.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var nome := String(prop["name"])
		if nome.begins_with("_") or CAMPOS_IGNORADOS.has(nome):
			continue
		campos[nome] = _valor_json(event.get(nome))
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
