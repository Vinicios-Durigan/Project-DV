extends GutTest

## O degrau 2 da escada: o dono encomenda, e aceitar é apostar.
##
## ## O que separa contrato de esteira
##
## Beneficiar não tem como dar errado — entrega, espera, busca. O contrato tem
## prazo, e o prazo é o atrito que transforma "entregar" em "quando e quanto
## entregar" (PRINCIPIOS §7). Recusar é grátis; **aceitar e falhar** é o que
## custa, e é isso que faz a oferta ser uma decisão.
##
## ## O sistema que pede não lê o state de quem vende
##
## `SistemaContratos` nunca toca no `EstadoCidade`. A constância chega pelo
## `RelacaoSubiuEvent` e fica guardada no state dele (regra da wave 02). Por
## isso a cópia existe, e é ela que o teste manipula quando quer um dono já
## amigo.
##
## ## Cumprir cobra antes de o contrato validar
##
## `CumprirContratoAction` **é** uma `RemoveItemAction`: o `InventorySystem`, que
## roda antes, tira o item da mochila antes de alguém olhar o prazo. Mesma
## exceção do `PlantCropAction` (receita 2, §4) — por isso existe
## `pode_cumprir()`, e é a resposta dela que `game/` consulta.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"
const JOGADOR: int = SimFactory.PLAYER_PADRAO
## Constância que já passou do primeiro limiar dos dois `.tres` (3 dias).
const AMIGO: int = 3

var _factory: SimFactory
var _world: SimWorld
var _contratos: SistemaContratos
var _estado: EstadoContratos


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	_estado = _factory.get_estado_contratos()
	for system in _world.get_systems():
		if system is SistemaContratos:
			_contratos = system
	_vai_para_cidade()

func _vai_para_cidade() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.CIDADE
	_world.handle(acao)

func _volta_para_fazenda() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.FAZENDA
	_world.handle(acao)

func _da_item(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.item_id = item_id
	acao.qtd = qtd
	_world.handle(acao)

## O dono já conhece o jogador: a cópia da constância entra direto, que é
## exatamente o que o `RelacaoSubiuEvent` faria.
func _ja_amigo(id: String = MOINHO, dias: int = AMIGO) -> void:
	_estado.define_dias(id, dias)

func _dorme() -> Array[SimEvent]:
	return _world.handle(SleepAction.new())

func _responde(id: String, aceita: bool) -> Array[SimEvent]:
	var acao := ResponderContratoAction.new()
	acao.player_id = JOGADOR
	acao.estabelecimento = id
	acao.aceita = aceita
	return _world.handle(acao)

func _cumpre(id: String, item_id: String, qtd: int) -> Array[SimEvent]:
	var acao := CumprirContratoAction.new()
	acao.player_id = JOGADOR
	acao.estabelecimento = id
	acao.item_id = item_id
	acao.qtd = qtd
	return _world.handle(acao)

## A oferta do dia, já na mesa, com a mochila cheia do que ela pede.
func _oferta_na_mesa(id: String = MOINHO) -> EstadoContratos.Contrato:
	_ja_amigo(id)
	_dorme()
	var con := _estado.contrato(id)
	if con != null:
		_da_item(con.item_id, con.qtd)
	return con

func _primeiro(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null

func _recusa(eventos: Array[SimEvent]) -> ActionRejectedEvent:
	return _primeiro(eventos, ActionRejectedEvent) as ActionRejectedEvent


# --- A oferta ---

func test_dono_que_nao_conhece_o_jogador_nao_encomenda() -> void:
	var eventos := _dorme()
	assert_null(_primeiro(eventos, ContratoOferecidoEvent),
			"degrau mínimo 1: a escada não pula degrau (PRINCIPIOS §3)")

func test_dono_amigo_encomenda_na_virada_do_dia() -> void:
	_ja_amigo()
	var evento := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent
	assert_not_null(evento, "a oferta chega junto com a cascata da manhã")
	assert_eq(evento.estabelecimento, MOINHO, "quem pediu")
	assert_eq(evento.item_id, "trigo", "o dono pede o que ele consome")

func test_a_oferta_vem_em_lote_cheio() -> void:
	_ja_amigo()
	var evento := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent
	var def := _contratos.def_de(MOINHO)
	assert_eq(evento.qtd % def.entram, 0,
			"pedido tem que ser múltiplo do lote — sobra não seria beneficiável")
	assert_between(evento.qtd, def.entram * def.contrato_lotes_min,
			def.entram * def.contrato_lotes_max, "dentro do que o .tres autoriza")

func test_o_pagamento_vem_do_multiplicador_do_tres() -> void:
	_ja_amigo()
	var evento := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent
	var def := _contratos.def_de(MOINHO)
	var preco := _factory.get_item_catalog().get_def("trigo").preco_venda
	assert_eq(evento.pagamento, def.pagamento_de(evento.qtd, preco),
			"paga mais que o caixote — sem isso não haveria motivo para aceitar")

func test_um_contrato_ativo_por_estabelecimento() -> void:
	_ja_amigo()
	_dorme()
	var eventos := _dorme()
	assert_null(_primeiro(eventos, ContratoOferecidoEvent),
			"com oferta na mesa, o dono não pede de novo")

func test_a_oferta_traz_o_prazo_para_responder() -> void:
	_ja_amigo()
	var evento := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent
	assert_gt(evento.minuto_limite, _estado.relogio,
			"a oferta fica na mesa por um tempo, não some no mesmo minuto")

func test_o_sorteio_e_deterministico() -> void:
	_ja_amigo()
	var primeiro := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent

	before_each()
	_ja_amigo()
	var segundo := _primeiro(_dorme(), ContratoOferecidoEvent) as ContratoOferecidoEvent

	assert_eq(segundo.qtd, primeiro.qtd,
			"mesma semente, mesma sequência de encomendas — replay confiável")

func test_cada_dono_sorteia_o_seu() -> void:
	_ja_amigo(MOINHO)
	_ja_amigo(PADARIA)
	var pedidos: Array[String] = []
	for evento in _dorme():
		if evento is ContratoOferecidoEvent:
			pedidos.append((evento as ContratoOferecidoEvent).estabelecimento)
	assert_eq(pedidos, [MOINHO, PADARIA] as Array[String],
			"os dois encomendam, em ordem alfabética — a sequência de eventos é contrato")


# --- A resposta ---

func test_aceitar_vira_compromisso_com_prazo_de_cumprir() -> void:
	var oferta := _oferta_na_mesa()
	var limite_da_oferta := oferta.minuto_limite
	var evento := _primeiro(_responde(MOINHO, true), ContratoAceitoEvent) as ContratoAceitoEvent
	assert_not_null(evento, "o aceite tem evento próprio")
	assert_eq(evento.qtd, oferta.qtd, "o pedido não muda ao ser aceito")
	assert_ne(evento.minuto_limite, limite_da_oferta,
			"o prazo de responder deu lugar ao prazo de cumprir")
	var dias := _contratos.def_de(MOINHO).contrato_prazo_dias
	assert_eq(evento.minuto_limite, _estado.relogio + dias * TimeSystem.MINUTOS_POR_DIA,
			"o prazo conta a partir de agora, no relógio monotônico")

func test_recusar_e_gratis_e_limpa_a_mesa() -> void:
	_oferta_na_mesa()
	var evento := _primeiro(_responde(MOINHO, false), ContratoFalhouEvent) as ContratoFalhouEvent
	assert_not_null(evento, "recusar também é um fim de contrato")
	assert_eq(evento.motivo, ContratoFalhouEvent.MOTIVO_RECUSADO,
			"e o motivo diz que não doeu (PRINCIPIOS §6)")
	assert_false(_estado.tem_contrato(MOINHO), "a mesa fica livre")

func test_depois_de_recusar_o_dono_encomenda_de_novo() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, false)
	assert_not_null(_primeiro(_dorme(), ContratoOferecidoEvent),
			"dizer não não fecha a porta")

func test_responder_sem_oferta_e_recusado() -> void:
	var recusa := _recusa(_responde(MOINHO, true))
	assert_not_null(recusa, "não há o que aceitar")
	assert_eq(recusa.motivo, SistemaContratos.MOTIVO_SEM_CONTRATO, "e o motivo diz isso")

func test_aceitar_duas_vezes_e_recusado() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	var recusa := _recusa(_responde(MOINHO, true))
	assert_not_null(recusa, "o segundo aceite não passa")
	assert_eq(recusa.motivo, SistemaContratos.MOTIVO_CONTRATO_JA_ACEITO,
			"senão bastaria reclicar para esticar o prazo")

func test_responder_da_fazenda_e_recusado() -> void:
	_oferta_na_mesa()
	_volta_para_fazenda()
	var recusa := _recusa(_responde(MOINHO, true))
	assert_not_null(recusa, "a oferta está na mesa do dono, não na sua cozinha")
	assert_eq(recusa.motivo, SistemaLocais.MOTIVO_FORA_DO_LOCAL, "quem barra é o local")


# --- O cumprimento ---

func test_cumprir_no_prazo_paga_e_encerra() -> void:
	var oferta := _oferta_na_mesa()
	_responde(MOINHO, true)
	var eventos := _cumpre(MOINHO, oferta.item_id, oferta.qtd)
	var evento := _primeiro(eventos, ContratoCumpridoEvent) as ContratoCumpridoEvent
	assert_not_null(evento, "cumpriu")
	assert_eq(evento.pagamento, oferta.pagamento, "paga o que foi prometido na oferta")
	assert_false(_estado.tem_contrato(MOINHO),
			"contrato terminado não fica no state — o evento levou o que interessa")

func test_cumprir_gasta_o_item_da_mochila() -> void:
	var oferta := _oferta_na_mesa()
	_responde(MOINHO, true)
	_cumpre(MOINHO, oferta.item_id, oferta.qtd)
	assert_eq(_factory.get_inventory_state().get_player(JOGADOR).count(oferta.item_id), 0,
			"entregar é gastar — quem tira é o InventorySystem, antes")

func test_cumprir_o_que_nao_foi_aceito_e_recusado() -> void:
	var oferta := _oferta_na_mesa()
	var recusa := _recusa(_cumpre(MOINHO, oferta.item_id, oferta.qtd))
	assert_not_null(recusa, "oferta não é compromisso")
	assert_eq(recusa.motivo, SistemaContratos.MOTIVO_CONTRATO_NAO_ACEITO, "e o motivo diz isso")

func test_cumprir_com_item_errado_e_recusado() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	_da_item("rabanete", 10)
	var recusa := _recusa(_cumpre(MOINHO, "rabanete", 2))
	assert_not_null(recusa, "o dono pediu trigo")
	assert_eq(recusa.motivo, SistemaContratos.MOTIVO_ITEM_ERRADO, "e o motivo diz isso")

func test_cumprir_pela_metade_e_recusado() -> void:
	var oferta := _oferta_na_mesa()
	_responde(MOINHO, true)
	var recusa := _recusa(_cumpre(MOINHO, oferta.item_id, oferta.qtd - 1))
	assert_not_null(recusa, "contrato é tudo ou nada — meia entrega não conta")
	assert_eq(recusa.motivo, SistemaContratos.MOTIVO_QUANTIDADE_ERRADA, "e o motivo diz isso")

func test_pode_cumprir_responde_antes_de_a_acao_cobrar() -> void:
	var oferta := _oferta_na_mesa()
	assert_false(_contratos.pode_cumprir(MOINHO, oferta.item_id, oferta.qtd),
			"sem aceite, não dá — e game/ pergunta antes de despachar")
	_responde(MOINHO, true)
	assert_true(_contratos.pode_cumprir(MOINHO, oferta.item_id, oferta.qtd),
			"com aceite e a conta certa, dá")
	assert_false(_contratos.pode_cumprir(MOINHO, "rabanete", oferta.qtd),
			"item errado, não dá")

## A armadilha que justifica `pode_cumprir()`: a ação **é** uma
## `RemoveItemAction`, então o `InventorySystem` já tirou o item quando o
## contrato descobre que a conta está errada. Ninguém desfaz nada (é a regra da
## validação em cadeia), e por isso `game/` pergunta antes de despachar.
func test_cumprir_errado_custa_o_item_e_e_por_isso_que_game_pergunta_antes() -> void:
	var oferta := _oferta_na_mesa()
	var quanto := _factory.get_inventory_state().get_player(JOGADOR).count(oferta.item_id)
	assert_false(_contratos.pode_cumprir(MOINHO, oferta.item_id, oferta.qtd - 1),
			"a consulta responde não, antes de qualquer coisa sair da mochila")
	_cumpre(MOINHO, oferta.item_id, oferta.qtd - 1)
	assert_eq(_factory.get_inventory_state().get_player(JOGADOR).count(oferta.item_id),
			quanto - (oferta.qtd - 1),
			"quem despacha sem perguntar paga: o inventário roda antes do contrato")

func test_cumprir_da_fazenda_e_recusado() -> void:
	var oferta := _oferta_na_mesa()
	_responde(MOINHO, true)
	_volta_para_fazenda()
	var recusa := _recusa(_cumpre(MOINHO, oferta.item_id, oferta.qtd))
	assert_not_null(recusa, "cumprir é no prédio, nunca no caixote (PRINCIPIOS §3)")
	assert_eq(recusa.motivo, SistemaLocais.MOTIVO_FORA_DO_LOCAL, "quem barra é o local")


# --- O prazo ---

func test_oferta_ignorada_sai_da_mesa_sem_custo() -> void:
	_ja_amigo()
	_dorme()
	var eventos: Array[SimEvent] = []
	for _i in 4:
		eventos.append_array(_dorme())
	var fim := _primeiro(eventos, ContratoFalhouEvent) as ContratoFalhouEvent
	assert_not_null(fim, "oferta esquecida não fica na mesa para sempre")
	assert_eq(fim.motivo, ContratoFalhouEvent.MOTIVO_EXPIRADO,
			"ausência não pune: expirar é diferente de estourar")

func test_compromisso_estourado_tem_motivo_proprio() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	var dias := _contratos.def_de(MOINHO).contrato_prazo_dias
	var eventos: Array[SimEvent] = []
	for _i in dias + 1:
		eventos.append_array(_dorme())
	var fim := _primeiro(eventos, ContratoFalhouEvent) as ContratoFalhouEvent
	assert_not_null(fim, "o prazo venceu")
	assert_eq(fim.motivo, ContratoFalhouEvent.MOTIVO_ESTOURADO,
			"aceitou e não cumpriu — este é o que custa")
	assert_false(_estado.contrato(MOINHO).aceito,
			"o compromisso saiu da ficha; o que está lá é a oferta de hoje — a mesa"
			+ " livre é justamente o que deixa o dono pedir de novo")

func test_o_prazo_vence_pelo_relogio_e_nao_pela_virada_do_dia() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	var dias := _contratos.def_de(MOINHO).contrato_prazo_dias
	var eventos := _world.advance(dias * TimeSystem.MINUTOS_POR_DIA + 1)
	assert_not_null(_primeiro(eventos, ContratoFalhouEvent),
			"o minuto que passa é quem vence, sem ninguém dormir")

func test_o_vencimento_nao_se_repete() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	var dias := _contratos.def_de(MOINHO).contrato_prazo_dias
	_world.advance(dias * TimeSystem.MINUTOS_POR_DIA + 1)
	var depois := _world.advance(60)
	assert_null(_primeiro(depois, ContratoFalhouEvent),
			"contrato encerrado não falha de novo a cada minuto")

func test_minutos_para_vencer_conta_para_a_tela() -> void:
	_oferta_na_mesa()
	_responde(MOINHO, true)
	var antes := _contratos.minutos_para_vencer(MOINHO)
	_world.advance(60)
	assert_eq(_contratos.minutos_para_vencer(MOINHO), antes - 60,
			"é o número da contagem regressiva, e ele anda com o relógio")


# --- A constância chega por evento ---

func test_a_constancia_entra_pelo_evento_e_nao_pelo_state_alheio() -> void:
	var evento := RelacaoSubiuEvent.new()
	evento.estabelecimento = MOINHO
	evento.dias = 9
	evento.cota = 14
	_contratos.react(evento)
	assert_eq(_estado.dias(MOINHO), 9,
			"o sistema que pede guarda a cópia — nunca lê o EstadoCidade")
