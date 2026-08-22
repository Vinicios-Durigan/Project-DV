class_name SistemaTerreno
extends SimSystem

## O chão como recurso escasso: entulho que trava a expansão, mato que volta.
##
## ## O que ele conserta
##
## Arar → plantar → regar → colher era linear: nada disputava o tile com o
## jogador e o layout não importava (PRINCIPIOS §7). Aqui limpar custa golpe, e
## o que você prepara e não usa o mato toma de volta — o espaço vira decisão.
##
## ## Propagação, não chance por tile
##
## Mato só nasce **encostado em mato**. Sorteio por tile livre transformaria a
## fazenda em manutenção: o jogador varrendo o mapa atrás de ruído que apareceu
## sozinho. Encostado, limpar em bloco compacto se defende sozinho e limpar
## espalhado deixa o jogador cercado — o layout da limpeza vira decisão de longo
## prazo, sem uma linha de arte nova.
##
## ## Ele lê o `FarmState`, mas nunca escreve
##
## Precisa saber se o tile arado tem cultura, para não cobrir planta em pé.
## Leitura de state alheio já tinha precedente no `ResolvedorUso` (wave 11.2); o
## que continua sendo só do dono é **escrever**. Quem desara o tile coberto é o
## `FarmSystem`, reagindo ao `TerrenoMudouEvent` — do mesmo jeito que o
## `InventorySystem` reage ao `ItemGrantedEvent`.
##
## ## Por que é o segundo da fila
##
## Logo depois do `SistemaLocais`, e não é organização: `LimparTerrenoAction`
## precisa ser recusada **antes** de qualquer sistema cobrar alguma coisa —
## mesma razão que pôs o Locais em primeiro na wave 12. A propagação da noite
## não depende da posição: ela acontece em `react`, e a fila do `SimWorld`
## oferece o evento a todos.
##
## ## O teto diário
##
## No máximo `MUDANCAS_POR_DIA` mudanças no mapa inteiro por virada. Sem ele, um
## save deixado correndo em ×60 vira floresta enquanto o jogador foi almoçar.

const MOTIVO_FERRAMENTA_ERRADA: String = "ferramenta_errada"
const MOTIVO_NADA_A_LIMPAR: String = "nada_a_limpar"

## Quantos dias um tile arado e vazio aguenta antes de o mato tomar o preparo.
## Três é chute calibrado: só é justo se limpar for rápido o bastante para
## recuperar, e isso se mede jogando.
const DIAS_PARA_FECHAR: int = 3
## A chance de um tile de mato tomar um vizinho por noite.
const CHANCE_DE_INVADIR: float = 0.25
## Teto de mudanças por virada no mapa inteiro.
const MUDANCAS_POR_DIA: int = 3

## A fazenda que nasce: quantas manchas de entulho e que fatia da área elas
## ocupam no total.
const MANCHAS: int = 9
const FRACAO_DE_ENTULHO: float = 0.15
## O que uma mancha pode ser. Mato não entra: ele é o que **volta**, não o que
## já estava — encontrar a fazenda tomada no dia 1 seria começar devendo.
const ENTULHO_INICIAL: Array[String] = [
	EstadoTerreno.PEDRA, EstadoTerreno.ARVORE, EstadoTerreno.TOCO,
]

## A área cultivável, em tiles. Os mesmos 8×6 dos canteiros — o mapa é autoral,
## e o que a semente sorteia é só **onde** o entulho cai dentro dele.
const LARGURA_PADRAO: int = 8
const ALTURA_PADRAO: int = 6

## Onde fica o poço. **Desenhado, não sorteado**: a água é a exceção da wave 14,
## e o que faz dela uma decisão de rota é ter um endereço que o jogador decora.
## Um poço que muda de lugar a cada partida não é rota, é caça ao tesouro.
##
## Ele ocupa um tile cultivável de propósito — a água custa chão, como tudo o
## mais neste mapa. O canto é provisório: "perto da casa" é a intenção, e a casa
## ainda não existe no esboço (wave 14.1, "Em aberto").
const POCO: Vector2i = Vector2i(7, 5)

## Os quatro vizinhos. Diagonal não conta: mato pulando na diagonal fecha um
## bloco por dentro e o jogador não vê chegando.
const VIZINHOS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var _estado: EstadoTerreno
## Leitura pura: só para saber se o tile tem cultura. Nunca escrito.
var _farm: FarmState
var _items: ItemCatalog
var _largura: int
var _altura: int


func _init(estado: EstadoTerreno = null, farm: FarmState = null,
		items: ItemCatalog = null, largura: int = LARGURA_PADRAO,
		altura: int = ALTURA_PADRAO) -> void:
	_estado = estado if estado != null else EstadoTerreno.new()
	_farm = farm if farm != null else FarmState.new()
	_items = items if items != null else ItemCatalog.new()
	_largura = maxi(largura, 1)
	_altura = maxi(altura, 1)


func get_state() -> EstadoTerreno:
	return _estado

func largura() -> int:
	return _largura

func altura() -> int:
	return _altura


# --- Consultas (para `game/`, que nunca decide regra) ---

func cobertura_de(x: int, y: int) -> String:
	return _estado.cobertura(x, y)

## Esta ferramenta tira esta cobertura do caminho? É a pergunta que a mira faz
## antes de despachar, e a mesma que decide a recusa.
func pode_limpar(x: int, y: int, item_id: String) -> bool:
	return _recusa_da_limpeza(x, y, item_id).is_empty()

## O tile está livre para arar? O `ResolvedorUso` pergunta antes de devolver
## `TillPlotAction` — arar por baixo de uma pedra não faz sentido nenhum.
func e_arável(x: int, y: int) -> bool:
	return _estado.e_livre(x, y)


# --- Ações ---

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is LimparTerrenoAction:
		return _limpa(action as LimparTerrenoAction)
	return []


func _limpa(action: LimparTerrenoAction) -> Array[SimEvent]:
	var motivo := _recusa_da_limpeza(action.x, action.y, action.item_id)
	if not motivo.is_empty():
		return [_rejeita(action, motivo)]

	var de := _estado.cobertura(action.x, action.y)
	var para := _estado.limpa(action.x, action.y)
	return [_mudou(action.x, action.y, de, para, TerrenoMudouEvent.POR_LIMPEZA,
			action.player_id)]


## O motivo pelo qual esta limpeza não passa, ou `""`. Uma função só para a
## recusa e para `pode_limpar()` — duas cópias divergiriam.
func _recusa_da_limpeza(x: int, y: int, item_id: String) -> String:
	if not _estado.pode_limpar(x, y):
		return MOTIVO_NADA_A_LIMPAR
	var def := _items.get_def(item_id)
	if def == null or not def.alvos_de_limpeza.has(_estado.cobertura(x, y)):
		return MOTIVO_FERRAMENTA_ERRADA
	return ""


# --- A noite ---

func react(event: SimEvent) -> Array[SimEvent]:
	if event is DayEndedEvent:
		return _passa_a_noite((event as DayEndedEvent).dia_novo)
	return []


## A virada do dia no terreno: o mato avança, e o preparo esquecido fecha.
##
## As fontes de mato são fotografadas **antes** de qualquer mudança: mato que
## nasceu esta noite não propaga na mesma noite, senão uma única moita viraria
## uma onda enquanto o jogador dorme.
func _passa_a_noite(dia: int) -> Array[SimEvent]:
	var eventos: Array[SimEvent] = []
	var fontes := _tiles_com(EstadoTerreno.MATO)

	for fonte in fontes:
		if eventos.size() >= MUDANCAS_POR_DIA:
			break
		var evento := _tenta_invadir(fonte, dia)
		if evento != null:
			eventos.append(evento)

	eventos.append_array(_fecha_arados_ociosos(dia, MUDANCAS_POR_DIA - eventos.size()))
	return eventos


## Um tile de mato tenta um vizinho por noite — um só, sorteado. Tentar os
## quatro faria uma moita virar uma cruz em duas noites.
func _tenta_invadir(fonte: Vector2i, dia: int) -> TerrenoMudouEvent:
	var rng := _rng_de("invade:%d:%d" % [fonte.x, fonte.y], dia)
	if rng.randf() >= CHANCE_DE_INVADIR:
		return null
	var alvo: Vector2i = fonte + VIZINHOS[rng.randi_range(0, VIZINHOS.size() - 1)]
	if not _cabe_mato(alvo):
		return null
	_estado.define_cobertura(alvo.x, alvo.y, EstadoTerreno.MATO)
	return _mudou(alvo.x, alvo.y, EstadoTerreno.LIVRE, EstadoTerreno.MATO,
			TerrenoMudouEvent.POR_INVASAO)


## O tile aceita mato? Precisa estar no mapa, livre e sem planta em pé.
func _cabe_mato(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= _largura or tile.y >= _altura:
		return false
	if not _estado.e_livre(tile.x, tile.y):
		return false
	return not _farm.peek_plot(tile.x, tile.y).tem_cultura()


## O preparo que ninguém usou volta a ser mato. Conta só tile **arado e vazio**:
## quem plantou zera o relógio, e é isso que separa punir o descuido de punir a
## paciência de uma abóbora de 13 dias (PRINCIPIOS §10).
func _fecha_arados_ociosos(_dia: int, teto: int) -> Array[SimEvent]:
	var eventos: Array[SimEvent] = []
	for id in _farm.plot_ids():
		var partes := id.split(":")
		if partes.size() != 2:
			continue
		var x := int(partes[0])
		var y := int(partes[1])
		var plot := _farm.peek_plot(x, y)
		if not plot.arada or plot.tem_cultura() or not _estado.e_livre(x, y):
			_estado.marca_ocioso(x, y, 0)
			continue

		var dias := _estado.dias_ocioso(x, y) + 1
		if dias < DIAS_PARA_FECHAR:
			_estado.marca_ocioso(x, y, dias)
			continue
		if eventos.size() >= teto:
			# Estourou o teto: o relógio para de contar aqui e o tile fecha
			# amanhã. Continuar contando faria uma fila inteira despencar junto
			# no dia seguinte.
			continue

		_estado.marca_ocioso(x, y, 0)
		_estado.define_cobertura(x, y, EstadoTerreno.MATO)
		eventos.append(_mudou(x, y, EstadoTerreno.LIVRE, EstadoTerreno.MATO,
				TerrenoMudouEvent.POR_FECHAMENTO))
	return eventos


# --- A fazenda que nasce ---

## Espalha o entulho inicial em manchas e devolve um evento por tile.
##
## Manchas, e não tiles soltos: pedra avulsa espalhada pelo mapa é ruído que o
## jogador limpa no piloto automático. Uma mancha é um **lugar** — ela tem forma,
## dá para contorná-la, e decidir se vale abrir caminho por ela é uma decisão de
## layout.
##
## Chamado uma vez na criação da partida. Carregar um save substitui o estado
## inteiro depois, e os eventos daqui se perdem — como acontece com a entrega
## inicial da mochila.
func gera() -> Array[SimEvent]:
	_estado.from_dict({"semente": _estado.semente})

	# O poço primeiro, e fora do sorteio: ele é o único ponto fixo do mapa, e
	# entra antes para que nenhuma mancha caia por cima dele.
	var eventos: Array[SimEvent] = []
	if POCO.x >= 0 and POCO.x < _largura and POCO.y >= 0 and POCO.y < _altura:
		_estado.define_cobertura(POCO.x, POCO.y, EstadoTerreno.AGUA)
		eventos.append(_mudou(POCO.x, POCO.y, EstadoTerreno.LIVRE, EstadoTerreno.AGUA,
				TerrenoMudouEvent.POR_GERACAO))

	var alvo := int(_largura * _altura * FRACAO_DE_ENTULHO)
	for mancha in MANCHAS:
		if eventos.size() >= alvo:
			break
		eventos.append_array(_planta_mancha(mancha, alvo - eventos.size()))
	return eventos


## Uma caminhada aleatória a partir de um ponto: cada passo cobre o tile e anda
## para um vizinho. É o que dá forma orgânica sem precisar de ruído de Perlin.
func _planta_mancha(mancha: int, teto: int) -> Array[SimEvent]:
	var rng := _rng_de("mancha", mancha)
	var tipo: String = ENTULHO_INICIAL[rng.randi_range(0, ENTULHO_INICIAL.size() - 1)]
	var passos := rng.randi_range(1, 3)
	var onde := Vector2i(rng.randi_range(0, _largura - 1), rng.randi_range(0, _altura - 1))

	var eventos: Array[SimEvent] = []
	for _passo in mini(passos, teto):
		if _estado.e_livre(onde.x, onde.y):
			_estado.define_cobertura(onde.x, onde.y, tipo)
			eventos.append(_mudou(onde.x, onde.y, EstadoTerreno.LIVRE, tipo,
					TerrenoMudouEvent.POR_GERACAO))
		var passo: Vector2i = VIZINHOS[rng.randi_range(0, VIZINHOS.size() - 1)]
		onde = Vector2i(
			clampi(onde.x + passo.x, 0, _largura - 1),
			clampi(onde.y + passo.y, 0, _altura - 1))
	return eventos


# --- Bastidores ---

## Os tiles com esta cobertura, em ordem — a mesma ordem do save, para a
## sequência de eventos da noite não depender de quem foi coberto primeiro.
func _tiles_com(cobertura: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for id in _estado.ids():
		var partes := id.split(":")
		var x := int(partes[0])
		var y := int(partes[1])
		if _estado.cobertura(x, y) == cobertura:
			out.append(Vector2i(x, y))
	return out


## O RNG deste assunto neste dia. Derivar de `(semente, assunto, dia)` dispensa
## guardar estado de RNG no save: carregar a partida no meio não desalinha a
## sequência. Mesmo padrão do `SistemaContratos`.
func _rng_de(assunto: String, dia: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _estado.semente + dia * 1000003 + assunto.hash()
	return rng


func _mudou(x: int, y: int, de: String, para: String, motivo: String,
		player_id: int = 0) -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.player_id = player_id
	evento.x = x
	evento.y = y
	evento.de = de
	evento.para = para
	evento.motivo = motivo
	return evento


func _rejeita(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var evento := ActionRejectedEvent.new()
	evento.player_id = action.player_id
	evento.acao = action.get_script().get_global_name()
	evento.motivo = motivo
	return evento
