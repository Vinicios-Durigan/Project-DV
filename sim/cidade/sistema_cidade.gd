class_name SistemaCidade
extends SimSystem

## Dono do `EstadoCidade`: recebe entregas, conclui pelo relógio e devolve o
## produto beneficiado.
##
## ## A posição na ordem fixa
##
## Locais → Inventory → Shipping → Farm → **Cidade** → Time. Depois do Farm,
## para a colheita da manhã já estar na mochila quando a cidade age; antes do
## Time, porque o relógio é quem fecha o dia.
##
## ## As duas metades da transação
##
## `EntregarAction` **é** uma `RemoveItemAction`; `RetirarAction` **é** uma
## `AddMoneyAction`. Quem é dono do item e do dinheiro é o `InventorySystem`, e
## ele roda antes daqui: entregando por uma ação e cobrando por outra, as duas
## recusas caras (`item_insuficiente`, `dinheiro_insuficiente`) saem de quem
## sabe responder por elas — e nenhum sistema existente precisou ser editado.
##
## O preço disso é o mesmo do `PlantCropAction`: o trigo sai da mochila antes de
## a cidade olhar a cota. Por isso existe `pode_entregar()`, e é a resposta dela
## que `game/` consulta (receita 2, §4).
##
## ## O relógio monotônico
##
## A cidade copia `dia × 1440 + minuto` do `MinuteTickedEvent` para o próprio
## state e conclui pelo número. Uma unidade só resolve "4 horas" e "3 dias" sem
## caso especial para a noite, e nada aqui depende da virada do dia.
##
## O `DayEndedEvent` é escutado por um motivo diferente e menor: dormir salta o
## relógio sem passar minuto nenhum, e um relógio parado em ontem daria
## beneficiamento instantâneo a quem entregasse logo ao acordar. A conclusão
## continua sendo pelo minuto — a virada do dia só acerta o ponteiro.
##
## ## Não conhece estabelecimento concreto
##
## Moinho e padaria são `data/cidade/*.tres`. Estabelecimento novo é `.tres`
## novo, zero código — a mesma promessa de cultura e item.

const MOTIVO_ESTABELECIMENTO_DESCONHECIDO: String = "estabelecimento_desconhecido"
const MOTIVO_ITEM_ERRADO: String = "item_errado"
const MOTIVO_LOTE_INCOMPLETO: String = "lote_incompleto"
const MOTIVO_COTA_ESTOURADA: String = "cota_estourada"
const MOTIVO_NADA_PRONTO: String = "nada_pronto"
const MOTIVO_TAXA_INCORRETA: String = "taxa_incorreta"

var _estado: EstadoCidade
## id -> DefEstabelecimento. Definição é leitura livre; state alheio é que é
## proibido.
var _defs: Dictionary


## O diretório é injetável para o teste não depender do conteúdo do jogo.
func _init(estado: EstadoCidade = null,
		dir_defs: String = DefEstabelecimento.DIR_PADRAO) -> void:
	_estado = estado if estado != null else EstadoCidade.new()
	_defs = DefEstabelecimento.carrega_de(dir_defs)

func get_state() -> EstadoCidade:
	return _estado


# --- Consultas (leitura pura, para o teste e para `game/`) ---

## Ids dos estabelecimentos, em ordem alfabética.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs.keys():
		out.append(id)
	out.sort()
	return out

## A definição do estabelecimento, ou `null` se o id não existe.
func def_de(id: String) -> DefEstabelecimento:
	return _defs.get(id, null) as DefEstabelecimento

## A cota vigente do jogador aqui, já limitada pela capacidade do prédio.
func cota_de(id: String) -> int:
	var def := def_de(id)
	if def == null:
		return 0
	return def.cota_com(_estado.dias_com_entrega(id))

## Tem lote pronto esperando alguém buscar?
##
## Existe para `game/` poder avisar sem abrir painel: o prédio no mapa acende
## por causa desta resposta, e o jogador decide a rota do dia olhando de longe.
func tem_pronto(id: String) -> bool:
	return not _estado.prontas(id).is_empty()

## Quanto falta para o próximo lote ficar pronto, em minutos de jogo, ou `-1`
## quando não há nada em produção.
##
## `-1` e não `0`: ausência de prazo é diferente de prazo vencido, e quem lê
## precisa poder escrever "vazio" em vez de "pronta". O que já está pronto sai
## por `tem_pronto()`.
##
## A conta mora aqui, e não em `game/`, porque dois nós precisam dela — o selo
## do prédio e a linha da fila. Feita em dois lugares, ela divergiria no
## primeiro ajuste e a tela mentiria sobre o relógio.
func minutos_para_a_proxima(id: String) -> int:
	var menor := -1
	for enc in _estado.encomendas(id):
		if enc.pronta:
			continue
		var falta: int = maxi(enc.minuto_conclusao - _estado.relogio, 0)
		if menor < 0 or falta < menor:
			menor = falta
	return menor

## Quanto o jogador deve pelo que está pronto para retirada. Zero quando não há
## nada pronto — não se paga pelo que ainda está no forno.
func taxa_a_pagar(id: String) -> int:
	var total := 0
	for enc in _estado.prontas(id):
		total += enc.taxa
	return total

## A entrega passaria? `game/` pergunta **antes** de despachar, porque a
## `EntregarAction` cobra o item no Inventory antes de chegar aqui.
func pode_entregar(id: String, item_id: String, qtd: int) -> bool:
	return _recusa_da_entrega(id, item_id, qtd).is_empty()


# --- Tick central ---

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is EntregarAction:
		return _entrega(action as EntregarAction)
	if action is RetirarAction:
		return _retira(action as RetirarAction)
	return []

## O relógio é copiado do evento, nunca lido do `TimeState`: state alheio é
## proibido, evento é o caminho.
func react(event: SimEvent) -> Array[SimEvent]:
	if event is MinuteTickedEvent:
		var minuto := event as MinuteTickedEvent
		return _acerta_relogio(EstadoCidade.minuto_monotonico(minuto.dia, minuto.minuto))
	if event is DayEndedEvent:
		var virada := event as DayEndedEvent
		return _acerta_relogio(EstadoCidade.minuto_monotonico(
			virada.dia_novo, TimeSystem.MINUTO_ACORDAR))
	return []


# --- Entregar ---

## Aceita o lote e agenda a conclusão. O trigo já saiu da mochila lá atrás: aqui
## é só validar a receita, a cota e pôr na fila.
func _entrega(action: EntregarAction) -> Array[SimEvent]:
	var motivo := _recusa_da_entrega(action.estabelecimento, action.item_id, action.qtd)
	if not motivo.is_empty():
		return [_rejeita(action, motivo)]

	var def := def_de(action.estabelecimento)
	var enc := EstadoCidade.Encomenda.new()
	enc.item_id = def.item_saida
	enc.qtd = def.saida_de(action.qtd)
	enc.qtd_entrada = action.qtd
	enc.taxa = def.taxa_de(action.qtd)
	enc.minuto_conclusao = _estado.relogio + def.prazo_minutos
	_estado.agenda(action.estabelecimento, enc)

	var events: Array[SimEvent] = []
	var aceita := EntregaAceitaEvent.new()
	aceita.player_id = action.player_id
	aceita.estabelecimento = action.estabelecimento
	aceita.item_entrada = action.item_id
	aceita.qtd_entrada = action.qtd
	aceita.item_saida = enc.item_id
	aceita.qtd_saida = enc.qtd
	aceita.taxa = enc.taxa
	aceita.minuto_conclusao = enc.minuto_conclusao
	events.append(aceita)

	events.append_array(_credita_constancia(action, def))
	return events

## O motivo pelo qual a entrega seria recusada, ou `""` se ela passa. É a mesma
## função que `pode_entregar()` responde e que `_entrega()` obedece — a regra
## existe uma vez só.
##
## A cota conferida é a de **agora**: quem chega no terceiro dia entrega dentro
## do limite de ontem, e o degrau que essa entrega ganhar vale a partir da
## próxima. "A cota de hoje é a que você tinha ao chegar."
func _recusa_da_entrega(id: String, item_id: String, qtd: int) -> String:
	var def := def_de(id)
	if def == null:
		return MOTIVO_ESTABELECIMENTO_DESCONHECIDO
	if item_id != def.item_entrada:
		return MOTIVO_ITEM_ERRADO
	if not def.lote_valido(qtd):
		return MOTIVO_LOTE_INCOMPLETO
	if _estado.cota_usada(id) + qtd > cota_de(id):
		return MOTIVO_COTA_ESTOURADA
	return ""

## Uma entrega credita um dia; a segunda do mesmo dia não credita nada. Relação
## sobe por constância (PRINCIPIOS §6).
func _credita_constancia(action: EntregarAction, def: DefEstabelecimento) -> Array[SimEvent]:
	if not _estado.credita_dia(action.estabelecimento, _estado.dia_do_jogo()):
		return []

	var dias := _estado.dias_com_entrega(action.estabelecimento)
	var cota := def.cota_com(dias)
	_estado.define_cota(action.estabelecimento, cota)

	var subiu := RelacaoSubiuEvent.new()
	subiu.player_id = action.player_id
	subiu.estabelecimento = action.estabelecimento
	subiu.dias = dias
	subiu.cota = cota
	return [subiu]


# --- Retirar ---

## Devolve tudo o que está pronto. A taxa já foi cobrada pelo `InventorySystem`
## quando esta ação passou por lá — aqui só se confere se o número bate.
func _retira(action: RetirarAction) -> Array[SimEvent]:
	var def := def_de(action.estabelecimento)
	if def == null:
		return [_rejeita(action, MOTIVO_ESTABELECIMENTO_DESCONHECIDO)]

	var devido := taxa_a_pagar(action.estabelecimento)
	if _estado.prontas(action.estabelecimento).is_empty():
		return [_rejeita(action, MOTIVO_NADA_PRONTO)]
	if -action.valor != devido:
		return [_rejeita(action, MOTIVO_TAXA_INCORRETA)]

	# Uma linha por item de saída: normalmente é um só, mas encomenda velha de
	# um `.tres` rebalanceado pode carregar outro — e ela sai pelo que foi
	# combinado, não pelo que a receita diz hoje.
	var por_item: Dictionary = {}
	for enc in _estado.retira(action.estabelecimento):
		por_item[enc.item_id] = int(por_item.get(enc.item_id, 0)) + enc.qtd

	var itens: Array[String] = []
	for item_id: String in por_item.keys():
		itens.append(item_id)
	itens.sort()

	var events: Array[SimEvent] = []
	for item_id in itens:
		var feita := RetiradaFeitaEvent.new()
		feita.player_id = action.player_id
		feita.estabelecimento = action.estabelecimento
		feita.item_id = item_id
		feita.qtd = int(por_item[item_id])
		feita.taxa_paga = devido
		events.append(feita)
	return events


# --- O relógio ---

## Põe o ponteiro no minuto informado e conclui o que venceu. Andar para trás
## não acontece no jogo, mas um save carregado no meio da sessão poderia — e
## concluir por engano seria pior do que não fazer nada.
func _acerta_relogio(minuto: int) -> Array[SimEvent]:
	if minuto <= _estado.relogio:
		return []
	_estado.relogio = minuto

	var events: Array[SimEvent] = []
	for id in _estado.ids():
		for enc in _estado.conclui_ate(id, minuto):
			var pronto := BeneficiamentoProntoEvent.new()
			pronto.estabelecimento = id
			pronto.item_id = enc.item_id
			pronto.qtd = enc.qtd
			events.append(pronto)
	return events


## Carimba a rejeição e monta o aviso. `motivo` é id de máquina; quem fala com o
## jogador é `game/`.
func _rejeita(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var evento := ActionRejectedEvent.new()
	evento.player_id = action.player_id
	evento.acao = action.get_script().get_global_name()
	evento.motivo = motivo
	return evento
