class_name ItemCatalog
extends RefCounted

## Catálogo de definições de item, com lookup por id.
##
## Definições são leitura livre: qualquer sistema pode consultar o catálogo.
## O que é proibido é ler *state* alheio.

const DIR_PADRAO: String = "res://data/items"

var _defs: Dictionary = {}

## Registra uma definição. Id repetido sobrescreve; definição sem id é ignorada.
func register(def: ItemDef) -> void:
	if def == null or def.id.is_empty():
		return
	_defs[def.id] = def

func has(item_id: String) -> bool:
	return _defs.has(item_id)

## Definição do item, ou `null` se o id não existe.
func get_def(item_id: String) -> ItemDef:
	return _defs.get(item_id, null) as ItemDef

func size() -> int:
	return _defs.size()

## Ids registrados, em ordem alfabética — a ordem não pode depender de inserção.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs.keys():
		out.append(id)
	out.sort()
	return out

## Stack máximo do item; id sem definição cai no padrão.
func stack_max_of(item_id: String) -> int:
	var def := get_def(item_id)
	return def.stack_max if def != null else ItemDef.STACK_MAX_PADRAO

## Carrega todo `.tres` do diretório. Devolve quantas definições entraram.
## Diretório inexistente não é erro: catálogo vazio.
func load_from_dir(dir_path: String = DIR_PADRAO) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var carregados := 0
	var nomes := dir.get_files()
	nomes.sort()
	for nome in nomes:
		# em build exportada o .tres vira .tres.remap
		var arquivo := nome.trim_suffix(".remap")
		if not arquivo.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(dir_path.path_join(arquivo)) as ItemDef
		if def == null:
			continue
		register(def)
		carregados += 1
	return carregados
