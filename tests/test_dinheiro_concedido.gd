extends GutTest

## O canal por onde uma mecânica paga o jogador sem ser o caixote.
##
## Até a wave 12 havia dois caminhos para a carteira: `AddMoneyAction`, que é
## intenção vinda de `game/`, e `ItemsSoldEvent`, que é a venda ao dormir. Um
## contrato cumprido não é nenhum dos dois — é um fato consumado dentro da sim,
## e quem precisa mexer no dinheiro é o `InventorySystem`, dono da carteira.
##
## `DinheiroConcedidoEvent` é o irmão do `ItemGrantedEvent`: quem conceder
## dinheiro emite, e o inventário reage. Pescaria, festival ou prêmio futuro
## passam por aqui em vez de inventar o próprio caminho — e nenhum deles precisa
## conhecer o `InventoryState`.
##
## É **só crédito**. Cobrança continua sendo `AddMoneyAction` com valor
## negativo, que pode ser recusada por saldo — e recusa precisa de ação, não de
## evento: evento é fato consumado, não pede licença.

const MOINHO: String = "moinho"
const JOGADOR: int = SimFactory.PLAYER_PADRAO
const AMIGO: int = 3

var _factory: SimFactory
var _world: SimWorld
var _inventario: InventorySystem
var _contratos: SistemaContratos


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	for system in _world.get_systems():
		if system is InventorySystem:
			_inventario = system
		if system is SistemaContratos:
			_contratos = system

func _dinheiro() -> int:
	return _factory.get_inventory_state().get_player(JOGADOR).dinheiro

func _concede(valor: int) -> Array[SimEvent]:
	var evento := DinheiroConcedidoEvent.new()
	evento.player_id = JOGADOR
	evento.valor = valor
	evento.motivo = "teste"
	return _inventario.react(evento)

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null


# --- O canal ---

func test_conceder_soma_na_carteira() -> void:
	var antes := _dinheiro()
	_concede(150)
	assert_eq(_dinheiro(), antes + 150, "o inventário é quem mexe no dinheiro")

func test_conceder_avisa_com_money_changed() -> void:
	var antes := _dinheiro()
	var evento := _primeiro(_concede(150), MoneyChangedEvent) as MoneyChangedEvent
	assert_not_null(evento, "a carteira mudou, então sai o evento de sempre")
	assert_eq(evento.de, antes, "de quanto era")
	assert_eq(evento.para, antes + 150, "para quanto foi")
	assert_eq(evento.delta, 150, "o quanto entrou — quem escuta o HUD já sabe ler isto")

func test_conceder_zero_nao_mexe_em_nada() -> void:
	assert_eq(_concede(0).size(), 0, "sem mudança, sem evento")

func test_o_canal_e_so_de_credito() -> void:
	var antes := _dinheiro()
	_concede(-100)
	assert_eq(_dinheiro(), antes,
			"cobrança é AddMoneyAction negativa, que pode ser recusada por saldo;"
			+ " evento é fato consumado e não pede licença")


# --- Ponta a ponta com o contrato ---

func test_contrato_cumprido_paga_o_prometido() -> void:
	_factory.get_estado_contratos().define_dias(MOINHO, AMIGO)
	_world.handle(SleepAction.new())
	var viagem := ViajarAction.new()
	viagem.destino = EstadoLocais.CIDADE
	_world.handle(viagem)

	var oferta := _contratos.contrato_de(MOINHO)
	var dar := AddItemAction.new()
	dar.item_id = oferta.item_id
	dar.qtd = oferta.qtd
	_world.handle(dar)

	var resposta := ResponderContratoAction.new()
	resposta.estabelecimento = MOINHO
	resposta.aceita = true
	_world.handle(resposta)

	var antes := _dinheiro()
	var acao := CumprirContratoAction.new()
	acao.estabelecimento = MOINHO
	acao.item_id = oferta.item_id
	acao.qtd = oferta.qtd
	var eventos := _world.handle(acao)

	assert_eq(_dinheiro(), antes + oferta.pagamento,
			"o pagamento combinado na oferta cai na carteira ao cumprir")
	assert_not_null(_primeiro(eventos, DinheiroConcedidoEvent),
			"e o caminho é o canal novo, não um AddMoneyAction escondido em sim/")

func test_o_evento_carrega_o_motivo_para_o_resumo_do_dia() -> void:
	_factory.get_estado_contratos().define_dias(MOINHO, AMIGO)
	_world.handle(SleepAction.new())
	var evento := DinheiroConcedidoEvent.new()
	evento.player_id = JOGADOR
	evento.valor = 10
	evento.motivo = MOINHO
	_inventario.react(evento)
	assert_eq(evento.motivo, MOINHO,
			"evento gordo: quem paga se identifica, para a tela dizer de onde veio")
