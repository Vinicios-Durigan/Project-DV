extends GutTest

## O degrau do beneficiamento, ponta a ponta: entrega, espera, busca.
##
## ## As duas metades da transação caem em ações diferentes
##
## `EntregarAction` **é** uma `RemoveItemAction` e `RetirarAction` **é** uma
## `AddMoneyAction`. Não é enfeite: quem é dono do item e do dinheiro é o
## `InventorySystem`, que roda antes da cidade na ordem fixa. Entregando o item
## por uma ação e cobrando por outra, nenhum sistema existente precisou ser
## editado — e as duas recusas que a wave prometeu (`item_insuficiente` e
## `dinheiro_insuficiente`) saem de graça, de quem sabe responder por elas.
##
## A ficção fecha junto: entrega o trigo, paga o moleiro quando busca a farinha.
##
## ## O relógio é monotônico
##
## A cidade copia `dia × 1440 + minuto` do `MinuteTickedEvent` para o próprio
## state e conclui pelo número, nunca pela virada do dia. Dormir não adianta
## prazo, e encomenda de 4 horas conclui no meio da tarde.
##
## ## Entregar cobra antes de a cidade validar
##
## Mesma exceção do `PlantCropAction` (receita 2, §4): o `InventorySystem` tira
## o trigo antes de a cidade olhar a cota. Por isso existe `pode_entregar()` —
## e é a resposta dela que `game/` consulta, nunca um `if` próprio.

const MOINHO: String = "moinho"
const PADARIA: String = "padaria"
const JOGADOR: int = SimFactory.PLAYER_PADRAO

var _factory: SimFactory
var _world: SimWorld
var _cidade: SistemaCidade
var _estado: EstadoCidade


func before_each() -> void:
	_factory = SimFactory.new()
	_world = _factory.build()
	_estado = _factory.get_estado_cidade()
	for system in _world.get_systems():
		if system is SistemaCidade:
			_cidade = system
	_vai_para_cidade()

func _vai_para_cidade() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.CIDADE
	_world.handle(acao)

func _da_item(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.item_id = item_id
	acao.qtd = qtd
	_world.handle(acao)

func _entrega(estabelecimento: String, item_id: String, qtd: int) -> Array[SimEvent]:
	var acao := EntregarAction.new()
	acao.player_id = JOGADOR
	acao.estabelecimento = estabelecimento
	acao.item_id = item_id
	acao.qtd = qtd
	return _world.handle(acao)

## Retirar cobra a taxa combinada: o valor sai da consulta da sim, nunca de uma
## conta feita aqui.
func _retira(estabelecimento: String) -> Array[SimEvent]:
	var acao := RetirarAction.new()
	acao.player_id = JOGADOR
	acao.estabelecimento = estabelecimento
	acao.valor = -_cidade.taxa_a_pagar(estabelecimento)
	return _world.handle(acao)

func _dorme() -> Array[SimEvent]:
	return _world.handle(SleepAction.new())

func _mochila() -> InventoryState.PlayerInventory:
	return _factory.get_inventory_state().get_player(JOGADOR)

func _dinheiro() -> int:
	return _mochila().dinheiro

func _evento(eventos: Array[SimEvent], tipo: Variant) -> SimEvent:
	for evento in eventos:
		if is_instance_of(evento, tipo):
			return evento
	return null

func _motivo(eventos: Array[SimEvent]) -> String:
	var recusa := _evento(eventos, ActionRejectedEvent) as ActionRejectedEvent
	return recusa.motivo if recusa != null else ""


# --- Montagem ---

func test_a_cidade_entra_entre_o_farm_e_o_time() -> void:
	var systems := _world.get_systems()
	assert_eq(systems.size(), 10, "os 10 sistemas do slice")
	assert_true(systems[7] is SistemaCidade,
		"a cidade conclui depois de a colheita da manhã já estar na mochila")
	assert_true(systems[9] is TimeSystem, "o calendário continua virando por último")

func test_o_bloco_cidade_entra_no_fim_do_save() -> void:
	assert_eq(_world.state_keys()[5], SimFactory.CHAVE_CIDADE,
		"bloco novo entra no fim — save antigo carrega sem migração")
	assert_same(_world.get_state(SimFactory.CHAVE_CIDADE), _estado)

func test_a_cidade_conhece_os_dois_estabelecimentos() -> void:
	assert_eq(_cidade.ids(), [MOINHO, PADARIA])
	assert_eq(_cidade.def_de(MOINHO).item_entrada, "trigo")
	assert_null(_cidade.def_de("ferreiro"), "estabelecimento que não existe não tem def")


# --- Só se age onde se está ---

func test_entregar_na_fazenda_e_recusado() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.FAZENDA
	_world.handle(acao)
	_da_item("trigo", 2)

	var eventos := _entrega(MOINHO, "trigo", 2)
	assert_eq(_motivo(eventos), SistemaLocais.MOTIVO_FORA_DO_LOCAL)
	assert_eq(_mochila().count("trigo"), 2, "recusado antes do Inventory: o trigo não saiu")
	assert_eq(_estado.encomendas(MOINHO).size(), 0)

func test_retirar_na_fazenda_e_recusado() -> void:
	var acao := ViajarAction.new()
	acao.destino = EstadoLocais.FAZENDA
	_world.handle(acao)
	assert_eq(_motivo(_retira(MOINHO)), SistemaLocais.MOTIVO_FORA_DO_LOCAL)


# --- Entregar ---

func test_entregar_tira_o_trigo_agenda_e_avisa() -> void:
	_da_item("trigo", 6)
	var eventos := _entrega(MOINHO, "trigo", 6)

	var aceita := _evento(eventos, EntregaAceitaEvent) as EntregaAceitaEvent
	assert_not_null(aceita, "mudou estado, tem que sair evento")
	assert_eq(aceita.estabelecimento, MOINHO)
	assert_eq(aceita.item_entrada, "trigo")
	assert_eq(aceita.qtd_entrada, 6)
	assert_eq(aceita.item_saida, "farinha")
	assert_eq(aceita.qtd_saida, 3, "6 trigo de 2 em 2 viram 3 farinhas")
	assert_eq(aceita.taxa, 30, "5 por trigo, paga na retirada")
	assert_eq(aceita.minuto_conclusao, _estado.relogio + 240)

	assert_eq(_mochila().count("trigo"), 0, "o trigo saiu da mochila")
	assert_eq(_dinheiro(), 500, "a taxa só é cobrada quando ele vier buscar")
	assert_eq(_estado.cota_usada(MOINHO), 6)

func test_entregar_sem_trigo_e_recusado_pelo_inventario() -> void:
	var eventos := _entrega(MOINHO, "trigo", 2)
	assert_eq(_motivo(eventos), InventorySystem.MOTIVO_ITEM_INSUFICIENTE)
	assert_eq(_estado.encomendas(MOINHO).size(), 0,
		"ação recusada lá atrás não chega na cidade")

func test_entregar_o_item_errado_e_recusado() -> void:
	_da_item("rabanete", 2)
	assert_eq(_motivo(_entrega(MOINHO, "rabanete", 2)),
		SistemaCidade.MOTIVO_ITEM_ERRADO, "moinho não mói rabanete")

func test_entregar_num_estabelecimento_que_nao_existe_e_recusado() -> void:
	_da_item("trigo", 2)
	assert_eq(_motivo(_entrega("ferreiro", "trigo", 2)),
		SistemaCidade.MOTIVO_ESTABELECIMENTO_DESCONHECIDO)

func test_lote_incompleto_e_recusado() -> void:
	_da_item("trigo", 3)
	assert_eq(_motivo(_entrega(MOINHO, "trigo", 3)), SistemaCidade.MOTIVO_LOTE_INCOMPLETO,
		"o moinho mói de 2 em 2 — o terceiro trigo sumiria sem virar nada")

func test_cota_estourada_e_recusada() -> void:
	_da_item("trigo", 20)
	_entrega(MOINHO, "trigo", 6)
	assert_eq(_motivo(_entrega(MOINHO, "trigo", 2)), SistemaCidade.MOTIVO_COTA_ESTOURADA,
		"cota inicial do moinho é 6 — o atrito é o limite (PRINCIPIOS §7)")

func test_pode_entregar_responde_antes_de_o_trigo_ser_cobrado() -> void:
	_da_item("trigo", 8)
	assert_true(_cidade.pode_entregar(MOINHO, "trigo", 6))
	assert_false(_cidade.pode_entregar(MOINHO, "trigo", 3), "lote incompleto")
	assert_false(_cidade.pode_entregar(MOINHO, "trigo", 8), "estoura a cota de 6")
	assert_false(_cidade.pode_entregar(MOINHO, "rabanete", 2), "item errado")
	assert_false(_cidade.pode_entregar("ferreiro", "trigo", 2), "não existe")
	assert_eq(_mochila().count("trigo"), 8, "perguntar não cobra nada")

## O buraco herdado do `PlantCropAction`: o Inventory cobra antes de a cidade
## validar. Ele está documentado, testado e é por isso que `pode_entregar`
## existe — quem despacha sem perguntar paga a conta.
func test_recusa_da_cidade_ja_custou_o_trigo() -> void:
	_da_item("trigo", 3)
	_entrega(MOINHO, "trigo", 3)
	assert_eq(_mochila().count("trigo"), 0,
		"validação em cadeia não desfaz nada — `game/` consulta pode_entregar antes")


# --- Constância ---

func test_entregar_credita_um_dia_e_avisa() -> void:
	_da_item("trigo", 6)
	var eventos := _entrega(MOINHO, "trigo", 2)

	var subiu := _evento(eventos, RelacaoSubiuEvent) as RelacaoSubiuEvent
	assert_not_null(subiu)
	assert_eq(subiu.estabelecimento, MOINHO)
	assert_eq(subiu.dias, 1)
	assert_eq(subiu.cota, 6, "ainda no primeiro degrau")

func test_duas_entregas_no_mesmo_dia_creditam_uma() -> void:
	_da_item("trigo", 6)
	_entrega(MOINHO, "trigo", 2)
	var eventos := _entrega(MOINHO, "trigo", 2)
	assert_null(_evento(eventos, RelacaoSubiuEvent),
		"volume não compra relação — constância compra (PRINCIPIOS §6)")
	assert_eq(_estado.dias_com_entrega(MOINHO), 1)

func test_a_cota_de_hoje_e_a_que_ele_tinha_ao_chegar() -> void:
	_da_item("trigo", 40)
	for dia in 3:
		_entrega(MOINHO, "trigo", 2)
		_retira(MOINHO)
		_dorme()
	assert_eq(_estado.dias_com_entrega(MOINHO), 3)
	assert_eq(_cidade.cota_de(MOINHO), 10, "cruzou o limiar de 3 dias: 6 + 4")


# --- A escada, respondida pela sim ---
#
# São perguntas de regra, e por isso vivem aqui e não na tela: a aba de amizade
# só desenha o que estas funções respondem. Um `if` de degrau em `game/` é bug
# de arquitetura, mesmo que a tela fique certa.

func test_a_ficha_da_amizade_comeca_zerada() -> void:
	assert_eq(_cidade.dias_de_relacao(MOINHO), 0)
	assert_eq(_cidade.degrau_de(MOINHO), 0)
	assert_eq(_cidade.degraus_de(MOINHO), 4, "a escada dos .tres do slice")
	assert_eq(_cidade.limiares_de(MOINHO), [3, 7, 14, 24] as Array[int])
	assert_eq(_cidade.dias_para_o_proximo_degrau(MOINHO), 3)
	assert_false(_cidade.cota_no_teto(MOINHO), "no começo sobra prédio")

func test_a_escada_anda_com_a_constancia() -> void:
	_da_item("trigo", 40)
	for dia in 3:
		_entrega(MOINHO, "trigo", 2)
		_retira(MOINHO)
		_dorme()

	assert_eq(_cidade.degrau_de(MOINHO), 1, "cruzou o limiar de 3 dias")
	assert_eq(_cidade.dias_para_o_proximo_degrau(MOINHO), 4, "agora a mira é o 7")
	assert_eq(_cidade.ganho_do_proximo_degrau(MOINHO), 4)

func test_o_contrato_e_um_degrau_da_escada_e_a_sim_diz_quanto_falta() -> void:
	assert_eq(_cidade.degraus_para_o_contrato(MOINHO), 1,
		"o dono só encomenda a quem apareceu (PRINCIPIOS §3)")
	assert_false(_cidade.encomenda_liberada(MOINHO))

	_da_item("trigo", 40)
	for dia in 3:
		_entrega(MOINHO, "trigo", 2)
		_retira(MOINHO)
		_dorme()

	assert_eq(_cidade.degraus_para_o_contrato(MOINHO), 0)
	assert_true(_cidade.encomenda_liberada(MOINHO))

func test_estabelecimento_desconhecido_responde_zerado_e_nao_quebra() -> void:
	assert_eq(_cidade.degrau_de("ferreiro"), 0)
	assert_eq(_cidade.degraus_de("ferreiro"), 0)
	assert_eq(_cidade.limiares_de("ferreiro"), [] as Array[int])
	assert_eq(_cidade.dias_para_o_proximo_degrau("ferreiro"), -1)
	assert_eq(_cidade.capacidade_de("ferreiro"), 0)
	assert_eq(_cidade.degraus_para_o_contrato("ferreiro"), -1,
		"-1 é 'não há contrato aqui', diferente de 'falta subir'")


# --- O relógio conclui ---

func test_encomenda_conclui_quando_o_minuto_chega() -> void:
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)

	var quase := _world.advance(239)
	assert_null(_evento(quase, BeneficiamentoProntoEvent), "faltou um minuto")

	var pronto := _evento(_world.advance(1), BeneficiamentoProntoEvent) as BeneficiamentoProntoEvent
	assert_not_null(pronto, "4 horas de jogo depois")
	assert_eq(pronto.estabelecimento, MOINHO)
	assert_eq(pronto.item_id, "farinha")
	assert_eq(pronto.qtd, 1)

func test_encomenda_pronta_nao_avisa_de_novo_a_cada_minuto() -> void:
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	_world.advance(240)
	assert_null(_evento(_world.advance(60), BeneficiamentoProntoEvent),
		"o aviso sai uma vez — não é um alarme")

func test_dormir_nao_adianta_o_prazo() -> void:
	_da_item("trigo", 2)
	_world.advance(240)          # 10:00
	_dorme()                     # acorda no dia 2 às 06:00
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_estado.relogio, 2 * TimeSystem.MINUTOS_POR_DIA + TimeSystem.MINUTO_ACORDAR,
		"o relógio da cidade acompanha a virada, senão dormir daria beneficiamento de graça")
	assert_null(_evento(_world.advance(1), BeneficiamentoProntoEvent),
		"a encomenda foi agendada a partir de agora, não de ontem")

## Dormir salta o relógio sem passar minuto nenhum. A cidade acerta o ponteiro
## na virada e conclui ali mesmo — sem esperar o primeiro tick da manhã.
func test_a_noite_conta_para_a_encomenda() -> void:
	_da_item("trigo", 2)
	_world.advance(900)          # 21:00
	_entrega(MOINHO, "trigo", 2) # vence 01:00, ainda de madrugada
	assert_not_null(_evento(_dorme(), BeneficiamentoProntoEvent),
		"dormir empurra o relógio e a encomenda avança junto")
	assert_eq(_mochila().count("farinha"), 0, "pronta, mas ainda no moinho: falta buscar")

## A meia-noite não pode fazer o relógio da cidade andar para trás: `dia` só
## vira ao dormir, então `dia × 1440 + minuto` cru daria um número menor às
## 00:00 do que às 23:59 — e a encomenda da madrugada ficaria pronta cedo.
func test_a_meia_noite_nao_adianta_encomenda() -> void:
	_da_item("trigo", 2)
	_world.advance(1020)         # 23:00
	_entrega(MOINHO, "trigo", 2) # vence 03:00 — depois do colapso das 02:00
	var noite := _world.advance(120)  # atravessa a meia-noite até 01:00
	assert_null(_evento(noite, BeneficiamentoProntoEvent),
		"passou da meia-noite, não do prazo")
	assert_eq(_estado.relogio, EstadoCidade.minuto_monotonico(1, 60))

func test_duas_entregas_na_mesma_noite_creditam_um_dia_so() -> void:
	_da_item("trigo", 4)
	_world.advance(1020)         # 23:00
	_entrega(MOINHO, "trigo", 2)
	_world.advance(120)          # 01:00, ainda o mesmo dia útil
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_estado.dias_com_entrega(MOINHO), 1,
		"o dia útil vai até as 02:00 — a madrugada é a mesma noite")


# --- Retirar ---

func test_retirar_paga_a_taxa_e_devolve_o_produto() -> void:
	_da_item("trigo", 6)
	_entrega(MOINHO, "trigo", 6)
	_world.advance(240)

	assert_eq(_cidade.taxa_a_pagar(MOINHO), 30)
	var eventos := _retira(MOINHO)

	var feita := _evento(eventos, RetiradaFeitaEvent) as RetiradaFeitaEvent
	assert_not_null(feita)
	assert_eq(feita.estabelecimento, MOINHO)
	assert_eq(feita.item_id, "farinha")
	assert_eq(feita.qtd, 3)
	assert_eq(feita.taxa_paga, 30)

	assert_eq(_mochila().count("farinha"), 3, "é um ItemGrantedEvent: o inventário reage")
	assert_eq(_dinheiro(), 470, "500 − 30 de taxa")
	assert_eq(_estado.cota_usada(MOINHO), 0, "retirou, liberou a cota")

func test_retirar_sem_nada_pronto_e_recusado_sem_cobrar() -> void:
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	assert_eq(_cidade.taxa_a_pagar(MOINHO), 0, "não se paga pelo que ainda está no moinho")
	assert_eq(_motivo(_retira(MOINHO)), SistemaCidade.MOTIVO_NADA_PRONTO)
	assert_eq(_dinheiro(), 500)

func test_retirar_sem_dinheiro_e_recusado_pelo_inventario() -> void:
	_da_item("trigo", 6)
	_entrega(MOINHO, "trigo", 6)
	_world.advance(240)

	var gasto := AddMoneyAction.new()
	gasto.valor = -_dinheiro()
	_world.handle(gasto)

	assert_eq(_motivo(_retira(MOINHO)), InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE)
	assert_eq(_estado.prontas(MOINHO).size(), 1,
		"a farinha continua presa no moinho, ocupando cota — é o atrito funcionando")

func test_retirar_com_a_taxa_errada_e_recusado() -> void:
	_da_item("trigo", 2)
	_entrega(MOINHO, "trigo", 2)
	_world.advance(240)

	var acao := RetirarAction.new()
	acao.estabelecimento = MOINHO
	acao.valor = -1
	assert_eq(_motivo(_world.handle(acao)), SistemaCidade.MOTIVO_TAXA_INCORRETA,
		"`game/` inventando o preço tem que fazer barulho, não passar")

func test_retirar_leva_so_o_que_esta_pronto() -> void:
	_da_item("trigo", 8)
	_entrega(MOINHO, "trigo", 2)
	_world.advance(120)
	_entrega(MOINHO, "trigo", 4)
	_world.advance(120)

	_retira(MOINHO)
	assert_eq(_mochila().count("farinha"), 1, "só o primeiro lote ficou pronto")
	assert_eq(_estado.cota_usada(MOINHO), 4, "o segundo continua no moinho")


# --- A cadeia inteira ---

func test_trigo_vira_pao_passando_pelos_dois_estabelecimentos() -> void:
	_da_item("trigo", 4)
	_entrega(MOINHO, "trigo", 4)
	_world.advance(240)
	_retira(MOINHO)
	assert_eq(_mochila().count("farinha"), 2)

	_entrega(PADARIA, "farinha", 2)
	_world.advance(480)
	_retira(PADARIA)

	assert_eq(_mochila().count("pao"), 1, "a padaria come a saída do moinho")
	assert_eq(_dinheiro(), 500 - 20 - 20, "20 de moagem + 20 de fornada")


# --- Save ---

func test_o_estado_da_cidade_sobrevive_ao_save() -> void:
	_da_item("trigo", 6)
	_entrega(MOINHO, "trigo", 6)
	_world.advance(240)

	var snapshot := _world.snapshot()
	assert_true(snapshot.has(SimFactory.CHAVE_CIDADE), "o bloco está no save")

	var outro := SimFactory.new()
	var mundo := outro.build()
	mundo.restore(snapshot)

	assert_eq(outro.get_estado_cidade().prontas(MOINHO).size(), 1)
	assert_eq(outro.get_estado_cidade().dias_com_entrega(MOINHO), 1)
	assert_eq(outro.get_estado_cidade().relogio, _estado.relogio)

func test_save_antigo_sem_o_bloco_cidade_carrega() -> void:
	var antigo := _world.snapshot()
	antigo.erase(SimFactory.CHAVE_CIDADE)
	_world.restore(antigo)
	assert_eq(_estado.ids(), [],
		"campo ausente cai no default — é assim que bloco novo entra sem migração")
	assert_eq(_world.snapshot()[SimWorld.CHAVE_VERSAO], SimWorld.SAVE_VERSION,
		"a cidade não fez a versão subir: quem a sobe é quem remove ou renomeia campo")
