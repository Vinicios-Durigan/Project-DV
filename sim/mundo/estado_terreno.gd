class_name EstadoTerreno
extends RefCounted

## O que cobre cada tile da fazenda — dono exclusivo do `SistemaTerreno`.
##
## ## Cobertura não é plot
##
## O `FarmState` guarda o que o **jogador fez** com o tile: arou, plantou,
## regou. Aqui fica o que o **mundo** pôs lá: a pedra que sempre esteve, o mato
## que voltou. São dois donos escrevendo no mesmo endereço, e é por isso que o
## `SistemaTerreno` lê o `FarmState` mas nunca escreve nele — quem desara um
## tile coberto é o `FarmSystem`, reagindo ao evento.
##
## ## Tile ausente é livre
##
## Mesma escolha do plot ausente ser intocado. Um mapa recém-criado não tem
## entrada nenhuma, e o save de antes da wave 14 carrega como fazenda limpa —
## é o que dispensa migração. Guardar `livre` explicitamente encheria o arquivo
## de nada.
##
## ## Limpar é tabela, não `if`
##
## `VIRA_AO_LIMPAR` diz no que cada cobertura se transforma. Árvore vira toco
## (dois golpes, não um), toco e pedra e mato somem de uma vez. Água **não está
## na tabela**, e isso é decisão de design, não lacuna: nenhuma ferramenta
## futura seca um poço.
##
## ## Entulho limpo não volta
##
## Não há nada aqui que reponha pedra ou árvore. É o que separa gate espacial de
## grind de coleta (PRINCIPIOS §8): o que você limpou é seu para sempre. Só o
## mato volta, e só por propagação a partir de um vizinho — quem faz isso é o
## sistema.
##
## Todo campo tem default e entra no bloco `terreno` do save por
## `to_dict`/`from_dict`.

## Chão livre. É a ausência de entrada, nunca um valor guardado.
const LIVRE: String = "livre"
## Volta sozinho, a partir de vizinho. O único que respawna.
const MATO: String = "mato"
const PEDRA: String = "pedra"
## Dois golpes: vira `TOCO` antes de sair.
const ARVORE: String = "arvore"
const TOCO: String = "toco"
## O poço. Não se limpa, e é de onde a água vem.
const AGUA: String = "agua"

const COBERTURAS: Array[String] = [LIVRE, MATO, PEDRA, ARVORE, TOCO, AGUA]

## No que cada cobertura vira ao ser limpa. Quem não está aqui não sai do lugar.
const VIRA_AO_LIMPAR: Dictionary = {
	MATO: LIVRE,
	PEDRA: LIVRE,
	ARVORE: TOCO,
	TOCO: LIVRE,
}

## A semente da fazenda quando ninguém escolheu outra.
##
## Fixa de propósito: `sim/` **nunca sorteia sozinha** (regra de determinismo).
## Quem quiser uma fazenda diferente a cada partida passa outro número na
## criação do mundo — e aí é `game/`, que pode sortear, quem decide. Aqui dentro,
## mesma semente é sempre a mesma fazenda.
const SEMENTE_PADRAO: int = 20260822


## A semente do sorteio do terreno, no save.
var semente: int = SEMENTE_PADRAO

## "x:y" -> cobertura. Tile livre **não** tem entrada.
var _tiles: Dictionary = {}

## "x:y" -> dias que o tile está arado e vazio. Zerado não tem entrada.
##
## Mora aqui, e não no `Plot`, porque quem lê esse número é o terreno: é ele que
## decide quando o preparo não usado fecha de novo. O `FarmState` continua sem
## saber que existe mato.
var _ociosos: Dictionary = {}


## O endereço do tile. É **a mesma chave** do `FarmState` de propósito: dois
## formatos para o mesmo tile seria bug garantido no dia em que alguém cruzasse
## os dois dicionários.
static func tile_id(x: int, y: int) -> String:
	return FarmState.plot_id(x, y)


# --- Leitura ---

func cobertura(x: int, y: int) -> String:
	return String(_tiles.get(tile_id(x, y), LIVRE))

func e_livre(x: int, y: int) -> bool:
	return not _tiles.has(tile_id(x, y))

## Ids com cobertura, em ordem alfabética. A ordem é contrato: o save tem que
## sair igual duas vezes, e a sequência de eventos da noite também.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _tiles.keys():
		out.append(id)
	out.sort()
	return out

## Esta cobertura sai do caminho com o golpe certo?
func pode_limpar(x: int, y: int) -> bool:
	return VIRA_AO_LIMPAR.has(cobertura(x, y))

## No que este tile viraria se fosse limpo, ou `""` se não há o que tirar.
## Responde sem aplicar — é a consulta que o resolvedor e `game/` usam.
func vira_ao_limpar(x: int, y: int) -> String:
	return String(VIRA_AO_LIMPAR.get(cobertura(x, y), ""))

## Há quantos dias este tile está arado e vazio.
func dias_ocioso(x: int, y: int) -> int:
	return int(_ociosos.get(tile_id(x, y), 0))


# --- Escrita ---

## Escreve a cobertura. `LIVRE` apaga a entrada — livre é ausência. Cobertura
## fora da lista é ignorada em silêncio, como local inválido no `EstadoLocais`.
func define_cobertura(x: int, y: int, nova: String) -> void:
	if not COBERTURAS.has(nova):
		return
	var id := tile_id(x, y)
	if nova == LIVRE:
		_tiles.erase(id)
		return
	_tiles[id] = nova

## Aplica um golpe e devolve a cobertura resultante, ou `""` se não havia o que
## limpar. Árvore precisa de dois: o primeiro devolve `TOCO`.
func limpa(x: int, y: int) -> String:
	var nova := vira_ao_limpar(x, y)
	if nova.is_empty():
		return ""
	define_cobertura(x, y, nova)
	return nova

## Escreve o contador do arado ocioso. Zero apaga a entrada — plantou, o relógio
## para e some do save.
func marca_ocioso(x: int, y: int, dias: int) -> void:
	var id := tile_id(x, y)
	if dias <= 0:
		_ociosos.erase(id)
		return
	_ociosos[id] = dias


# --- Save ---

func to_dict() -> Dictionary:
	var tiles: Dictionary = {}
	for id in ids():
		tiles[id] = String(_tiles[id])
	var ociosos: Dictionary = {}
	var arados: Array[String] = []
	for id: String in _ociosos.keys():
		arados.append(id)
	arados.sort()
	for id in arados:
		ociosos[id] = int(_ociosos[id])
	return {
		"semente": semente,
		"tiles": tiles,
		"ociosos": ociosos,
	}

## Carrega do save. Bloco ausente é fazenda limpa — foi assim que a seção
## `terreno` entrou sem migração.
func from_dict(data: Dictionary) -> void:
	_tiles = {}
	_ociosos = {}
	semente = int(data.get("semente", SEMENTE_PADRAO))
	var tiles: Dictionary = data.get("tiles", {})
	for chave: Variant in tiles:
		var id := String(chave)
		var valor := String(tiles[chave])
		if not _id_valido(id) or not COBERTURAS.has(valor) or valor == LIVRE:
			continue
		_tiles[id] = valor
	var ociosos: Dictionary = data.get("ociosos", {})
	for chave: Variant in ociosos:
		var id := String(chave)
		var dias := int(ociosos[chave])
		if not _id_valido(id) or dias <= 0:
			continue
		_ociosos[id] = dias


## Chave malformada é lixo de save: ela nunca casaria com um tile de verdade e
## ficaria para sempre no arquivo.
func _id_valido(id: String) -> bool:
	var partes := id.split(":")
	if partes.size() != 2:
		return false
	return partes[0].is_valid_int() and partes[1].is_valid_int()
