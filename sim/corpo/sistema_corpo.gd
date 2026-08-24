class_name SistemaCorpo
extends SimSystem

## O segundo preço do dia: o corpo. Trabalhar custa estamina, e a estamina
## acaba.
##
## ## O que ele conserta
##
## Até aqui o dia tinha um limitador só — o relógio — e trabalhar era de graça:
## arar cem tiles custava o mesmo que arar um, desde que coubesse nos 15 minutos
## reais do dia útil. Com o corpo cobrando, "quanto ainda dá para fazer hoje"
## vira uma aposta que pode sair errada (PRINCIPIOS §7).
##
## O alvo de calibragem está no `tasks/wave-15.md` e é uma frase só: **um dia
## cheio de trabalho termina com a barra raspando**. Se a estamina acabar antes
## do relógio, ela não soma um limitador — ela substitui o relógio, e aí o
## PRINCIPIOS §9 deixa de valer para tudo que já foi construído. Os números
## abaixo são chute para calibrar jogando.
##
## ## O trabalho reage; só comer é ação
##
## Este sistema trata **uma** ação, a `ComerAction`, e nenhuma outra. Trabalho
## nunca passa por aqui, e isso é decisão, não preguiça: um validador de estamina
## teria que rodar antes do `InventorySystem` (que cobra a semente e a água) e
## depois do `SistemaTerreno` (que recusa a limpeza impossível), e não existe
## posição na fila que satisfaça as duas. Reagindo ao evento, o corpo só desconta
## o que **aconteceu de verdade**: ação recusada não cansa ninguém, de graça.
##
## Comer é o caminho contrário e por isso cabe numa ação: ele não observa um fato
## do mundo, ele é o fato. A posição depois do `InventorySystem` é a certa — o
## item sai da mochila antes de o corpo receber, e `ComerAction` estende
## `RemoveItemAction` justamente para isso.
##
## ## Comida é resgate, não combustível
##
## A wave 15 mira um dia que termina com a barra raspando junto com o relógio. Se
## o alvo for atingido, comida como extensor de dia não teria para onde ir: os
## 100 recuperados às 20:00 não achariam relógio sobrando. Então o momento da
## comida é outro — você come quando **apertou demais**, e a escolha é entre
## queimar um pão de 260g ou perder metade do dia de amanhã.
##
## A saciedade é o freio: cada refeição do dia vale menos que a anterior. Sem
## ela, a estratégia ótima é mochila cheia de pão e o corpo deixa de existir — e
## o atrito padrão do projeto é limite (PRINCIPIOS §7).
##
## ## Zero desmaia, não bloqueia
##
## Não existe "cansado demais para agir". Recusa é para impossibilidade (item
## errado, fora do lugar), não para consequência — apertar o botão e nada
## acontecer, no meio do canteiro, é o pior momento de jogo que esta mecânica
## poderia produzir. Ao chegar a zero sai `DesmaiouEvent`, o `TimeSystem` fecha o
## dia com `COLLAPSED` e a manhã devolve metade.
##
## ## O custo é do trabalho, não da ferramenta
##
## `PlotTilledEvent` não diz qual enxada arou, e descobrir exigiria ler o
## inventário — state alheio. O trade-off aceito é explícito: **ferramenta melhor
## não cansa menos, ainda**. Quando o ferreiro existir, o evento ganha o campo e
## o custo migra para lá; pagar essa complexidade hoje seria por uma mecânica que
## não existe.
##
## ## Andar não cansa
##
## O relógio cobra o deslocamento, o corpo cobra o trabalho, e nenhum dos dois
## cobra duas vezes pela mesma coisa. Um dia de só ir à cidade, entregar e voltar
## não gasta estamina — ele já custou o relógio inteiro.

## O vocabulário dos trabalhos. É id, como tudo o mais que é conteúdo: a tela
## traduz para português, e mecânica nova (pescar, forjar) entra somando uma
## linha aqui e outra na tabela de custos.
const ARAR: String = "arar"
const REGAR: String = "regar"
const PLANTAR: String = "plantar"
const COLHER: String = "colher"
const LIMPAR_MATO: String = "limpar_mato"
const LIMPAR_PEDRA: String = "limpar_pedra"
const LIMPAR_TOCO: String = "limpar_toco"
const LIMPAR_ARVORE: String = "limpar_arvore"

## Os números de partida (wave 15). Um dia de 20 tiles arados, plantados e
## regados gasta ~180 dos 200 — a barra raspa no fim do dia, que é o alvo.
const CUSTO_ARAR: int = 4
const CUSTO_REGAR: int = 2
const CUSTO_PLANTAR: int = 1
const CUSTO_COLHER: int = 1
const CUSTO_LIMPAR_MATO: int = 4
const CUSTO_LIMPAR_PEDRA: int = 8
const CUSTO_LIMPAR_TOCO: int = 10
const CUSTO_LIMPAR_ARVORE: int = 12

## A ordem é a ordem em que a aba Corpo lista: o ciclo do canteiro primeiro, a
## limpeza depois, cada bloco do mais barato ao mais caro.
const TRABALHOS: Array[String] = [
	PLANTAR, COLHER, REGAR, ARAR,
	LIMPAR_MATO, LIMPAR_PEDRA, LIMPAR_TOCO, LIMPAR_ARVORE,
]

## Quanto cada trabalho cobra. Tabela, e não `if`: o custo de um trabalho novo é
## uma linha, e a aba Corpo desenha a lista sem saber quais existem.
const CUSTOS: Dictionary = {
	PLANTAR: CUSTO_PLANTAR,
	COLHER: CUSTO_COLHER,
	REGAR: CUSTO_REGAR,
	ARAR: CUSTO_ARAR,
	LIMPAR_MATO: CUSTO_LIMPAR_MATO,
	LIMPAR_PEDRA: CUSTO_LIMPAR_PEDRA,
	LIMPAR_TOCO: CUSTO_LIMPAR_TOCO,
	LIMPAR_ARVORE: CUSTO_LIMPAR_ARVORE,
}

## Que trabalho é tirar cada cobertura do caminho. O custo sai do que **estava**
## lá, nunca do que ficou: derrubar a árvore é o golpe caro, arrancar o toco que
## ela virou é o seguinte, e são dois preços porque são dois golpes.
const TRABALHO_DA_COBERTURA: Dictionary = {
	EstadoTerreno.MATO: LIMPAR_MATO,
	EstadoTerreno.PEDRA: LIMPAR_PEDRA,
	EstadoTerreno.TOCO: LIMPAR_TOCO,
	EstadoTerreno.ARVORE: LIMPAR_ARVORE,
}

## A saciedade, refeição a refeição: a primeira do dia vale o número cheio do
## `.tres`, a segunda metade, a terceira um quarto, e da quarta em diante o piso.
##
## É o freio que impede a mochila de pão de apagar o corpo, e é o que cria a
## decisão de **quando** comer: cedo demais desperdiça a refeição cheia, tarde
## demais arrisca não chegar lá. O item é o mesmo; o valor não.
##
## Tabela, e não fórmula, pelo mesmo motivo da tabela de custos: calibrar é mudar
## um número, e o número está escrito por extenso.
const FATORES_DE_SACIEDADE: Array[float] = [1.0, 0.5, 0.25, 0.1]

## Uma mordida sempre é uma mordida. Comida cujo valor efetivo arredondasse para
## zero sumiria da mochila sem devolver nada — o mesmo bug que `pode_comer()`
## existe para evitar, por outro caminho.
const RESTAURO_MINIMO: int = 1

const MOTIVO_NAO_E_COMIDA: String = "nao_e_comida"
const MOTIVO_ESTAMINA_CHEIA: String = "estamina_cheia"
const MOTIVO_DESMAIADO: String = "desmaiado"

var _estado: EstadoCorpo
## Só para ler `restaura_estamina`. Definição é leitura livre; state alheio é que
## é proibido. Comida nova é `.tres` novo, e ela chega aqui sozinha.
var _items: ItemCatalog


func _init(estado: EstadoCorpo = null, items: ItemCatalog = null) -> void:
	_estado = estado if estado != null else EstadoCorpo.new()
	_items = items if items != null else ItemCatalog.new()


func get_state() -> EstadoCorpo:
	return _estado


# --- Consultas (para `game/`, que nunca decide regra) ---

## Quanto este trabalho cobra. Trabalho que o jogo não conhece custa 0 — mecânica
## que ainda não existe não pode cansar ninguém.
func custo_de(trabalho: String) -> int:
	return int(CUSTOS.get(trabalho, 0))

func estamina_de(player_id: int) -> int:
	return _estado.estamina_de(player_id)

func maxima_de(player_id: int) -> int:
	return _estado.maxima_de(player_id)

## Quanto do corpo ainda resta, de 0 a 1. É a barra da tela — e ela é conta de
## regra, não de layout: quem sabe o teto é o dono do state.
func fracao_de(player_id: int) -> float:
	var maxima := _estado.maxima_de(player_id)
	if maxima <= 0:
		return 0.0
	return clampf(float(_estado.estamina_de(player_id)) / float(maxima), 0.0, 1.0)

## Quantas ações deste tipo ainda cabem antes do desmaio. É a pergunta que a aba
## Corpo faz, e ela é de regra: quem decide o que sobra é quem cobra.
##
## Arredonda para baixo: o golpe que não cabe inteiro é o golpe que derruba.
func acoes_restantes(trabalho: String, player_id: int) -> int:
	var custo := custo_de(trabalho)
	if custo <= 0:
		return 0
	return _estado.estamina_de(player_id) / custo


# --- A mesa (consultas) ---

## Este item se come? A resposta é do `.tres`, via `ItemDef.alimenta()` — o
## sistema não conhece pão nem cenoura.
func e_comida(item_id: String) -> bool:
	var def := _items.get_def(item_id)
	return def != null and def.alimenta()

## Quantas refeições este jogador já fez hoje.
func refeicoes_hoje(player_id: int) -> int:
	return _estado.refeicoes_hoje(player_id)

## Qual refeição do dia vem a seguir — 1 com a mesa limpa.
func proxima_refeicao(player_id: int) -> int:
	return _estado.refeicoes_hoje(player_id) + 1

## Quanto a próxima refeição vale, de 0 a 1. É o número que a aba Corpo mostra
## antes do clique.
func fator_agora(player_id: int) -> float:
	return fator_da_refeicao(proxima_refeicao(player_id))

## O fator da refeição de número `refeicao` — a primeira do dia é 1. Da quarta em
## diante todo mundo vale o piso.
##
## Estática porque é tabela pura: quem quiser explicar a saciedade na tela
## pergunta sem precisar de um sistema montado.
static func fator_da_refeicao(refeicao: int) -> float:
	var indice := mini(maxi(refeicao, 1) - 1, FATORES_DE_SACIEDADE.size() - 1)
	return FATORES_DE_SACIEDADE[indice]

## Quanto esta comida restaura **agora**, já com a saciedade do dia aplicada.
## Item que não alimenta restaura 0.
##
## É a pergunta que a mesa da aba Corpo faz para cada linha, e ela é de regra: o
## número cru do `.tres` mentiria na terceira refeição.
func restauro_de(item_id: String, player_id: int) -> int:
	return _valor_da_refeicao(item_id, proxima_refeicao(player_id))

## Esta refeição passaria? `game/` pergunta **antes** de despachar, porque a
## `ComerAction` cobra o item no Inventory antes de chegar aqui.
func pode_comer(player_id: int, item_id: String) -> bool:
	return _recusa_de_comer(player_id, item_id).is_empty()


# --- A mesa (a ação) ---

## A única ação que este sistema trata. Trabalho continua entrando por evento
## consumado — ver o cabeçalho.
func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is ComerAction:
		return _come(action as ComerAction)
	return []

## Come: aplica o fator da refeição, devolve o que couber e conta o prato.
##
## O item **já saiu da mochila** quando chegamos aqui — o `InventorySystem` vem
## antes na ordem fixa. Uma recusa daqui, portanto, é comida perdida, e é por
## isso que `pode_comer()` existe e que `game/` pergunta antes. Mesma armadilha
## de `EntregarAction`, mesma saída.
func _come(action: ComerAction) -> Array[SimEvent]:
	var motivo := _recusa_de_comer(action.player_id, action.item_id)
	if not motivo.is_empty():
		return [_rejeita(action, motivo)]

	var refeicao := _estado.registra_refeicao(action.player_id)
	var restaurou := _valor_da_refeicao(action.item_id, refeicao)
	var de := _estado.estamina_de(action.player_id)
	var para := _estado.restaura(action.player_id, restaurou)
	return [_comeu(action, refeicao, restaurou, de, para)]

## O motivo pelo qual a refeição seria recusada, ou `""` se ela passa. É a mesma
## função que `pode_comer()` responde e que `_come()` obedece — a regra existe uma
## vez só.
##
## Saciedade no fundo **não** recusa: restaura pouco, mas a decisão é do jogador,
## e a tela mostra o valor efetivo antes do clique.
func _recusa_de_comer(player_id: int, item_id: String) -> String:
	if not e_comida(item_id):
		return MOTIVO_NAO_E_COMIDA
	# Chegou a zero, o dia acabou. Comida é o que evita o desmaio, nunca o que o
	# desfaz.
	if _estado.desmaiado(player_id):
		return MOTIVO_DESMAIADO
	if _estado.estamina_de(player_id) >= _estado.maxima_de(player_id):
		return MOTIVO_ESTAMINA_CHEIA
	return ""

## O valor efetivo de uma refeição: o número do `.tres` vezes o fator do dia,
## arredondado para baixo e com piso em 1. O que não é comida vale 0 e nem chega
## ao piso.
func _valor_da_refeicao(item_id: String, refeicao: int) -> int:
	var def := _items.get_def(item_id)
	if def == null or not def.alimenta():
		return 0
	var bruto := int(floor(float(def.restaura_estamina) * fator_da_refeicao(refeicao)))
	return maxi(bruto, RESTAURO_MINIMO)


# --- O trabalho cobra ---

## Todo desconto entra por aqui, e todo desconto vem de um evento de trabalho já
## consumado. `game/` nunca despacha "cansar".
## A lista é curta de propósito: o que não está aqui é de graça, e "de graça" é
## a resposta certa para viajar, entregar, vender e para tudo que a noite faz
## sozinha.
##
## Quem paga é sempre o `player_id` do evento, nunca "o jogador": todo evento de
## trabalho carrega o dono desde o primeiro dia, e é isso que deixa co-op ser
## problema de rede, não de refatoração.
func react(event: SimEvent) -> Array[SimEvent]:
	if event is DayEndedEvent:
		return _amanhece(event as DayEndedEvent)
	if event is PlotTilledEvent:
		return _cansa((event as PlotTilledEvent).player_id, ARAR)
	if event is PlotWateredEvent:
		return _cansa((event as PlotWateredEvent).player_id, REGAR)
	if event is CropPlantedEvent:
		return _cansa((event as CropPlantedEvent).player_id, PLANTAR)
	if event is CropHarvestedEvent:
		return _cansa((event as CropHarvestedEvent).player_id, COLHER)
	if event is TerrenoMudouEvent:
		return _limpeza(event as TerrenoMudouEvent)
	return []


## A limpeza cobra pelo que **estava** no caminho, e só quando foi o jogador: o
## mato que invadiu, o arado que fechou e a fazenda que nasceu são trabalho da
## noite, e a noite não cansa ninguém.
func _limpeza(event: TerrenoMudouEvent) -> Array[SimEvent]:
	if event.motivo != TerrenoMudouEvent.POR_LIMPEZA:
		return []
	var trabalho := String(TRABALHO_DA_COBERTURA.get(event.de, ""))
	if trabalho.is_empty():
		return []
	return _cansa(event.player_id, trabalho)


## Desconta e, se o corpo chegou ao fim, derruba.
##
## Quem já está em zero não desconta de novo: o dia dele acabou no golpe
## anterior, e um segundo `DesmaiouEvent` fecharia o dia duas vezes.
func _cansa(player_id: int, trabalho: String) -> Array[SimEvent]:
	var custo := custo_de(trabalho)
	var de := _estado.estamina_de(player_id)
	if custo <= 0 or de <= 0:
		return []

	var para := _estado.gasta(player_id, custo)
	var eventos: Array[SimEvent] = [_gastou(player_id, trabalho, custo, de, para)]
	if para <= 0:
		eventos.append(_desmaiou(player_id, trabalho))
	return eventos


# --- A manhã ---

## O dia acabou: dormir enche, colapso devolve metade.
##
## Não sai evento nenhum daqui. Encher não é fato que alguém precise animar — a
## tela relê a barra na virada do dia, que já é um evento — e um
## `EstaminaRestauradaEvent` seria vocabulário inventado para dizer o que o
## `DayEndedEvent` já disse.
##
## Só quem tem corpo gravado é restaurado: quem nunca trabalhou já está cheio, e
## criar a entrada dele aqui só encheria o save.
func _amanhece(event: DayEndedEvent) -> Array[SimEvent]:
	var dormiu := event.cause == DayEndedEvent.Cause.SLEPT
	for player_id in _estado.jogadores():
		# A mesa limpa junto, inclusive no colapso: a saciedade é do dia, e o dia
		# acabou. Se amanhecer com a refeição cheia depois de desmaiar parecer
		# generoso demais, o `cause` está aqui e dá para diferenciar.
		_estado.zera_refeicoes(player_id)
		if dormiu:
			_estado.enche(player_id)
			continue
		_estado.enche_metade(player_id)
	return []


# --- Fábrica de eventos ---

func _gastou(player_id: int, trabalho: String, custo: int, de: int,
		para: int) -> EstaminaGastaEvent:
	var evento := EstaminaGastaEvent.new()
	evento.player_id = player_id
	evento.trabalho = trabalho
	evento.custo = custo
	evento.de = de
	evento.para = para
	evento.maxima = _estado.maxima_de(player_id)
	return evento

func _desmaiou(player_id: int, trabalho: String) -> DesmaiouEvent:
	var evento := DesmaiouEvent.new()
	evento.player_id = player_id
	evento.trabalho = trabalho
	evento.maxima = _estado.maxima_de(player_id)
	return evento

func _comeu(action: ComerAction, refeicao: int, restaurou: int, de: int,
		para: int) -> ComeuEvent:
	var evento := ComeuEvent.new()
	evento.player_id = action.player_id
	evento.item_id = action.item_id
	evento.refeicao = refeicao
	evento.restaurou = restaurou
	evento.de = de
	evento.para = para
	evento.maxima = _estado.maxima_de(action.player_id)
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
