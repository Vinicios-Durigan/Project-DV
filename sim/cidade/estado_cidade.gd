class_name EstadoCidade
extends RefCounted

## O que a cidade lembra do jogador — dono exclusivo do `SistemaCidade`.
##
## ## O relógio monotônico
##
## `relogio` é o instante do mundo num número só. É o que faz uma encomenda de 4
## horas e uma de 3 dias serem o mesmo cálculo, e o que dispensa a cidade de
## escutar a virada do dia: a encomenda que venceu durante a noite conclui
## sozinha quando o ponteiro passa por cima dela.
##
## `dia × 1440 + minuto` **não** serve, e o motivo é o dia útil do jogo: o
## relógio do mundo vira à meia-noite (`minuto` volta a 0) mas o **dia** só vira
## ao dormir ou ao colapsar às 02:00. Somando cru, 00:00 daria um número *menor*
## que 23:59 — o tempo andaria para trás uma vez por noite, e toda encomenda da
## madrugada ficaria pronta cedo demais.
##
## `minuto_monotonico()` conserta: a madrugada (00:00–05:59) pertence à noite do
## dia anterior, então ela ganha um dia inteiro somado. Ver os testes de
## `test_estado_cidade.gd` — eles prendem as duas beiradas, meia-noite e o
## colapso das 02:00.
##
## O relógio é copiado de `MinuteTickedEvent`/`DayEndedEvent`, nunca lido do
## `TimeState`: state alheio é proibido, evento é o caminho.
##
## ## A cota é ocupada até a retirada
##
## Encomenda ocupa cota desde a entrega e só libera quando o jogador **busca**.
## Pronta e esquecida continua entupindo o estabelecimento — é o atrito que
## transforma "beneficiar" numa decisão de rota, e não num botão (PRINCIPIOS §9).
##
## ## O state é burro
##
## Ele não sabe o que é moinho nem quanto custa moer: a taxa viaja **dentro** da
## encomenda porque o preço combinado na entrega é o que se paga na retirada,
## mesmo que o `.tres` seja rebalanceado no meio.
##
## Todo campo tem default e entra no bloco `cidade` do save por
## `to_dict`/`from_dict`.

## O relógio do mundo novo: dia 1 às 06:00 (1 × 1440 + 360). O teste
## `test_o_relogio_comeca_no_primeiro_dia_as_seis` prende este número ao
## `TimeState` — se o mundo passar a acordar em outra hora, ele quebra aqui.
const RELOGIO_DEFAULT: int = 1800


## O instante do mundo num número só, que nunca anda para trás.
##
## O dia útil vai das 06:00 às 02:00, então a madrugada faz parte da noite do
## dia anterior e leva um dia inteiro somado. Sem isso, 00:00 valeria 1439
## minutos a menos que 23:59.
static func minuto_monotonico(dia: int, minuto: int) -> int:
	var noite := TimeSystem.MINUTOS_POR_DIA if minuto < TimeSystem.MINUTO_ACORDAR else 0
	return dia * TimeSystem.MINUTOS_POR_DIA + minuto + noite


## Um lote em beneficiamento. Guarda o que vai **sair** (é o que o jogador vem
## buscar) e o que **entrou** (é o que ocupa cota) — os dois, porque a receita
## que ligava um ao outro mora no `.tres` e pode mudar.
class Encomenda extends RefCounted:
	var item_id: String = ""
	var qtd: int = 0
	var qtd_entrada: int = 0
	var taxa: int = 0
	var minuto_conclusao: int = 0
	var pronta: bool = false

	func to_dict() -> Dictionary:
		return {
			"item_id": item_id,
			"qtd": qtd,
			"qtd_entrada": qtd_entrada,
			"taxa": taxa,
			"minuto_conclusao": minuto_conclusao,
			"pronta": pronta,
		}

	## Encomenda sem item ou sem saída é lixo de save: devolve `null`. Ela só
	## ocuparia cota para sempre, sem nunca virar item na mochila.
	static func from_dict(data: Dictionary) -> Encomenda:
		var enc := Encomenda.new()
		enc.item_id = String(data.get("item_id", ""))
		enc.qtd = int(data.get("qtd", 0))
		enc.qtd_entrada = int(data.get("qtd_entrada", 0))
		enc.taxa = int(data.get("taxa", 0))
		enc.minuto_conclusao = int(data.get("minuto_conclusao", 0))
		enc.pronta = bool(data.get("pronta", false))
		if enc.item_id.is_empty() or enc.qtd <= 0:
			return null
		return enc


## A ficha de um estabelecimento. Nasce zerada e só existe depois que o jogador
## encostou nele.
class Registro extends RefCounted:
	## Quantos dias diferentes tiveram entrega. Não zera nunca (PRINCIPIOS §6).
	var dias_com_entrega: int = 0
	## O último dia creditado, para a segunda entrega do dia não contar de novo.
	var ultimo_dia_creditado: int = 0
	## A cota vigente. Quem manda é o `DefEstabelecimento` + `dias_com_entrega`;
	## este campo é o espelho que a tela e o save leem, escrito pelo sistema.
	var cota: int = 0
	var encomendas: Array[Encomenda] = []

	func to_dict() -> Dictionary:
		var fila: Array[Dictionary] = []
		for enc in encomendas:
			fila.append(enc.to_dict())
		return {
			"dias_com_entrega": dias_com_entrega,
			"ultimo_dia_creditado": ultimo_dia_creditado,
			"cota": cota,
			"encomendas": fila,
		}

	static func from_dict(data: Dictionary) -> Registro:
		var reg := Registro.new()
		reg.dias_com_entrega = int(data.get("dias_com_entrega", 0))
		reg.ultimo_dia_creditado = int(data.get("ultimo_dia_creditado", 0))
		reg.cota = int(data.get("cota", 0))
		for entrada: Variant in data.get("encomendas", []):
			var bruto := entrada as Dictionary
			if bruto == null:
				continue
			var enc := Encomenda.from_dict(bruto)
			if enc != null:
				reg.encomendas.append(enc)
		return reg


## Relógio monotônico do mundo, em minutos: `dia × 1440 + minuto`.
var relogio: int = RELOGIO_DEFAULT

## id do estabelecimento -> Registro. Estabelecimento nunca visitado não tem
## entrada — é o que deixa a cidade crescer sem migração de save.
var _registros: Dictionary = {}


## O dia de jogo em que o relógio está, para creditar constância.
##
## Não é `relogio / 1440`: a madrugada leva um dia somado, então 00:30 cairia no
## dia seguinte e a segunda entrega da mesma noite creditaria duas vezes.
## Descontar o horário de acordar devolve o dia útil inteiro — 06:00 até 01:59 —
## para o mesmo número.
func dia_do_jogo() -> int:
	@warning_ignore("integer_division")
	var dia := (relogio - TimeSystem.MINUTO_ACORDAR) / TimeSystem.MINUTOS_POR_DIA
	return dia


## Ids com registro, em ordem alfabética. A ordem é contrato: o save tem que
## sair igual, não pode depender de quem foi visitado primeiro.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _registros.keys():
		out.append(id)
	out.sort()
	return out


# --- Leitura (nunca cria registro) ---

## Quantos dias diferentes tiveram entrega neste estabelecimento.
func dias_com_entrega(id: String) -> int:
	var reg := _peek(id)
	return reg.dias_com_entrega if reg != null else 0

## A cota vigente, como o sistema a escreveu.
func cota(id: String) -> int:
	var reg := _peek(id)
	return reg.cota if reg != null else 0

## Quantas unidades **de entrada** estão comprometidas aqui — em andamento e
## prontas esperando retirada.
func cota_usada(id: String) -> int:
	var total := 0
	for enc in encomendas(id):
		total += enc.qtd_entrada
	return total

## A fila deste estabelecimento, em ordem de chegada.
func encomendas(id: String) -> Array[Encomenda]:
	var reg := _peek(id)
	return reg.encomendas if reg != null else ([] as Array[Encomenda])

## O que está pronto e ainda não foi buscado.
func prontas(id: String) -> Array[Encomenda]:
	var out: Array[Encomenda] = []
	for enc in encomendas(id):
		if enc.pronta:
			out.append(enc)
	return out


# --- Escrita ---

## Credita um dia de constância. Devolve `false` se este dia já contou — duas
## entregas no mesmo dia valem uma (PRINCIPIOS §6).
func credita_dia(id: String, dia: int) -> bool:
	var reg := _registro(id)
	if dia <= reg.ultimo_dia_creditado:
		return false
	reg.ultimo_dia_creditado = dia
	reg.dias_com_entrega += 1
	return true

## Credita um bônus de constância de uma vez só — o preço de um compromisso
## cumprido, e não de mais um dia de rotina. Devolve os dias resultantes.
##
## Carimba `dia` como creditado: uma entrega comum no mesmo dia não soma outro
## por cima do bônus. Dois contratos diferentes no mesmo dia **somam**, porque
## cada um foi uma promessa distinta — a regra do dia único é sobre entrega,
## não sobre compromisso.
func credita_bonus(id: String, dia: int, quantos: int) -> int:
	var reg := _registro(id)
	reg.dias_com_entrega += maxi(quantos, 0)
	reg.ultimo_dia_creditado = maxi(reg.ultimo_dia_creditado, dia)
	return reg.dias_com_entrega

## Tira dias de constância, com piso em zero. Só promessa quebrada chega aqui:
## faltar não desconta nada (PRINCIPIOS §6). Devolve os dias resultantes.
func debita_dias(id: String, quantos: int) -> int:
	var reg := _registro(id)
	reg.dias_com_entrega = maxi(reg.dias_com_entrega - maxi(quantos, 0), 0)
	return reg.dias_com_entrega

## Escreve a cota vigente, para a tela e o save a lerem.
func define_cota(id: String, valor: int) -> void:
	_registro(id).cota = maxi(valor, 0)

## Põe o lote na fila. A ordem é de chegada: quem espera vê a própria vez.
func agenda(id: String, encomenda: Encomenda) -> void:
	if encomenda == null:
		return
	_registro(id).encomendas.append(encomenda)

## Marca como prontas as encomendas cujo minuto já chegou e devolve **só as
## recém-concluídas**. Chamar de novo não conclui nada duas vezes — senão o
## evento sairia a cada minuto.
func conclui_ate(id: String, minuto: int) -> Array[Encomenda]:
	var novas: Array[Encomenda] = []
	for enc in encomendas(id):
		if enc.pronta or enc.minuto_conclusao > minuto:
			continue
		enc.pronta = true
		novas.append(enc)
	return novas

## Tira da fila tudo o que está pronto e devolve. O que ainda está no forno
## fica — e continua ocupando cota.
func retira(id: String) -> Array[Encomenda]:
	var reg := _peek(id)
	if reg == null:
		return []
	var levadas: Array[Encomenda] = []
	var ficam: Array[Encomenda] = []
	for enc in reg.encomendas:
		if enc.pronta:
			levadas.append(enc)
		else:
			ficam.append(enc)
	reg.encomendas = ficam
	return levadas


# --- Save ---

## Snapshot para o save, na ordem contratada.
func to_dict() -> Dictionary:
	var estabelecimentos: Dictionary = {}
	for id in ids():
		estabelecimentos[id] = (_registros[id] as Registro).to_dict()
	return {
		"relogio": relogio,
		"estabelecimentos": estabelecimentos,
	}

## Carrega do save, substituindo o que estiver em memória. Campo ausente cai no
## default — é assim que o bloco `cidade` entrou sem migração.
func from_dict(data: Dictionary) -> void:
	_registros = {}
	relogio = int(data.get("relogio", RELOGIO_DEFAULT))
	var estabelecimentos: Dictionary = data.get("estabelecimentos", {})
	for chave: Variant in estabelecimentos:
		var bruto: Variant = estabelecimentos[chave]
		if not bruto is Dictionary:
			continue
		_registros[String(chave)] = Registro.from_dict(bruto)


## O registro, criado sob demanda. Só quem escreve chama por aqui.
func _registro(id: String) -> Registro:
	if not _registros.has(id):
		_registros[id] = Registro.new()
	return _registros[id] as Registro

## O registro, ou `null`. Leitura não cria registro: encheria o save de
## estabelecimento que o jogador nunca visitou.
func _peek(id: String) -> Registro:
	return _registros.get(id, null) as Registro
