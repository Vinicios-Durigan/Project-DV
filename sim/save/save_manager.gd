class_name SaveManager
extends RefCounted

## Ponte entre o snapshot da sim e o disco: dicionário → JSON → arquivo, e de
## volta.
##
## Não conhece nenhum state: o que entra e sai é dicionário puro. Quem monta o
## snapshot é o `SimWorld`; quem decide quando salvar é `game/`.
##
## **Escrita atômica.** O arquivo definitivo nunca é aberto para escrita. O save
## vai inteiro para um `.tmp` ao lado, é fechado, e só então toma o lugar do
## definitivo por rename. Queda de energia no meio do processo deixa um `.tmp`
## pela metade e o save anterior intacto — nunca um save meio-escrito.
##
## Um slot é um arquivo. Slot que não existe carrega `null`, e é assim que o
## jogo sabe que é jogo novo.

const DIRETORIO_PADRAO: String = "user://saves"
const SLOT_PADRAO: String = "slot_1"
const EXTENSAO: String = ".json"
const EXTENSAO_TEMP: String = ".tmp"

var _diretorio: String

## O diretório é injetável para o teste não escrever no save do jogador.
func _init(diretorio: String = DIRETORIO_PADRAO) -> void:
	_diretorio = diretorio.trim_suffix("/")

## Diretório onde os slots moram.
func get_directory() -> String:
	return _diretorio

## Caminho do arquivo de um slot.
func path_for(slot: String = SLOT_PADRAO) -> String:
	return "%s/%s%s" % [_diretorio, slot, EXTENSAO]

## Existe save neste slot?
func has_slot(slot: String = SLOT_PADRAO) -> bool:
	if slot.is_empty():
		return false
	return FileAccess.file_exists(path_for(slot))

## Grava o dicionário no slot. Devolve `false` se não deu para escrever — quem
## chamou decide o que dizer ao jogador.
func save_slot(data: Dictionary, slot: String = SLOT_PADRAO) -> bool:
	if slot.is_empty():
		return false
	if not _garante_diretorio():
		return false

	var destino := path_for(slot)
	var temporario := destino + EXTENSAO_TEMP

	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	# indentado de propósito: save é o primeiro lugar onde se olha quando um bug
	# de estado aparece, e diff de save legível vale mais que byte economizado
	arquivo.store_string(JSON.stringify(data, "\t"))
	arquivo.close()

	var dir := DirAccess.open(_diretorio)
	if dir == null:
		return false
	# rename por cima do definitivo: é este passo, e só ele, que é atômico
	if dir.rename(temporario, destino) != OK:
		dir.remove(temporario)
		return false
	return true

## Lê o slot. Devolve `null` para slot ausente (jogo novo) e também para
## arquivo ilegível — meio-carregado seria pior que jogo novo.
##
## O dicionário que volta **não** é idêntico ao que foi salvo: JSON não tem
## inteiro, então todo número volta como `float`. Quem devolve o tipo é o
## `from_dict` de cada state, que já converte — por isso nenhum state pode ler
## campo numérico do save sem passar por `int()`.
func load_slot(slot: String = SLOT_PADRAO) -> Variant:
	if not has_slot(slot):
		return null
	var arquivo := FileAccess.open(path_for(slot), FileAccess.READ)
	if arquivo == null:
		return null
	var texto := arquivo.get_as_text()
	arquivo.close()

	# instância em vez de JSON.parse_string: o wrapper estático imprime erro de
	# engine quando o texto não presta, e save corrompido é caso previsto aqui
	var json := JSON.new()
	if json.parse(texto) != OK:
		return null
	var lido: Variant = json.data
	if lido is Dictionary:
		return lido
	return null

## Apaga o slot. Devolve `false` se não havia nada para apagar.
func delete_slot(slot: String = SLOT_PADRAO) -> bool:
	if not has_slot(slot):
		return false
	var dir := DirAccess.open(_diretorio)
	if dir == null:
		return false
	return dir.remove(path_for(slot)) == OK

func _garante_diretorio() -> bool:
	if DirAccess.dir_exists_absolute(_diretorio):
		return true
	return DirAccess.make_dir_recursive_absolute(_diretorio) == OK
