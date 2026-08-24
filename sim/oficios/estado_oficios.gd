class_name EstadoOficios
extends RefCounted

## A caderneta do jogador: quanto cada ofício praticou, que nível isso virou,
## quantos pontos sobraram e o que já foi comprado com eles — dono exclusivo do
## `SistemaOficios`.
##
## ## O state é burro
##
## Ele não sabe que arar dá 4 de XP, que o nível 2 de Lavoura pede 300, nem que
## Mãos leves custa 1 ponto e para no teto 2. Tudo isso é tabela do
## `SistemaOficios`, do mesmo jeito que o custo de arar é tabela do
## `SistemaCorpo` e não do `EstadoCorpo`. Aqui só se soma, se guarda o nível que
## mandaram guardar, se credita e se desconta ponto.
##
## ## Ponto preso no ofício
##
## Não existe "pontos do jogador": existem pontos de Lavoura e pontos de Campo,
## em contas separadas por ofício. É o que faz abrir o tabuleiro inteiro obrigar
## a variar o trabalho, em vez de moer um gesto só até comprar tudo.
##
## ## O que sobe não desce
##
## XP só soma, nível não regride, vantagem comprada não volta e a cultura da
## especialização não troca. A permanência é a regra que faz o ponto pesar na
## hora de gastar (PRINCIPIOS §7), e ela é invariante de state — não promessa de
## quem chama. Respec, se um dia doer demais jogando, entra por ação nova.
##
## ## Jogador ausente é folha em branco
##
## Mesma decisão do `EstadoCorpo` e do `EstadoLocais`: quem nunca trabalhou não
## tem entrada, e o save de antes desta wave carrega sem ofício nenhum. É o que
## faz o bloco `oficios` entrar sem migração.


## O que um ofício acumulou. Nasce zerado e só existe depois do primeiro
## trabalho.
class Oficio extends RefCounted:
	## Prática acumulada, na moeda da tabela de estamina: o que cansa mais ensina
	## mais.
	var xp: int = 0
	## O nível que o sistema já reconheceu. Guardado, e não recalculado, para o
	## state não precisar conhecer os limiares.
	var nivel: int = 0
	## Pontos ganhos e ainda não gastos, deste ofício.
	var pontos: int = 0
	## Pontos já convertidos em vantagem. Só para a tela poder contar a história
	## ("2 de 3 gastos") sem refazer a conta do tabuleiro.
	var gastos: int = 0

	func to_dict() -> Dictionary:
		return {
			"xp": xp,
			"nivel": nivel,
			"pontos": pontos,
			"gastos": gastos,
		}

	## Save editado à mão não pode criar uma caderneta impossível: número negativo
	## em qualquer campo vira zero, como a máxima zerada do `EstadoCorpo` vira o
	## padrão.
	func from_dict(data: Dictionary) -> void:
		xp = maxi(int(data.get("xp", 0)), 0)
		nivel = maxi(int(data.get("nivel", 0)), 0)
		pontos = maxi(int(data.get("pontos", 0)), 0)
		gastos = maxi(int(data.get("gastos", 0)), 0)


## A caderneta de um jogador: os ofícios que ele praticou e o que comprou.
class Caderneta extends RefCounted:
	## oficio_id (String) -> Oficio. Ofício nunca praticado não tem entrada — o
	## state não sabe quantos ofícios o jogo tem, e isso é de propósito: ofício
	## novo é uma linha na tabela do sistema, não um campo aqui.
	var oficios: Dictionary = {}
	## vantagem_id (String) -> nível comprado (int). Vantagem não comprada não
	## tem entrada.
	var vantagens: Dictionary = {}
	## A cultura da Colheita especializada. Vazia até a escolha, e depois nunca
	## mais outra.
	var cultura: String = ""

	## Os ofícios praticados, em ordem crescente — a ordem não pode depender de
	## qual foi praticado primeiro, senão o save sai diferente a cada partida.
	func ids_dos_oficios() -> Array[String]:
		var ids: Array[String] = []
		for oficio_id: String in oficios.keys():
			ids.append(oficio_id)
		ids.sort()
		return ids

	func to_dict() -> Dictionary:
		var blocos: Dictionary = {}
		for oficio_id in ids_dos_oficios():
			blocos[oficio_id] = (oficios[oficio_id] as Oficio).to_dict()

		var compradas: Dictionary = {}
		for vantagem_id in _ids_das_vantagens():
			compradas[vantagem_id] = int(vantagens[vantagem_id])

		return {
			"oficios": blocos,
			"vantagens": compradas,
			"cultura": cultura,
		}

	func from_dict(data: Dictionary) -> void:
		oficios = {}
		vantagens = {}
		cultura = String(data.get("cultura", ""))

		var blocos: Dictionary = data.get("oficios", {})
		for chave: Variant in blocos:
			var bruto: Variant = blocos[chave]
			if not bruto is Dictionary:
				continue
			var oficio := Oficio.new()
			oficio.from_dict(bruto as Dictionary)
			oficios[String(chave)] = oficio

		var compradas: Dictionary = data.get("vantagens", {})
		for chave: Variant in compradas:
			var nivel := maxi(int(compradas[chave]), 0)
			if nivel <= 0:
				continue
			vantagens[String(chave)] = nivel

	func _ids_das_vantagens() -> Array[String]:
		var ids: Array[String] = []
		for vantagem_id: String in vantagens.keys():
			ids.append(vantagem_id)
		ids.sort()
		return ids


## player_id (int) -> Caderneta. Jogador ausente é folha em branco.
var _jogadores: Dictionary = {}


# --- Leitura ---

## Quanto este ofício praticou. Ofício nunca tocado está em zero.
func xp_de(player_id: int, oficio_id: String) -> int:
	var oficio := _busca(player_id, oficio_id)
	return oficio.xp if oficio != null else 0

## Que nível o sistema já reconheceu neste ofício.
func nivel_de(player_id: int, oficio_id: String) -> int:
	var oficio := _busca(player_id, oficio_id)
	return oficio.nivel if oficio != null else 0

## Pontos deste ofício ainda por gastar.
func pontos_de(player_id: int, oficio_id: String) -> int:
	var oficio := _busca(player_id, oficio_id)
	return oficio.pontos if oficio != null else 0

## Pontos deste ofício já convertidos em vantagem.
func gastos_de(player_id: int, oficio_id: String) -> int:
	var oficio := _busca(player_id, oficio_id)
	return oficio.gastos if oficio != null else 0

## Que nível desta vantagem o jogador comprou. Zero é não ter.
func nivel_da_vantagem(player_id: int, vantagem_id: String) -> int:
	var caderneta := _jogadores.get(player_id, null) as Caderneta
	if caderneta == null:
		return 0
	return int(caderneta.vantagens.get(vantagem_id, 0))

## Tudo que este jogador comprou: vantagem_id -> nível. Cópia ordenada — quem
## pergunta não escreve na caderneta.
func vantagens_de(player_id: int) -> Dictionary:
	var caderneta := _jogadores.get(player_id, null) as Caderneta
	if caderneta == null:
		return {}
	return (caderneta.to_dict()["vantagens"] as Dictionary).duplicate()

## A cultura da especialização, ou `""` se ela ainda não foi escolhida.
func cultura_de(player_id: int) -> String:
	var caderneta := _jogadores.get(player_id, null) as Caderneta
	return caderneta.cultura if caderneta != null else ""

## Os ofícios que este jogador praticou, em ordem crescente.
func oficios_de(player_id: int) -> Array[String]:
	var caderneta := _jogadores.get(player_id, null) as Caderneta
	return caderneta.ids_dos_oficios() if caderneta != null else [] as Array[String]

## Jogadores com caderneta gravada, em ordem crescente — a ordem não pode
## depender de quem trabalhou primeiro.
func jogadores() -> Array[int]:
	var ids: Array[int] = []
	for player_id: int in _jogadores.keys():
		ids.append(player_id)
	ids.sort()
	return ids


# --- Escrita ---

## Soma prática e devolve o acumulado do ofício.
##
## Valor negativo é ignorado: trabalho não desensina. Quem decide **quanto** cada
## gesto vale é o sistema — aqui só se soma o que mandaram.
func soma_xp(player_id: int, oficio_id: String, quanto: int) -> int:
	var oficio := _oficio(player_id, oficio_id)
	if quanto <= 0:
		return oficio.xp
	oficio.xp += quanto
	return oficio.xp

## Registra o nível que o sistema reconheceu. Nível menor é ignorado — o que foi
## aprendido não se desaprende, e um save editado à mão não rebaixa ninguém.
func define_nivel(player_id: int, oficio_id: String, nivel: int) -> void:
	var oficio := _oficio(player_id, oficio_id)
	if nivel <= oficio.nivel:
		return
	oficio.nivel = nivel

## Credita pontos neste ofício. Crédito negativo é ignorado: tirar ponto de volta
## seria desfazer um nível, e nível não desce.
func credita_pontos(player_id: int, oficio_id: String, quantos: int) -> void:
	if quantos <= 0:
		return
	_oficio(player_id, oficio_id).pontos += quantos

## Desconta pontos e conta o gasto. Piso em zero: ponto não fica negativo.
##
## Não pergunta se dá — quem recusa a compra sem ponto é o sistema, como a recusa
## de comer desmaiado é do `SistemaCorpo` e não do `EstadoCorpo`. O state protege
## a invariante; a regra de jogo mora uma vez só, onde estão os custos.
func gasta_pontos(player_id: int, oficio_id: String, quantos: int) -> int:
	var oficio := _oficio(player_id, oficio_id)
	if quantos <= 0:
		return oficio.pontos
	var cobrado := mini(quantos, oficio.pontos)
	oficio.pontos -= cobrado
	oficio.gastos += cobrado
	return oficio.pontos

## Sobe esta vantagem um nível e devolve o nível novo.
##
## O teto não mora aqui: o state deixa comprar quantas vezes mandarem, e quem
## segura é o `SistemaOficios`, que é quem conhece o tabuleiro.
func compra_vantagem(player_id: int, vantagem_id: String) -> int:
	var caderneta := _caderneta(player_id)
	var nivel := int(caderneta.vantagens.get(vantagem_id, 0)) + 1
	caderneta.vantagens[vantagem_id] = nivel
	return nivel

## Carimba a cultura da especialização. A primeira escolha é a única: cultura
## vazia não apaga, e cultura nova não troca a que já está lá.
func define_cultura(player_id: int, cultura: String) -> void:
	if cultura.is_empty():
		return
	var caderneta := _caderneta(player_id)
	if not caderneta.cultura.is_empty():
		return
	caderneta.cultura = cultura


# --- Save ---

## Snapshot para o save. Chave de jogador vira string: JSON não tem chave int,
## mesmo formato dos blocos `corpo`, `inventory` e `locais`.
func to_dict() -> Dictionary:
	var jogadores: Dictionary = {}
	for player_id in jogadores():
		jogadores[str(player_id)] = (_jogadores[player_id] as Caderneta).to_dict()
	return {"jogadores": jogadores}

## Carrega do save. Bloco ausente é todo mundo sem ofício — foi assim que a
## seção `oficios` entrou sem migração.
func from_dict(data: Dictionary) -> void:
	_jogadores = {}
	var jogadores: Dictionary = data.get("jogadores", {})
	for chave: Variant in jogadores:
		var bruto: Variant = jogadores[chave]
		if not bruto is Dictionary:
			continue
		var caderneta := Caderneta.new()
		caderneta.from_dict(bruto as Dictionary)
		_jogadores[int(str(chave))] = caderneta


# --- Bastidores ---

## A caderneta deste jogador, criada em branco na primeira vez que alguém
## escreve nela.
func _caderneta(player_id: int) -> Caderneta:
	if not _jogadores.has(player_id):
		_jogadores[player_id] = Caderneta.new()
	return _jogadores[player_id] as Caderneta

## O ofício, criado zerado na primeira escrita. Leitura não cria nada: consultar
## a caderneta de quem nunca trabalhou não pode encher o save.
func _oficio(player_id: int, oficio_id: String) -> Oficio:
	var caderneta := _caderneta(player_id)
	if not caderneta.oficios.has(oficio_id):
		caderneta.oficios[oficio_id] = Oficio.new()
	return caderneta.oficios[oficio_id] as Oficio

## O ofício deste jogador, ou `null` se ele nunca o praticou.
func _busca(player_id: int, oficio_id: String) -> Oficio:
	var caderneta := _jogadores.get(player_id, null) as Caderneta
	if caderneta == null:
		return null
	return caderneta.oficios.get(oficio_id, null) as Oficio
