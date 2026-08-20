class_name CropCatalog
extends RefCounted

## Catálogo de definições de cultura, com lookup por id.
##
## Definições são leitura livre: qualquer sistema (e `game/`, para montar a
## ação de plantio) pode consultar o catálogo. O que é proibido é ler *state*
## alheio.

const DIR_PADRAO: String = "res://data/crops"

var _defs: Dictionary = {}

## Registra uma definição. Id repetido sobrescreve; definição sem id é ignorada.
func register(def: CropDef) -> void:
	if def == null or def.id.is_empty():
		return
	_defs[def.id] = def

func has(crop_id: String) -> bool:
	return _defs.has(crop_id)

## Definição da cultura, ou `null` se o id não existe.
func get_def(crop_id: String) -> CropDef:
	return _defs.get(crop_id, null) as CropDef

func size() -> int:
	return _defs.size()

## Ids registrados, em ordem alfabética — a ordem não pode depender de inserção.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs.keys():
		out.append(id)
	out.sort()
	return out

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
		var def := ResourceLoader.load(dir_path.path_join(arquivo)) as CropDef
		if def == null:
			continue
		register(def)
		carregados += 1
	return carregados
