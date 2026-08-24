class_name Cidade
extends Node2D

## A cidade na tela: um nó por estabelecimento que a sim conhece.
##
## **Quais** prédios existem é da sim (`SistemaCidade.ids()`); **onde** cada um
## fica é apresentação e é decidido aqui — a mesma divisão já travada em
## `MundoEsboco.tiles_do_predio`. Por isso a posição sai de uma **conta pela
## ordem da lista**, e não de um campo no `.tres`: layout não é conteúdo, e um
## `.tres` que soubesse a própria coordenada obrigaria o artista a pensar em
## pixel para cadastrar um prédio.
##
## Moinho, padaria e ferreiro são a **mesma cena**, carimbada com id e sprite
## diferentes — conteúdo é id, não classe. Estabelecimento novo é um `.tres`
## novo: ele aparece no mapa sozinho, sem ninguém editar cena nem código. É a
## mesma promessa que `CropDef` já cumpre para as culturas.
##
## Nenhum `if` de regra mora aqui. Este nó não sabe o que é cota, prazo ou
## contrato: ele planta os prédios e sai da frente.

const MOLDE: PackedScene = preload("res://game/cidade/estabelecimento.tscn")

## O tile do mundo visual em pixels, o mesmo do esboço (wave 13).
const TILE: float = 48.0

## Onde o primeiro prédio nasce, relativo a este nó.
@export var origem: Vector2 = Vector2.ZERO

## Daqui até o próximo prédio. Cinco tiles é o respiro do esboço: perto o
## bastante para dois prédios caberem na tela juntos, longe o bastante para a
## caminhada entre eles custar relógio — e tempo é o que precifica a rota do
## dia (PRINCIPIOS §8).
@export var espaco: Vector2 = Vector2(0.0, TILE * 5.0)

var _bridge: SimBridge = null

## id -> o nó plantado. Existe para achar um prédio sem varrer filhos, e para
## `predio()` responder `null` em vez de estourar num id que a sim não conhece.
var _predios: Dictionary = {}


## A bridge chega por injeção — a `SimBridge` só injeta nos filhos diretos
## dela, então a cena que hospeda a cidade precisa repassar. Plantar acontece
## aqui e não no `_ready` porque sem a sim não há lista de prédios para plantar.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_planta_tudo()


# --- Leitura ---

## Os ids na ordem em que aparecem no mapa. Sai da sim: o mapa não inventa
## prédio nem esconde nenhum.
func ids() -> Array[String]:
	var sistema := _sistema()
	return sistema.ids() if sistema != null else ([] as Array[String])

## O nó de um estabelecimento, ou `null` se a sim não conhece esse id.
func predio(id: String) -> Estabelecimento:
	return _predios.get(id, null) as Estabelecimento

## Quantos prédios estão plantados.
func plantados() -> int:
	return _predios.size()

## Onde nasce o prédio de índice `indice`. Conta, não tabela — é o que deixa o
## prédio novo achar o próprio lugar.
func posicao_de(indice: int) -> Vector2:
	return origem + espaco * indice


# --- Plantio ---

func _planta_tudo() -> void:
	var sistema := _sistema()
	if sistema == null:
		return
	var indice := 0
	for id in sistema.ids():
		_planta(id, sistema.def_de(id), indice)
		indice += 1

## Um prédio: a mesma cena, carimbada. Os campos são preenchidos **antes** do
## `add_child` porque é ele que dispara o `_ready` do nó — depois seria tarde
## para a arte e a âncora do pé.
##
## `Icones.textura` devolve `null` quando o `.tres` ainda não tem sprite, e o
## prédio nasce sem desenho em vez de quebrar: a arte é a última coisa a chegar
## e não pode ser a primeira a ser exigida.
func _planta(id: String, def: DefEstabelecimento, indice: int) -> void:
	var no: Estabelecimento = MOLDE.instantiate()
	no.name = id
	no.id_estabelecimento = id
	if def != null:
		no.textura = Icones.textura(def.sprite)
	no.position = posicao_de(indice)
	add_child(no)
	no.setup(_bridge)
	_predios[id] = no

func _sistema() -> SistemaCidade:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			return system as SistemaCidade
	return null
