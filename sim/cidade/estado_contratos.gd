class_name EstadoContratos
extends RefCounted

## O que o dono lembra do que pediu — dono exclusivo do `SistemaContratos`.
##
## ## Um contrato ativo por estabelecimento
##
## Oferta nova só sai onde não há contrato em pé. O atrito do degrau 2 vem do
## prazo e do relógio (PRINCIPIOS §7), não de fila de pedidos — três encomendas
## empilhadas no mesmo moinho viraria lista de tarefas, não decisão.
##
## ## O contrato some quando termina
##
## Cumprido e falho **não ficam** guardados: o `ContratoCumpridoEvent` e o
## `ContratoFalhouEvent` carregam tudo o que a tela precisa mostrar, e histórico
## no save só engordaria o arquivo sem ninguém consultar. Quem quiser um diário
## de contratos guarda em `game/`, que é onde ele seria lido.
##
## ## `minuto_limite` é um campo só
##
## Enquanto oferecido, ele é o prazo para **responder**; depois de aceito, o
## prazo para **cumprir**. As duas datas nunca coexistem — aceitar reescreve o
## limite —, e aceitar de novo não mexe nele: senão bastaria reclicar para ganhar
## prazo. O número é o relógio monotônico do `EstadoCidade`, o mesmo que faz a
## madrugada não adiantar encomenda.
##
## ## A constância conhecida
##
## `dias(id)` é a **cópia** de `dias_com_entrega`, que chega pelo
## `RelacaoSubiuEvent`. O sistema que pede não lê o state de quem vende (regra da
## wave 02): ele reage ao evento e guarda o número aqui. Se as duas divergirem —
## save remendado à mão, por exemplo —, a próxima entrega acerta sozinha.
##
## Todo campo tem default e entra no bloco `contratos` do save por
## `to_dict`/`from_dict`.

## A semente do sorteio quando a partida é nova. Fixa de propósito: mesma
## partida, mesma sequência de ofertas — replay e bug report continuam
## confiáveis (decisão herdada da wave 09).
const SEMENTE_PADRAO: int = 20260822

## O mesmo instante inicial do `EstadoCidade`: dia 1 às 06:00.
const RELOGIO_DEFAULT: int = EstadoCidade.RELOGIO_DEFAULT


## O pedido de um dono. Nasce oferecido; vira compromisso ao ser aceito.
##
## `pagamento` é o total combinado **na oferta**, não recalculado na entrega: o
## `.tres` pode ser rebalanceado no meio do prazo, e o que vale é o que foi
## prometido — a mesma regra da taxa que viaja dentro da encomenda.
class Contrato extends RefCounted:
	var estabelecimento: String = ""
	var item_id: String = ""
	var qtd: int = 0
	var pagamento: int = 0
	var aceito: bool = false
	## Prazo para responder enquanto oferecido; prazo para cumprir depois de
	## aceito. Em minutos do relógio monotônico.
	var minuto_limite: int = 0

	## O dono não entra no dicionário: ele é a chave do bloco no save.
	func to_dict() -> Dictionary:
		return {
			"item_id": item_id,
			"qtd": qtd,
			"pagamento": pagamento,
			"aceito": aceito,
			"minuto_limite": minuto_limite,
		}

	## Contrato sem item ou sem quantidade é lixo de save: devolve `null`. Ele
	## nunca poderia ser cumprido e ficaria bloqueando a oferta seguinte para
	## sempre.
	static func from_dict(estabelecimento_id: String, data: Dictionary) -> Contrato:
		var con := Contrato.new()
		con.estabelecimento = estabelecimento_id
		con.item_id = String(data.get("item_id", ""))
		con.qtd = int(data.get("qtd", 0))
		con.pagamento = int(data.get("pagamento", 0))
		con.aceito = bool(data.get("aceito", false))
		con.minuto_limite = int(data.get("minuto_limite", 0))
		if con.estabelecimento.is_empty() or con.item_id.is_empty() or con.qtd <= 0:
			return null
		return con


## A semente do RNG de sorteio, no save.
var semente: int = SEMENTE_PADRAO

## O relógio monotônico, copiado dos eventos do tempo — **não** lido do
## `EstadoCidade`, que é state alheio, nem do `TimeState`.
##
## Ele existe porque aceitar é uma **ação**: quando o jogador topa, o prazo
## precisa ser contado a partir de agora, e não há evento na mão para dizer que
## horas são. Guardado no save para que um contrato aceito logo depois de
## carregar a partida não nasça com prazo do dia 1.
var relogio: int = RELOGIO_DEFAULT

## id do estabelecimento -> Contrato ativo. Sem entrada = sem contrato.
var _contratos: Dictionary = {}

## id do estabelecimento -> dias de constância conhecidos, copiados do evento.
var _dias: Dictionary = {}


## Ids com contrato ativo, em ordem alfabética. A ordem é contrato: o save e a
## sequência de eventos têm que sair iguais, sem depender de quem sorteou
## primeiro.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _contratos.keys():
		out.append(id)
	out.sort()
	return out


# --- Leitura ---

## O dia de jogo em que o relógio está. Mesma conta do `EstadoCidade`: a
## madrugada pertence à noite do dia anterior, então descontar o horário de
## acordar devolve o dia útil inteiro para o mesmo número.
func dia_do_jogo() -> int:
	@warning_ignore("integer_division")
	var dia := (relogio - TimeSystem.MINUTO_ACORDAR) / TimeSystem.MINUTOS_POR_DIA
	return dia

func tem_contrato(id: String) -> bool:
	return _contratos.has(id)

## O contrato ativo, ou `null`.
func contrato(id: String) -> Contrato:
	return _contratos.get(id, null) as Contrato

## A constância conhecida deste estabelecimento.
func dias(id: String) -> int:
	return int(_dias.get(id, 0))

## Os contratos cujo limite já passou, em ordem alfabética. **Não** tira
## ninguém da ficha: encerrar é decisão do sistema, que precisa distinguir
## oferta ignorada (sem custo) de compromisso estourado (custa constância).
func vencidos_ate(minuto: int) -> Array[Contrato]:
	var out: Array[Contrato] = []
	for id in ids():
		var con := contrato(id)
		if con.minuto_limite <= minuto:
			out.append(con)
	return out


# --- Escrita ---

## Põe a oferta na mesa. Onde já há contrato, não entra — um por
## estabelecimento.
func oferece(con: Contrato) -> void:
	if con == null or con.estabelecimento.is_empty():
		return
	if _contratos.has(con.estabelecimento):
		return
	_contratos[con.estabelecimento] = con

## O jogador topou. Devolve `false` se não havia oferta ou se ela já era
## compromisso — aceitar duas vezes não estica prazo.
func aceita(id: String, minuto_limite: int) -> bool:
	var con := contrato(id)
	if con == null or con.aceito:
		return false
	con.aceito = true
	con.minuto_limite = minuto_limite
	return true

## Tira o contrato da ficha e devolve, para quem encerra montar o evento.
func encerra(id: String) -> Contrato:
	var con := contrato(id)
	if con == null:
		return null
	_contratos.erase(id)
	return con

## Guarda a constância que chegou pelo `RelacaoSubiuEvent`.
func define_dias(id: String, valor: int) -> void:
	_dias[id] = maxi(valor, 0)


# --- Save ---

## Snapshot para o save, na ordem contratada.
func to_dict() -> Dictionary:
	var contratos: Dictionary = {}
	for id in ids():
		contratos[id] = (_contratos[id] as Contrato).to_dict()
	var constancia: Dictionary = {}
	var conhecidos: Array[String] = []
	for id: String in _dias.keys():
		conhecidos.append(id)
	conhecidos.sort()
	for id in conhecidos:
		constancia[id] = int(_dias[id])
	return {
		"semente": semente,
		"relogio": relogio,
		"contratos": contratos,
		"dias": constancia,
	}

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai no
## default — é assim que o bloco `contratos` entra sem migração.
func from_dict(data: Dictionary) -> void:
	_contratos = {}
	_dias = {}
	semente = int(data.get("semente", SEMENTE_PADRAO))
	relogio = int(data.get("relogio", RELOGIO_DEFAULT))
	var contratos: Dictionary = data.get("contratos", {})
	for chave: Variant in contratos:
		var bruto: Variant = contratos[chave]
		if not bruto is Dictionary:
			continue
		var con := Contrato.from_dict(String(chave), bruto)
		if con != null:
			_contratos[con.estabelecimento] = con
	var constancia: Dictionary = data.get("dias", {})
	for chave: Variant in constancia:
		_dias[String(chave)] = maxi(int(constancia[chave]), 0)
