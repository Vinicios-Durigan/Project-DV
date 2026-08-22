class_name SistemaContratos
extends SimSystem

## O degrau 2 da escada: o dono encomenda, o jogador aceita ou não, e o prazo
## corre (PRINCIPIOS §3).
##
## ## Por que este sistema existe separado do `SistemaCidade`
##
## Beneficiar e encomendar são mecânicas diferentes: uma é serviço contratado
## pelo jogador, a outra é pedido feito **a** ele. Juntá-las no mesmo sistema
## faria um arquivo decidir cota, fila, prazo e amizade ao mesmo tempo — e a
## regra do projeto é mecânica nova = arquivo novo.
##
## Mais importante: **o sistema que pede não lê o state de quem vende** (regra
## da wave 02). A constância chega pelo `RelacaoSubiuEvent` e mora no
## `EstadoContratos`. Se um dia o ferreiro passar a encomendar sem beneficiar
## nada, nada aqui muda.
##
## ## A oferta é garantida; o que o RNG decide é o tamanho
##
## Todo dono liberado e sem contrato na mesa encomenda na virada do dia. Sortear
## *se* haveria pedido tornaria a mecânica invisível em partidas azaradas — e o
## que dá tensão não é a existência da oferta, é o prazo dela. O RNG decide
## quantos lotes, e nada mais.
##
## A semente mora no save e o sorteio é derivado de `(semente, dia, dono)`, sem
## estado de RNG a persistir: a mesma partida produz a mesma sequência de
## encomendas, mesmo carregando no meio (decisão herdada da wave 09).
##
## ## Cumprir cobra antes de validar
##
## `CumprirContratoAction` **é** uma `RemoveItemAction`: o `InventorySystem`,
## antes na ordem fixa, tira o item da mochila antes de este sistema olhar o
## prazo. É a mesma exceção do `PlantCropAction` (receita 2, §4), e é por isso
## que `pode_cumprir()` existe — `game/` pergunta antes de despachar.
##
## ## Quem legisla sobre amizade é a cidade
##
## Este sistema não credita nem debita constância. Ele emite
## `ContratoCumpridoEvent` e `ContratoFalhouEvent`; quanto isso vale em dias é
## decisão do `SistemaCidade`, que reage. Sistema magro, evento gordo.

const MOTIVO_ESTABELECIMENTO_DESCONHECIDO: String = "estabelecimento_desconhecido"
const MOTIVO_SEM_CONTRATO: String = "sem_contrato"
const MOTIVO_CONTRATO_JA_ACEITO: String = "contrato_ja_aceito"
const MOTIVO_CONTRATO_NAO_ACEITO: String = "contrato_nao_aceito"
const MOTIVO_ITEM_ERRADO: String = "item_errado"
const MOTIVO_QUANTIDADE_ERRADA: String = "quantidade_errada"

## Quantos dias a oferta fica na mesa antes de sair sozinha. Dois: ela aparece
## na manhã e sobrevive ao dia seguinte inteiro, então dá para ver o pedido,
## dormir, colher e responder no dia seguinte.
const DIAS_PARA_RESPONDER: int = 2

var _estado: EstadoContratos
## id -> DefEstabelecimento, o mesmo catálogo que a cidade usa. Definição é
## leitura livre; o que é proibido é ler *state* alheio.
var _defs: Dictionary
var _catalogo: ItemCatalog


## O diretório é injetável para o teste não depender do conteúdo do jogo, como
## no `SistemaCidade`. As defs são carregadas de novo aqui, e não pedidas a ele:
## catálogo é leitura livre, mas pedir a outro sistema criaria a dependência que
## este arquivo existe para não ter.
func _init(estado: EstadoContratos = null,
		dir_defs: String = DefEstabelecimento.DIR_PADRAO,
		catalogo: ItemCatalog = null) -> void:
	_estado = estado if estado != null else EstadoContratos.new()
	_defs = DefEstabelecimento.carrega_de(dir_defs)
	_catalogo = catalogo if catalogo != null else ItemCatalog.new()


func get_state() -> EstadoContratos:
	return _estado


# --- Consultas (para `game/`, que nunca decide regra) ---

## Ids dos estabelecimentos que existem, em ordem alfabética.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _defs.keys():
		out.append(id)
	out.sort()
	return out

func def_de(id: String) -> DefEstabelecimento:
	return _defs.get(id, null) as DefEstabelecimento

## O contrato ativo deste dono, ou `null`.
func contrato_de(id: String) -> EstadoContratos.Contrato:
	return _estado.contrato(id)

## Quanto falta para o prazo vencer, em minutos de jogo. `0` sem contrato — é o
## número da contagem regressiva da tela.
func minutos_para_vencer(id: String) -> int:
	var con := _estado.contrato(id)
	if con == null:
		return 0
	return maxi(con.minuto_limite - _estado.relogio, 0)

## Esta entrega seria aceita? `game/` pergunta antes de despachar, porque a ação
## cobra o item no `InventorySystem` antes de o prazo ser olhado.
func pode_cumprir(id: String, item_id: String, qtd: int) -> bool:
	return _recusa_do_cumprimento(id, item_id, qtd).is_empty()


# --- Ações ---

func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is ResponderContratoAction:
		return _responde(action as ResponderContratoAction)
	if action is CumprirContratoAction:
		return _cumpre(action as CumprirContratoAction)
	return []


func _responde(action: ResponderContratoAction) -> Array[SimEvent]:
	var con := _estado.contrato(action.estabelecimento)
	if con == null:
		return [_rejeita(action, MOTIVO_SEM_CONTRATO)]
	if con.aceito:
		return [_rejeita(action, MOTIVO_CONTRATO_JA_ACEITO)]
	if not action.aceita:
		return [_encerra(action.estabelecimento, ContratoFalhouEvent.MOTIVO_RECUSADO,
				action.player_id)]

	var def := def_de(action.estabelecimento)
	var prazo := def.contrato_prazo_dias * TimeSystem.MINUTOS_POR_DIA
	_estado.aceita(action.estabelecimento, _estado.relogio + prazo)

	var evento := ContratoAceitoEvent.new()
	evento.player_id = action.player_id
	evento.estabelecimento = con.estabelecimento
	evento.item_id = con.item_id
	evento.qtd = con.qtd
	evento.pagamento = con.pagamento
	evento.minuto_limite = con.minuto_limite
	return [evento]


func _cumpre(action: CumprirContratoAction) -> Array[SimEvent]:
	var motivo := _recusa_do_cumprimento(action.estabelecimento, action.item_id, action.qtd)
	if not motivo.is_empty():
		return [_rejeita(action, motivo)]

	var con := _estado.encerra(action.estabelecimento)
	var evento := ContratoCumpridoEvent.new()
	evento.player_id = action.player_id
	evento.estabelecimento = con.estabelecimento
	evento.item_id = con.item_id
	evento.qtd = con.qtd
	evento.pagamento = con.pagamento

	# O contrato não mexe na carteira: ele avisa, e o InventorySystem — dono do
	# dinheiro — reage. Mesmo desenho do `ItemGrantedEvent`.
	var pagamento := DinheiroConcedidoEvent.new()
	pagamento.player_id = action.player_id
	pagamento.valor = con.pagamento
	pagamento.motivo = con.estabelecimento
	return [evento, pagamento]


## O motivo pelo qual esta entrega não passa, ou `""` se passa. Uma função só
## para a recusa e para `pode_cumprir()` — duas cópias divergiriam.
func _recusa_do_cumprimento(id: String, item_id: String, qtd: int) -> String:
	if not _defs.has(id):
		return MOTIVO_ESTABELECIMENTO_DESCONHECIDO
	var con := _estado.contrato(id)
	if con == null:
		return MOTIVO_SEM_CONTRATO
	if not con.aceito:
		return MOTIVO_CONTRATO_NAO_ACEITO
	if con.item_id != item_id:
		return MOTIVO_ITEM_ERRADO
	if con.qtd != qtd:
		return MOTIVO_QUANTIDADE_ERRADA
	return ""


# --- Reações ---

func react(event: SimEvent) -> Array[SimEvent]:
	if event is MinuteTickedEvent:
		var minuto := event as MinuteTickedEvent
		return _acerta_relogio(EstadoCidade.minuto_monotonico(minuto.dia, minuto.minuto))
	if event is DayEndedEvent:
		var virada := event as DayEndedEvent
		var relogio := EstadoCidade.minuto_monotonico(virada.dia_novo, TimeSystem.MINUTO_ACORDAR)
		var eventos := _acerta_relogio(relogio)
		eventos.append_array(_sorteia())
		return eventos
	if event is RelacaoSubiuEvent:
		var relacao := event as RelacaoSubiuEvent
		_estado.define_dias(relacao.estabelecimento, relacao.dias)
	# A cópia acompanha a queda também, senão o dono continuaria encomendando
	# para quem já perdeu o degrau.
	if event is RelacaoCaiuEvent:
		var queda := event as RelacaoCaiuEvent
		_estado.define_dias(queda.estabelecimento, queda.dias)
	return []


## Empurra o relógio e encerra o que venceu. Nunca anda para trás: um evento
## atrasado não pode ressuscitar prazo.
func _acerta_relogio(minuto: int) -> Array[SimEvent]:
	if minuto <= _estado.relogio:
		return []
	_estado.relogio = minuto
	var eventos: Array[SimEvent] = []
	for con in _estado.vencidos_ate(minuto):
		var motivo := ContratoFalhouEvent.MOTIVO_ESTOURADO if con.aceito \
				else ContratoFalhouEvent.MOTIVO_EXPIRADO
		eventos.append(_encerra(con.estabelecimento, motivo))
	return eventos


## A rodada de encomendas da manhã. Ordem alfabética: a sequência de eventos é
## contrato e não pode depender da ordem de carga dos `.tres`.
func _sorteia() -> Array[SimEvent]:
	var eventos: Array[SimEvent] = []
	var dia := _estado.dia_do_jogo()
	for id in ids():
		var evento := _encomenda(id, dia)
		if evento != null:
			eventos.append(evento)
	return eventos


## A encomenda deste dono hoje, ou `null` se ele não pede.
func _encomenda(id: String, dia: int) -> ContratoOferecidoEvent:
	if _estado.tem_contrato(id):
		return null
	var def := def_de(id)
	if def == null or not def.encomenda_com(_estado.dias(id)):
		return null

	var rng := _rng_de(id, dia)
	var lotes := rng.randi_range(def.contrato_lotes_min, def.contrato_lotes_max)
	var qtd := lotes * def.entram

	var con := EstadoContratos.Contrato.new()
	con.estabelecimento = id
	con.item_id = def.item_entrada
	con.qtd = qtd
	con.pagamento = def.pagamento_de(qtd, _preco_de(def.item_entrada))
	con.minuto_limite = _estado.relogio + DIAS_PARA_RESPONDER * TimeSystem.MINUTOS_POR_DIA
	_estado.oferece(con)

	var evento := ContratoOferecidoEvent.new()
	evento.estabelecimento = con.estabelecimento
	evento.item_id = con.item_id
	evento.qtd = con.qtd
	evento.pagamento = con.pagamento
	evento.minuto_limite = con.minuto_limite
	return evento


## O RNG deste dono neste dia. Derivar da semente + dia + id dispensa guardar
## estado de RNG no save: carregar a partida no meio não desalinha a sequência.
func _rng_de(id: String, dia: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _estado.semente + dia * 1000003 + id.hash()
	return rng


## Preço de venda do item, ou 0 se ele não estiver no catálogo — item fora do
## catálogo não paga nada, em vez de derrubar a sim.
func _preco_de(item_id: String) -> int:
	var def := _catalogo.get_def(item_id)
	return def.preco_venda if def != null else 0


## Tira o contrato da ficha e monta o evento de fim. `player_id` fica em 0
## quando foi o tempo que encerrou — ninguém agiu.
func _encerra(id: String, motivo: String, player_id: int = 0) -> ContratoFalhouEvent:
	var con := _estado.encerra(id)
	var evento := ContratoFalhouEvent.new()
	evento.player_id = player_id
	evento.estabelecimento = id
	evento.motivo = motivo
	if con != null:
		evento.item_id = con.item_id
		evento.qtd = con.qtd
	return evento


func _rejeita(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var evento := ActionRejectedEvent.new()
	evento.player_id = action.player_id
	evento.acao = action.get_script().get_global_name()
	evento.motivo = motivo
	return evento
