class_name Icones
extends RefCounted

## Carrega o PNG que um `ItemDef` ou `CropDef` aponta, e guarda o que já
## carregou.
##
## `sim/` diz **qual** é o caminho do sprite — é conteúdo do `.tres`, que o
## artista edita. Quem transforma caminho em `Texture2D` é `game/`, porque
## `Texture2D` é tipo de engine e não pode atravessar a fronteira.
##
## Duas coisas justificam a classe existir em vez de um `load()` solto:
##
## - **cache.** A mochila redesenha a cada evento da sim, e são 24 slots. Sem
##   cache seriam 24 `load()` por virada de dia.
## - **arte faltando não quebra nada.** Caminho vazio ou arquivo inexistente
##   devolve `null`, e quem chama volta a desenhar o nome em texto. O
##   playground precisa continuar jogável com meia dúzia de sprites prontos —
##   é essa a promessa do `CLAUDE.md`, e uma tela que só funciona depois que
##   toda a arte chegou seria o contrário dela.

## Caminho → textura já carregada. `null` guardado é resposta também: significa
## "já tentei e não existe", e evita repetir a busca em disco a cada quadro.
static var _carregadas: Dictionary = {}


## A textura de um caminho `res://`, ou `null` se não houver arte ainda.
static func textura(caminho: String) -> Texture2D:
	if caminho.is_empty():
		return null
	if _carregadas.has(caminho):
		return _carregadas[caminho]

	var achada: Texture2D = null
	if ResourceLoader.exists(caminho):
		achada = ResourceLoader.load(caminho) as Texture2D
	_carregadas[caminho] = achada
	return achada


## O ícone de um item, direto do catálogo. Item sem def e item sem sprite dão o
## mesmo resultado — `null`, e a tela cai no texto.
static func do_item(catalogo: ItemCatalog, item_id: String) -> Texture2D:
	if catalogo == null or item_id.is_empty():
		return null
	var def: ItemDef = catalogo.get_def(item_id)
	return null if def == null else textura(def.sprite)


## O sprite de uma cultura no estágio em que ela está.
##
## Índice fora da lista devolve `null` em vez de estourar: uma cultura com três
## sprites e quatro estágios é erro de conteúdo, não motivo para o jogo parar.
## Quem grita sobre isso é o teste dos `.tres`, não a tela.
static func do_estagio(catalogo: CropCatalog, crop_id: String, estagio: int) -> Texture2D:
	if catalogo == null or crop_id.is_empty() or estagio < 0:
		return null
	var def: CropDef = catalogo.get_def(crop_id)
	if def == null or estagio >= def.sprites_estagios.size():
		return null
	return textura(def.sprites_estagios[estagio])


## Esquece o que carregou. Serve para o teste que grava um PNG, olha a tela e
## grava outro no mesmo caminho — sem isto ele veria sempre o primeiro.
static func esquece_tudo() -> void:
	_carregadas.clear()
