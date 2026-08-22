extends GutTest

## O que um contrato vale em amizade — e é a **cidade** quem decide isso.
##
## O `SistemaContratos` emite `ContratoCumpridoEvent` e `ContratoFalhouEvent`
## sem dizer quanto valem. Quem legisla sobre relação é o `SistemaCidade`, que
## reage: cumprir vale vários dias de constância de uma vez, estourar prazo tira
## dois. Sistema magro, evento gordo — e o contrato não precisa saber o que é
## cota.
##
## ## Por que acelerar
##
## Sem isso, o contrato seria só uma venda melhor. Com isso, ele é o **caminho
## rápido de contrato para dono** (PRINCIPIOS §3): a cota sobe mais depressa, e
## é a cota batendo na capacidade que destrava a compra (§4).
##
## ## Por que a queda existe, se relação não zera
##
## Faltar não pune — quem some por uma semana não perde nada (§6). O que custa é
## **aceitar e não cumprir**, que é uma promessa quebrada, não uma ausência. O
## piso é zero: nem o pior jogador fica devendo amizade.

const MOINHO: String = "moinho"
const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _factory: SimFactory
var _world: SimWorld
var _cidade: SistemaCidade
var _estado: EstadoCidade
var _contratos: SistemaContratos


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	_estado = _factory.get_estado_cidade()
	for system in _world.get_systems():
		if system is SistemaCidade:
			_cidade = system
		if system is SistemaContratos:
			_contratos = system

func _cumpriu() -> Array[SimEvent]:
	var evento := ContratoCumpridoEvent.new()
	evento.player_id = JOGADOR
	evento.estabelecimento = MOINHO
	evento.item_id = "trigo"
	evento.qtd = 4
	evento.pagamento = 150
	return _cidade.react(evento)

func _falhou(motivo: String) -> Array[SimEvent]:
	var evento := ContratoFalhouEvent.new()
	evento.player_id = JOGADOR
	evento.estabelecimento = MOINHO
	evento.item_id = "trigo"
	evento.qtd = 4
	evento.motivo = motivo
	return _cidade.react(evento)

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null


# --- Cumprir acelera ---

func test_cumprir_vale_varios_dias_de_uma_vez() -> void:
	_cumpriu()
	assert_eq(_estado.dias_com_entrega(MOINHO), SistemaCidade.DIAS_POR_CONTRATO,
			"é o caminho rápido para virar dono, não mais um dia qualquer")

func test_cumprir_avisa_com_a_cota_nova() -> void:
	var evento := _primeiro(_cumpriu(), RelacaoSubiuEvent) as RelacaoSubiuEvent
	assert_not_null(evento, "mudou relação, saiu evento")
	assert_eq(evento.estabelecimento, MOINHO, "de quem")
	assert_eq(evento.dias, SistemaCidade.DIAS_POR_CONTRATO, "quantos dias agora")
	assert_eq(evento.cota, _cidade.def_de(MOINHO).cota_com(evento.dias),
			"a cota vem recalculada — quem escuta não precisa abrir o .tres")

func test_cumprir_empurra_a_cota_para_o_degrau_seguinte() -> void:
	var antes := _estado.cota(MOINHO)
	_cumpriu()
	assert_gt(_estado.cota(MOINHO), antes,
			"três dias de uma vez cruzam o primeiro limiar dos .tres do jogo")

func test_dois_contratos_cumpridos_somam() -> void:
	_cumpriu()
	_cumpriu()
	assert_eq(_estado.dias_com_entrega(MOINHO), SistemaCidade.DIAS_POR_CONTRATO * 2,
			"cada compromisso cumprido conta por si — não é constância de dia")


# --- Falhar só custa quando houve promessa ---

func test_estourar_o_prazo_custa_constancia() -> void:
	_cumpriu()
	_falhou(ContratoFalhouEvent.MOTIVO_ESTOURADO)
	assert_eq(_estado.dias_com_entrega(MOINHO),
			SistemaCidade.DIAS_POR_CONTRATO - SistemaCidade.DIAS_PERDIDOS_NO_ESTOURO,
			"aceitou e não cumpriu — promessa quebrada dói")

func test_estourar_avisa_com_evento_proprio() -> void:
	_cumpriu()
	var evento := _primeiro(_falhou(ContratoFalhouEvent.MOTIVO_ESTOURADO),
			RelacaoCaiuEvent) as RelacaoCaiuEvent
	assert_not_null(evento, "a queda tem evento próprio — RelacaoSubiu mentiria no nome")
	assert_eq(evento.dias, SistemaCidade.DIAS_POR_CONTRATO
			- SistemaCidade.DIAS_PERDIDOS_NO_ESTOURO, "quantos dias sobraram")
	assert_eq(evento.cota, _cidade.def_de(MOINHO).cota_com(evento.dias),
			"a cota acompanha: ela é derivada dos dias")

func test_recusar_nao_custa_nada() -> void:
	_cumpriu()
	var antes := _estado.dias_com_entrega(MOINHO)
	var eventos := _falhou(ContratoFalhouEvent.MOTIVO_RECUSADO)
	assert_eq(_estado.dias_com_entrega(MOINHO), antes, "dizer não é de graça")
	assert_null(_primeiro(eventos, RelacaoCaiuEvent), "e nem evento sai")

func test_oferta_ignorada_nao_custa_nada() -> void:
	_cumpriu()
	var antes := _estado.dias_com_entrega(MOINHO)
	_falhou(ContratoFalhouEvent.MOTIVO_EXPIRADO)
	assert_eq(_estado.dias_com_entrega(MOINHO), antes,
			"ausência não pune — a mesma filosofia da planta não regada (§6)")

func test_a_relacao_tem_piso_zero() -> void:
	_falhou(ContratoFalhouEvent.MOTIVO_ESTOURADO)
	assert_eq(_estado.dias_com_entrega(MOINHO), 0,
			"ninguém fica devendo amizade")


# --- O contrato fica sabendo ---

func test_a_queda_chega_no_sistema_de_contratos() -> void:
	_estado.credita_bonus(MOINHO, 1, 9)
	var evento := RelacaoCaiuEvent.new()
	evento.estabelecimento = MOINHO
	evento.dias = 2
	evento.cota = 6
	_contratos.react(evento)
	assert_eq(_factory.get_estado_contratos().dias(MOINHO), 2,
			"a cópia acompanha a queda, senão o dono continuaria encomendando"
			+ " para quem já perdeu o degrau")


# --- A regra do dia único continua valendo ---

func test_contrato_no_mesmo_dia_de_uma_entrega_nao_conta_duas_vezes() -> void:
	_cidade.react(_minuto(3, 600))
	_cumpriu()
	var depois_do_contrato := _estado.dias_com_entrega(MOINHO)
	assert_false(_estado.credita_dia(MOINHO, _estado.dia_do_jogo()),
			"o dia do contrato já está carimbado")
	assert_eq(_estado.dias_com_entrega(MOINHO), depois_do_contrato,
			"a entrega comum do mesmo dia não soma mais um por cima do bônus")

func _minuto(dia: int, minuto: int) -> MinuteTickedEvent:
	var evento := MinuteTickedEvent.new()
	evento.dia = dia
	evento.minuto = minuto
	return evento
