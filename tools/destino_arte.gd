class_name DestinoArte
extends RefCounted

## Onde cada tipo de arte mora e como cada arquivo se chama — a seção 1 e a
## seção 2 do `docs/ARTE.md` escritas em código.
##
## Existe para o artista não precisar decorar caminho nem convenção de nome:
## ele escolhe "cultura", digita "trigo", e sai
## `assets/crops/trigo/trigo_estagio_0.png` até `trigo_fruto.png`, na ordem
## certa. Errar a pasta ou o sufixo é o jeito mais comum de a arte não aparecer
## no jogo (`ARTE.md` §10), e é justamente o que dá para automatizar.
##
## Se o `ARTE.md` mudar de convenção, muda aqui — e `tests/test_destino_arte.gd`
## é quem percebe se as duas coisas se separarem.

enum Tipo { ITEM, CULTURA, OBJETO, TILE, UI, PERSONAGEM, PARTICULA, LIVRE }

## Rótulo, pasta e lado da célula padrão de cada tipo. `celula = 0` significa
## "sem tamanho fixo": personagem é 16×32 e partícula varia, então nesses o
## recorte sai justo e quem decide é o olho.
const TABELA: Dictionary = {
	Tipo.ITEM: {
		"rotulo": "Item — ferramenta, colheita, comida",
		"pasta": "res://assets/items",
		"celula": 16,
		"por_slug": false,
	},
	Tipo.CULTURA: {
		"rotulo": "Cultura — estágios, semente e fruto",
		"pasta": "res://assets/crops",
		"celula": 16,
		"por_slug": true,
	},
	Tipo.OBJETO: {
		"rotulo": "Objeto do mundo — caixote, cerca, placa",
		"pasta": "res://assets/objects",
		"celula": 16,
		"por_slug": false,
	},
	Tipo.TILE: {
		"rotulo": "Chão — tileset",
		"pasta": "res://assets/tiles",
		"celula": 16,
		"por_slug": false,
	},
	Tipo.UI: {
		"rotulo": "UI — slot, retículo, moldura",
		"pasta": "res://assets/ui",
		"celula": 0,
		"por_slug": false,
	},
	Tipo.PERSONAGEM: {
		"rotulo": "Personagem — 16×32, não quadrado",
		"pasta": "res://assets/player",
		"celula": 0,
		"por_slug": false,
	},
	Tipo.PARTICULA: {
		"rotulo": "Partícula — 2 a 3 quadros",
		"pasta": "res://assets/fx",
		"celula": 0,
		"por_slug": false,
	},
	Tipo.LIVRE: {
		"rotulo": "Outro — eu digito a pasta",
		"pasta": "",
		"celula": 0,
		"por_slug": false,
	},
}

## Os nomes que o `ARTE.md` §2 exige de toda cultura, na ordem de leitura em que
## o artista costuma desenhar: os estágios crescendo, depois os dois ícones.
const SUFIXO_ESTAGIO: String = "_estagio_%d"
const SUFIXO_SEMENTE: String = "_semente"
const SUFIXO_FRUTO: String = "_fruto"
const ESTAGIOS_PADRAO: int = 4


static func tipos_em_ordem() -> Array[Tipo]:
	return [Tipo.ITEM, Tipo.CULTURA, Tipo.OBJETO, Tipo.TILE, Tipo.UI,
		Tipo.PERSONAGEM, Tipo.PARTICULA, Tipo.LIVRE]


static func rotulo(tipo: Tipo) -> String:
	return String(TABELA[tipo]["rotulo"])


## Lado da célula que o projeto espera para este tipo. 0 = sem padrão.
static func celula(tipo: Tipo) -> int:
	return int(TABELA[tipo]["celula"])


## Cultura mora em subpasta própria (`assets/crops/trigo/`), o resto mora na
## pasta do tipo. É a única diferença estrutural entre eles.
static func precisa_de_slug(tipo: Tipo) -> bool:
	return bool(TABELA[tipo]["por_slug"])


## A pasta final, já com o slug quando o tipo pede um.
static func pasta(tipo: Tipo, slug: String = "") -> String:
	var base: String = String(TABELA[tipo]["pasta"])
	if base.is_empty():
		return ""
	if not precisa_de_slug(tipo):
		return base
	var limpo: String = normaliza_slug(slug)
	return base if limpo.is_empty() else base.path_join(limpo)


## Nome de arquivo é contrato: minúsculo, sem acento, sublinhado e não hífen
## (`ARTE.md` §10). Normalizar aqui evita o erro que só aparece no jogo, com o
## sprite faltando e ninguém sabendo por quê.
static func normaliza_slug(bruto: String) -> String:
	var texto: String = bruto.strip_edges().to_lower()
	const ACENTOS: Dictionary = {
		"á": "a", "à": "a", "ã": "a", "â": "a", "ä": "a",
		"é": "e", "ê": "e", "è": "e",
		"í": "i", "î": "i",
		"ó": "o", "õ": "o", "ô": "o", "ö": "o",
		"ú": "u", "û": "u", "ü": "u",
		"ç": "c", "ñ": "n",
	}
	for acentuado: String in ACENTOS:
		texto = texto.replace(acentuado, String(ACENTOS[acentuado]))

	var limpo: String = ""
	for i in texto.length():
		var letra: String = texto[i]
		if letra.is_valid_identifier() or (letra >= "0" and letra <= "9"):
			limpo += letra
		elif letra == "_" or letra == "-" or letra == " ":
			limpo += "_"
	while limpo.contains("__"):
		limpo = limpo.replace("__", "_")
	return limpo.strip_edges().trim_prefix("_").trim_suffix("_")


## Os nomes que o tipo já sabe de cor, na ordem de leitura.
##
## Cultura tem convenção fechada — estágios, semente, fruto — e é a única em que
## dá para acertar sem o artista digitar nada. Nos outros tipos o palpite seria
## chute, então devolve vazio e quem nomeia é ele.
static func nomes_sugeridos(tipo: Tipo, slug: String, quantos: int) -> PackedStringArray:
	var nomes: PackedStringArray = PackedStringArray()
	if tipo != Tipo.CULTURA or quantos <= 0:
		return nomes

	var limpo: String = normaliza_slug(slug)
	if limpo.is_empty():
		return nomes

	# Os dois últimos recortes são semente e fruto; o resto são os estágios.
	# Com poucos recortes o artista está mandando só parte da cultura, então o
	# que sobra vira estágio e ele corrige o que quiser.
	var estagios: int = maxi(0, quantos - 2)
	for i in estagios:
		nomes.append(limpo + SUFIXO_ESTAGIO % i)
	if quantos - estagios >= 2:
		nomes.append(limpo + SUFIXO_SEMENTE)
	if quantos - estagios >= 1:
		nomes.append(limpo + SUFIXO_FRUTO)
	return nomes


## Os sufixos que marcam um arquivo como parte de uma cultura. O que vem antes
## deles é o nome da cultura — e, portanto, a subpasta.
const SUFIXOS_DE_CULTURA: Array[String] = ["_estagio_", SUFIXO_SEMENTE, SUFIXO_FRUTO]


## O nome da cultura lido do nome do arquivo: `cenoura_estagio_0` → `cenoura`.
##
## É o que deixa uma folha misturada funcionar. O artista nomeia a peça e marca
## "Cultura"; a subpasta sai do nome, sem ele digitar a mesma palavra de novo
## num segundo campo.
##
## Devolve vazio quando o nome não segue a convenção — aí quem responde é o
## slug padrão da janela.
static func slug_do_nome(nome: String) -> String:
	for sufixo in SUFIXOS_DE_CULTURA:
		var corte: int = nome.find(sufixo)
		if corte > 0:
			return normaliza_slug(nome.substr(0, corte))
	return ""


## Quantos recortes o tipo espera. 0 = qualquer número serve.
static func quantidade_esperada(tipo: Tipo) -> int:
	return ESTAGIOS_PADRAO + 2 if tipo == Tipo.CULTURA else 0


## O aviso a mostrar quando a contagem não bate com o que o tipo espera. Vazio
## quando está tudo certo — cultura com número errado de sprites é o erro que
## quebra o `.tres` depois, e vale gritar antes de gravar.
static func aviso_de_quantidade(tipo: Tipo, quantos: int) -> String:
	var esperado: int = quantidade_esperada(tipo)
	if esperado == 0 or quantos == esperado:
		return ""
	return ("cultura costuma ter %d sprites (%d estágios + semente + fruto) e a folha tem %d"
		% [esperado, ESTAGIOS_PADRAO, quantos])


static func tipo_por_nome(nome: String) -> Tipo:
	match nome.strip_edges().to_lower():
		"item", "itens":
			return Tipo.ITEM
		"cultura", "crop", "planta":
			return Tipo.CULTURA
		"objeto", "objetos":
			return Tipo.OBJETO
		"tile", "tiles", "chao", "chão":
			return Tipo.TILE
		"ui", "hud":
			return Tipo.UI
		"personagem", "player":
			return Tipo.PERSONAGEM
		"particula", "partícula", "fx":
			return Tipo.PARTICULA
		_:
			return Tipo.LIVRE


static func nomes_de_tipo_aceitos() -> String:
	return "item, cultura, objeto, tile, ui, personagem, particula"
