class_name EstadoCorpo
extends RefCounted

## Quanta estamina cada jogador ainda tem no dia — dono exclusivo do
## `SistemaCorpo`.
##
## ## O state é burro
##
## Ele não sabe que arar custa 4 e derrubar árvore custa 12: a tabela de custos
## é do sistema, e aqui só se guarda o número, se desconta com piso em zero, se
## restaura (cheio, pela metade ou de um prato) e se contam as refeições do dia.
## Que a segunda refeição vale metade é tabela do sistema, do mesmo jeito que o
## custo de arar. Mesma escolha do `EstadoCidade`, que não sabe o que é um
## moinho.
##
## ## Jogador ausente está inteiro
##
## Mesma decisão do `EstadoLocais`: quem nunca trabalhou não tem entrada, e o
## save de antes desta wave carrega com todo mundo descansado. É o que faz o
## bloco `corpo` entrar sem migração.
##
## ## Zero é desmaio, não recusa
##
## O state responde `desmaiado()`, mas não impede nada: chegar a zero desmaia o
## jogador (o `TimeSystem` fecha o dia), e nenhuma ação é recusada por cansaço.
## Apertar o botão e nada acontecer, no meio do canteiro, é o pior momento de
## jogo que esta mecânica poderia produzir.

## O corpo cheio. Chute de calibragem, como o `DIAS_POR_CONTRATO` da wave 13:
## um dia de 20 tiles arados, plantados e regados gasta ~180, e o alvo é a barra
## raspar junto com o relógio.
const ESTAMINA_PADRAO: int = 200


## O corpo de um jogador. Nasce cheio e só existe depois que ele trabalhou.
class Corpo extends RefCounted:
	var estamina: int = EstadoCorpo.ESTAMINA_PADRAO
	var maxima: int = EstadoCorpo.ESTAMINA_PADRAO
	## Quantas refeições este corpo já fez hoje. Só a contagem: **quanto** a
	## terceira mordida vale é tabela do `SistemaCorpo`, como o custo de arar.
	var refeicoes_hoje: int = 0

	func to_dict() -> Dictionary:
		return {
			"estamina": estamina,
			"maxima": maxima,
			"refeicoes_hoje": refeicoes_hoje,
		}

	## Save editado à mão não pode criar um corpo impossível: máxima zerada
	## seria desmaio permanente, e estamina acima do teto seria um dia de graça.
	##
	## `refeicoes_hoje` ausente é mesa limpa — é o campo novo da wave 15.1 e é o
	## default que faz o save da wave 15 carregar sem migração.
	func from_dict(data: Dictionary) -> void:
		maxima = int(data.get("maxima", EstadoCorpo.ESTAMINA_PADRAO))
		if maxima <= 0:
			maxima = EstadoCorpo.ESTAMINA_PADRAO
		estamina = clampi(int(data.get("estamina", maxima)), 0, maxima)
		refeicoes_hoje = maxi(int(data.get("refeicoes_hoje", 0)), 0)


## player_id (int) -> Corpo. Jogador ausente está inteiro.
var _jogadores: Dictionary = {}


# --- Leitura ---

## Quanta estamina resta. Jogador nunca visto está descansado.
func estamina_de(player_id: int) -> int:
	var corpo := _jogadores.get(player_id, null) as Corpo
	return corpo.estamina if corpo != null else ESTAMINA_PADRAO

## Quanto cabe neste corpo.
func maxima_de(player_id: int) -> int:
	var corpo := _jogadores.get(player_id, null) as Corpo
	return corpo.maxima if corpo != null else ESTAMINA_PADRAO

## O corpo chegou ao fim. Quem decide o que fazer com isso é o sistema.
func desmaiado(player_id: int) -> bool:
	return estamina_de(player_id) <= 0

## Quantas refeições este jogador já fez hoje. Quem nunca comeu está com a mesa
## limpa, pelo mesmo motivo de quem nunca trabalhou estar inteiro.
##
## É contagem, não saciedade: que a segunda refeição vale metade é tabela do
## `SistemaCorpo`.
func refeicoes_hoje(player_id: int) -> int:
	var corpo := _jogadores.get(player_id, null) as Corpo
	return corpo.refeicoes_hoje if corpo != null else 0

## Jogadores com corpo gravado, em ordem crescente — a ordem não pode depender
## de quem cansou primeiro.
func jogadores() -> Array[int]:
	var ids: Array[int] = []
	for player_id: int in _jogadores.keys():
		ids.append(player_id)
	ids.sort()
	return ids


# --- Escrita ---

## Desconta o trabalho e devolve o que sobrou. Piso em zero: cansaço não fica
## negativo, senão o desmaio de amanhã já começaria devendo.
##
## Custo negativo é ignorado — descansar é assunto do restauro, e um custo que
## enche seria um jeito de o corpo se curar trabalhando.
func gasta(player_id: int, quanto: int) -> int:
	var corpo := _corpo(player_id)
	if quanto <= 0:
		return corpo.estamina
	corpo.estamina = maxi(corpo.estamina - quanto, 0)
	return corpo.estamina

## Devolve estamina no meio do dia e entrega o corpo de agora. Teto na máxima: o
## que passa do topo se perde, e é isso que faz comer cedo demais desperdiçar o
## pão.
##
## Valor negativo é ignorado — cansar é assunto do `gasta()`, e um restauro que
## cansa seria um jeito de a comida virar trabalho.
##
## Não pergunta se o corpo está no chão: quem recusa é o sistema. O state é
## burro, e a regra "desmaiado não come" existe uma vez só.
func restaura(player_id: int, quanto: int) -> int:
	var corpo := _corpo(player_id)
	if quanto <= 0:
		return corpo.estamina
	corpo.estamina = mini(corpo.estamina + quanto, corpo.maxima)
	return corpo.estamina

## Dormir sempre enche. O dia seguinte não depende de como se foi dormir — uma
## variável a menos para calibrar, e a decisão continua dentro do dia.
func enche(player_id: int) -> void:
	var corpo := _corpo(player_id)
	corpo.estamina = corpo.maxima

## O preço do desmaio: acorda com metade. O custo é tempo de trabalho, que é a
## moeda do jogo, e se paga sozinho — quem desmaia hoje rende menos amanhã.
##
## Arredonda para baixo: meia estamina nunca é meio ponto.
func enche_metade(player_id: int) -> void:
	var corpo := _corpo(player_id)
	corpo.estamina = corpo.maxima / 2

## Muda o teto do corpo. Existe para o save e para o dia em que a comida ou uma
## cama melhor levantarem a máxima; máxima menor encolhe a estamina junto,
## porque ninguém carrega mais do que cabe.
##
## Valor inválido é ignorado em silêncio, como cobertura fora da lista no
## `EstadoTerreno`: um corpo de capacidade zero seria desmaio permanente.
func define_maxima(player_id: int, valor: int) -> void:
	if valor <= 0:
		return
	var corpo := _corpo(player_id)
	corpo.maxima = valor
	corpo.estamina = mini(corpo.estamina, valor)

## Anota mais uma refeição e devolve **qual** ela foi — a primeira do dia é 1.
##
## O número devolvido é o que o sistema usa para achar o fator de saciedade. A
## conta não mora aqui: o state conta pratos, não calorias.
func registra_refeicao(player_id: int) -> int:
	var corpo := _corpo(player_id)
	corpo.refeicoes_hoje += 1
	return corpo.refeicoes_hoje

## Mesa limpa. É o que a virada do dia faz, inclusive no colapso: a saciedade é
## do dia, e o dia acabou.
func zera_refeicoes(player_id: int) -> void:
	_corpo(player_id).refeicoes_hoje = 0


# --- Save ---

## Snapshot para o save. Chave de jogador vira string: JSON não tem chave int,
## mesmo formato dos blocos `inventory` e `locais`.
func to_dict() -> Dictionary:
	var jogadores: Dictionary = {}
	for player_id in jogadores():
		jogadores[str(player_id)] = (_jogadores[player_id] as Corpo).to_dict()
	return {"jogadores": jogadores}

## Carrega do save. Bloco ausente é todo mundo descansado — foi assim que a
## seção `corpo` entrou sem migração.
func from_dict(data: Dictionary) -> void:
	_jogadores = {}
	var jogadores: Dictionary = data.get("jogadores", {})
	for chave: Variant in jogadores:
		var bruto: Variant = jogadores[chave]
		if not bruto is Dictionary:
			continue
		var corpo := Corpo.new()
		corpo.from_dict(bruto as Dictionary)
		_jogadores[int(str(chave))] = corpo


# --- Bastidores ---

## O corpo deste jogador, criado cheio na primeira vez que alguém o pede.
func _corpo(player_id: int) -> Corpo:
	if not _jogadores.has(player_id):
		_jogadores[player_id] = Corpo.new()
	return _jogadores[player_id] as Corpo
