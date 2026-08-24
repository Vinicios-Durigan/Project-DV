class_name SistemaOficios
extends SimSystem

## A árvore do jogador: trabalhar ensina, ensinar sobe nível, e o nível vira
## ponto que compra vantagem — uma vez só, para sempre.
##
## ## O que ele conserta
##
## Até aqui o personagem não progredia: o dia 40 tinha exatamente o mesmo corpo e
## as mesmas mãos do dia 1, e tudo que crescia era a fazenda e a relação com a
## cidade. Faltava a escada que é do **jogador**, e ela é a última mecânica do
## slice.
##
## ## Grind é intencional, e o freio é o mundo
##
## Quem planta mais ganha mais XP que quem planta menos. A progressão não é por
## constância — isso é a escada da cidade, e premiar duas vezes o mesmo gesto
## inflaria a relação que a wave 12 calibrou. O freio aqui não é uma regra nova:
## **cada ação já custa estamina e relógio**. Volume nunca sai de graça, e o
## grind se paga em corpo.
##
## ## XP é o custo de estamina
##
## Arar dá 4, regar 2, quebrar pedra 8, derrubar árvore 12 — a tabela é lida do
## `SistemaCorpo`, não copiada. Uma segunda fonte de verdade divergiria no
## primeiro rebalanceamento, e a frase que a une é curta: **o que cansa mais
## ensina mais**.
##
## ## Ele reage; só comprar é ação
##
## Mesma divisão do corpo, e pela mesma razão: XP entra por evento consumado, e
## ação recusada não ensina ninguém de graça. Comprar é o caminho contrário — não
## observa um fato do mundo, é o fato.
##
## ## Ponto preso no ofício
##
## Ponto de Lavoura só compra vantagem de Lavoura. Você fica bom no que pratica,
## e abrir o tabuleiro inteiro obriga a variar o trabalho — senão moer um gesto
## só compraria tudo.
##
## ## A cidade fica fora
##
## Entregar, cumprir contrato e subir relação não dão XP. A cidade já tem a
## própria escada, e o mesmo gesto premiado duas vezes seria inflação dos dois
## lados.
##
## ## O efeito viaja por evento
##
## Este sistema não aplica nada. Ele credita, cobra e emite
## `VantagemEscolhidaEvent`; quem paga o efeito (o corpo, a lavoura) guarda a
## própria cópia no próprio state. Nenhum sistema lê state alheio — mesmo padrão
## de contratos↔cidade.
##
## ## Efeito nunca toca preço de venda
##
## A conta que mata: 4 trigos crus valem 100g, moídos rendem 140g líquidos.
## Trigo a 2× valeria 200g e o moinho morreria no primeiro ponto gasto — e com
## ele a tese do jogo (PRINCIPIOS §2). As vantagens compram **corpo, relógio,
## água e terra**, nunca preço.
##
## ## Nada de sorte no efeito
##
## "10% de chance de nascer regada" viraria RNG em resultado, descartado no
## GAMEPLAY com motivo. A versão determinística é a Rega funda: os primeiros N
## canteiros do dia seguram a água, e o jogador controla **quais** pela ordem em
## que rega.

## Os dois ofícios. Id, como tudo o mais que é conteúdo: a tela traduz.
const LAVOURA: String = "lavoura"
const CAMPO: String = "campo"

## A ordem é a ordem em que a aba Ofícios lista.
const OFICIOS: Array[String] = [LAVOURA, CAMPO]

## As vantagens que esta wave entrega. As outras quatro do tabuleiro planejado
## (Braço de poço, Golpe certeiro, Terra domada, Passo firme) entram na 17.1,
## junto com os donos dos seus efeitos: **o tabuleiro só oferece vantagem cujo
## efeito existe**, porque comprar vantagem morta é pior que não vendê-la.
const MAOS_LEVES: String = "maos_leves"
const REGA_FUNDA: String = "rega_funda"
const COLHEITA_ESPECIALIZADA: String = "colheita_especializada"
const COSTAS_LARGAS: String = "costas_largas"

## XP acumulado que cada nível pede. Cada nível dá 1 ponto, e o topo da lista é o
## teto do ofício.
##
## Lavoura sobe caro porque a fonte é infinita: o dia todo alimenta o canteiro.
## Campo sobe barato porque a fonte é quase finita — pedra e árvore não voltam, e
## só o mato pinga. Números de partida, para calibrar jogando, como o
## `DIAS_POR_CONTRATO` da wave 13.
const LIMIARES_LAVOURA: Array[int] = [100, 300, 700, 1400]
const LIMIARES_CAMPO: Array[int] = [30, 80, 160, 280]

const LIMIARES: Dictionary = {
	LAVOURA: LIMIARES_LAVOURA,
	CAMPO: LIMIARES_CAMPO,
}

## Que ofício cada trabalho pratica. Lavoura é o ciclo do canteiro; Campo é tirar
## o mundo do caminho.
##
## Trabalho fora desta tabela não ensina nada — é a mesma resposta que o corpo dá
## para viajar, entregar e vender: de graça.
const OFICIO_DO_TRABALHO: Dictionary = {
	SistemaCorpo.ARAR: LAVOURA,
	SistemaCorpo.REGAR: LAVOURA,
	SistemaCorpo.PLANTAR: LAVOURA,
	SistemaCorpo.COLHER: LAVOURA,
	SistemaCorpo.LIMPAR_MATO: CAMPO,
	SistemaCorpo.LIMPAR_PEDRA: CAMPO,
	SistemaCorpo.LIMPAR_TOCO: CAMPO,
	SistemaCorpo.LIMPAR_ARVORE: CAMPO,
}

## O tabuleiro: de que bolso sai, quanto custa por nível e onde para.
##
## Tabela, e não `if`: vantagem nova é uma linha aqui e um `react` no dono do
## efeito, e a aba Ofícios desenha a lista sem saber quais existem.
##
## 8 pontos ganháveis no slice contra 13 de custo total — nunca dá para ter tudo,
## e é isso que faz o ponto pesar.
const TABULEIRO: Dictionary = {
	MAOS_LEVES: {"oficio": LAVOURA, "custo": 1, "teto": 2},
	REGA_FUNDA: {"oficio": LAVOURA, "custo": 1, "teto": 2},
	COLHEITA_ESPECIALIZADA: {"oficio": LAVOURA, "custo": 2, "teto": 1},
	COSTAS_LARGAS: {"oficio": CAMPO, "custo": 1, "teto": 2},
}

## A única vantagem que pede uma escolha junto do ponto.
const VANTAGEM_DA_CULTURA: String = COLHEITA_ESPECIALIZADA

const MOTIVO_VANTAGEM_DESCONHECIDA: String = "vantagem_desconhecida"
const MOTIVO_NO_TETO: String = "vantagem_no_teto"
const MOTIVO_SEM_PONTO: String = "sem_ponto"
const MOTIVO_CULTURA_AUSENTE: String = "cultura_ausente"
const MOTIVO_CULTURA_DESCONHECIDA: String = "cultura_desconhecida"

var _estado: EstadoOficios
## Só para conferir a cultura da especialização. Definição é leitura livre; state
## alheio é que é proibido. Cultura nova é `.tres` novo, e ela chega aqui
## sozinha.
var _crops: CropCatalog


func _init(estado: EstadoOficios = null, crops: CropCatalog = null) -> void:
	_estado = estado if estado != null else EstadoOficios.new()
	_crops = crops if crops != null else CropCatalog.new()


func get_state() -> EstadoOficios:
	return _estado


# --- O tabuleiro (consultas) ---

## Quanto este trabalho ensina — o mesmo número que ele cobra do corpo. Trabalho
## que o jogo não conhece ensina 0.
func xp_do_trabalho(trabalho: String) -> int:
	return int(SistemaCorpo.CUSTOS.get(trabalho, 0))

## Que ofício este trabalho pratica, ou `""` se ele não pratica nenhum.
func oficio_do_trabalho(trabalho: String) -> String:
	return String(OFICIO_DO_TRABALHO.get(trabalho, ""))

## As vantagens deste ofício, na ordem do tabuleiro.
func vantagens_do_oficio(oficio: String) -> Array[String]:
	var ids: Array[String] = []
	for vantagem_id: String in TABULEIRO.keys():
		if oficio_da_vantagem(vantagem_id) == oficio:
			ids.append(vantagem_id)
	return ids

func existe_vantagem(vantagem_id: String) -> bool:
	return TABULEIRO.has(vantagem_id)

## De que bolso esta vantagem sai. Vantagem desconhecida não sai de nenhum.
func oficio_da_vantagem(vantagem_id: String) -> String:
	return String(_linha(vantagem_id).get("oficio", ""))

## Quantos pontos um nível desta vantagem custa.
func custo_da_vantagem(vantagem_id: String) -> int:
	return int(_linha(vantagem_id).get("custo", 0))

## Quantas vezes esta vantagem pode ser comprada.
func teto_da_vantagem(vantagem_id: String) -> int:
	return int(_linha(vantagem_id).get("teto", 0))

## Esta vantagem pede uma cultura junto do ponto?
func exige_cultura(vantagem_id: String) -> bool:
	return vantagem_id == VANTAGEM_DA_CULTURA

## Quantos níveis este ofício tem. É o teto da escada, e o topo da tabela.
func nivel_maximo(oficio: String) -> int:
	return _limiares(oficio).size()


# --- A caderneta (consultas) ---

func xp_de(player_id: int, oficio: String) -> int:
	return _estado.xp_de(player_id, oficio)

func nivel_de(player_id: int, oficio: String) -> int:
	return _estado.nivel_de(player_id, oficio)

func pontos_de(player_id: int, oficio: String) -> int:
	return _estado.pontos_de(player_id, oficio)

func gastos_de(player_id: int, oficio: String) -> int:
	return _estado.gastos_de(player_id, oficio)

## Quantos pontos este ofício já rendeu na vida — gastos mais disponíveis. É o
## número que a aba usa para contar "2 de 4 gastos".
func pontos_ganhos(player_id: int, oficio: String) -> int:
	return _estado.pontos_de(player_id, oficio) + _estado.gastos_de(player_id, oficio)

func nivel_da_vantagem(player_id: int, vantagem_id: String) -> int:
	return _estado.nivel_da_vantagem(player_id, vantagem_id)

## A cultura da Colheita especializada, ou `""` se ela ainda não foi escolhida.
func cultura_de(player_id: int) -> String:
	return _estado.cultura_de(player_id)

## Quanto XP acumulado o nível `nivel` deste ofício pede. Nível fora da escada
## pede 0 — no topo não existe próximo limiar.
func xp_do_nivel(oficio: String, nivel: int) -> int:
	var limiares := _limiares(oficio)
	if nivel <= 0 or nivel > limiares.size():
		return 0
	return limiares[nivel - 1]

## Quanto falta para o próximo nível. No topo da escada, 0 — não há para onde
## subir, e um número aqui viraria uma barra que nunca enche.
func xp_para_o_proximo(player_id: int, oficio: String) -> int:
	var alvo := xp_do_nivel(oficio, _estado.nivel_de(player_id, oficio) + 1)
	if alvo <= 0:
		return 0
	return maxi(alvo - _estado.xp_de(player_id, oficio), 0)

## Quanto do nível atual já foi andado, de 0 a 1. É a barra da aba — e ela é
## conta de regra, não de layout: quem conhece os limiares é o dono da tabela.
##
## No topo devolve 1: sem próximo nível, a barra cheia é a leitura certa.
func fracao_do_nivel(player_id: int, oficio: String) -> float:
	var nivel := _estado.nivel_de(player_id, oficio)
	var alvo := xp_do_nivel(oficio, nivel + 1)
	if alvo <= 0:
		return 1.0
	var piso := xp_do_nivel(oficio, nivel)
	var andado := _estado.xp_de(player_id, oficio) - piso
	var faixa := alvo - piso
	if faixa <= 0:
		return 1.0
	return clampf(float(andado) / float(faixa), 0.0, 1.0)


# --- Comprar (consultas antes do clique) ---

## Esta compra passaria? `game/` pergunta **antes** de despachar, porque a
## escolha é permanente e o ponto não volta.
func pode_comprar(player_id: int, vantagem_id: String, cultura: String = "") -> bool:
	return recusa_de(player_id, vantagem_id, cultura).is_empty()

## O motivo pelo qual a compra seria recusada, ou `""` se ela passa. É a mesma
## função que `pode_comprar()` responde e que `handle()` obedece — a regra existe
## uma vez só.
func recusa_de(player_id: int, vantagem_id: String, cultura: String = "") -> String:
	if not existe_vantagem(vantagem_id):
		return MOTIVO_VANTAGEM_DESCONHECIDA
	if _estado.nivel_da_vantagem(player_id, vantagem_id) >= teto_da_vantagem(vantagem_id):
		return MOTIVO_NO_TETO
	if _estado.pontos_de(player_id, oficio_da_vantagem(vantagem_id)) < custo_da_vantagem(vantagem_id):
		return MOTIVO_SEM_PONTO
	if not exige_cultura(vantagem_id):
		return ""
	# A escolha é permanente: uma cultura digitada errada queimaria dois pontos
	# para sempre. Mesma razão de `pode_comer()` existir no corpo.
	if cultura.is_empty():
		return MOTIVO_CULTURA_AUSENTE
	if _crops.get_def(cultura) == null:
		return MOTIVO_CULTURA_DESCONHECIDA
	return ""


# --- Comprar (a ação) ---

## A única ação que este sistema trata. Trabalho continua entrando por evento
## consumado — ver o cabeçalho.
func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is EscolherVantagemAction:
		return _compra(action as EscolherVantagemAction)
	return []

## Compra: cobra o ponto do bolso certo, carimba a vantagem e conta ao mundo.
##
## O ponto sai antes de o evento sair, e é de propósito: quem escuta
## `VantagemEscolhidaEvent` está lendo um fato já pago.
func _compra(action: EscolherVantagemAction) -> Array[SimEvent]:
	var motivo := recusa_de(action.player_id, action.vantagem_id, action.cultura)
	if not motivo.is_empty():
		return [_rejeita(action, motivo)]

	var oficio := oficio_da_vantagem(action.vantagem_id)
	var custo := custo_da_vantagem(action.vantagem_id)
	var restantes := _estado.gasta_pontos(action.player_id, oficio, custo)
	var nivel := _estado.compra_vantagem(action.player_id, action.vantagem_id)
	if exige_cultura(action.vantagem_id):
		_estado.define_cultura(action.player_id, action.cultura)

	return [_escolheu(action, oficio, nivel, custo, restantes)]


# --- O trabalho ensina ---

## Todo XP entra por aqui, e todo XP vem de um gesto já consumado. `game/` nunca
## despacha "aprender".
##
## A lista é a mesma do `SistemaCorpo`, e isso é o contrato da wave: o mesmo
## golpe cansa e ensina. O que não está aqui é de graça — e "de graça" é a
## resposta certa para viajar, entregar, vender e para tudo que a noite faz
## sozinha.
func react(event: SimEvent) -> Array[SimEvent]:
	if event is PlotTilledEvent:
		return _pratica((event as PlotTilledEvent).player_id, SistemaCorpo.ARAR)
	if event is PlotWateredEvent:
		return _pratica((event as PlotWateredEvent).player_id, SistemaCorpo.REGAR)
	if event is CropPlantedEvent:
		return _pratica((event as CropPlantedEvent).player_id, SistemaCorpo.PLANTAR)
	if event is CropHarvestedEvent:
		return _pratica((event as CropHarvestedEvent).player_id, SistemaCorpo.COLHER)
	if event is TerrenoMudouEvent:
		return _limpeza(event as TerrenoMudouEvent)
	return []

## A limpeza ensina pelo que **estava** no caminho, e só quando foi o jogador: o
## mato que invadiu, o arado que fechou e a fazenda que nasceu são trabalho da
## noite, e a noite não ensina ninguém.
func _limpeza(event: TerrenoMudouEvent) -> Array[SimEvent]:
	if event.motivo != TerrenoMudouEvent.POR_LIMPEZA:
		return []
	var trabalho := String(SistemaCorpo.TRABALHO_DA_COBERTURA.get(event.de, ""))
	if trabalho.is_empty():
		return []
	return _pratica(event.player_id, trabalho)

## Soma o XP do gesto e, se a soma cruzou limiar, sobe o nível e credita ponto.
func _pratica(player_id: int, trabalho: String) -> Array[SimEvent]:
	var oficio := oficio_do_trabalho(trabalho)
	var xp := xp_do_trabalho(trabalho)
	if oficio.is_empty() or xp <= 0:
		return []

	var total := _estado.soma_xp(player_id, oficio, xp)
	var eventos: Array[SimEvent] = [_ganhou(player_id, oficio, trabalho, xp, total)]
	var subiu := _confere_nivel(player_id, oficio, total)
	if subiu != null:
		eventos.append(subiu)
	return eventos

## Cruza o acumulado com a tabela e credita o que faltar.
##
## Um golpe caro pode passar de dois limiares de uma vez: nesse caso são dois
## pontos e **um** evento, contando o salto inteiro. Dois eventos fariam a tela
## comemorar duas vezes por um golpe só.
func _confere_nivel(player_id: int, oficio: String, total: int) -> OficioSubiuEvent:
	var antes := _estado.nivel_de(player_id, oficio)
	var agora := _nivel_do_xp(oficio, total)
	if agora <= antes:
		return null

	var ganhos := agora - antes
	_estado.define_nivel(player_id, oficio, agora)
	_estado.credita_pontos(player_id, oficio, ganhos)
	return _subiu(player_id, oficio, antes, agora, ganhos)

## Que nível este acumulado vale. Conta limiares cruzados, e para no topo da
## tabela — XP a mais não vira ponto infinito.
func _nivel_do_xp(oficio: String, xp: int) -> int:
	var nivel := 0
	for limiar in _limiares(oficio):
		if xp < limiar:
			break
		nivel += 1
	return nivel

func _limiares(oficio: String) -> Array[int]:
	var limiares: Array[int] = LIMIARES.get(oficio, [] as Array[int])
	return limiares

func _linha(vantagem_id: String) -> Dictionary:
	return TABULEIRO.get(vantagem_id, {}) as Dictionary


# --- Fábrica de eventos ---

func _ganhou(player_id: int, oficio: String, trabalho: String, xp: int,
		total: int) -> ExperienciaGanhaEvent:
	var evento := ExperienciaGanhaEvent.new()
	evento.player_id = player_id
	evento.oficio = oficio
	evento.trabalho = trabalho
	evento.xp = xp
	evento.total = total
	return evento

func _subiu(player_id: int, oficio: String, de: int, para: int,
		pontos: int) -> OficioSubiuEvent:
	var evento := OficioSubiuEvent.new()
	evento.player_id = player_id
	evento.oficio = oficio
	evento.de = de
	evento.para = para
	evento.pontos = pontos
	evento.disponiveis = _estado.pontos_de(player_id, oficio)
	return evento

func _escolheu(action: EscolherVantagemAction, oficio: String, nivel: int,
		custo: int, restantes: int) -> VantagemEscolhidaEvent:
	var evento := VantagemEscolhidaEvent.new()
	evento.player_id = action.player_id
	evento.vantagem_id = action.vantagem_id
	evento.oficio = oficio
	evento.nivel = nivel
	evento.custo = custo
	evento.pontos_restantes = restantes
	evento.cultura = _estado.cultura_de(action.player_id) if exige_cultura(action.vantagem_id) else ""
	return evento

## Carimba a ação e conta o motivo. `motivo` é id de máquina — quem fala com o
## jogador é `game/`.
func _rejeita(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var evento := ActionRejectedEvent.new()
	evento.player_id = action.player_id
	evento.acao = action.get_script().get_global_name()
	evento.motivo = motivo
	return evento
