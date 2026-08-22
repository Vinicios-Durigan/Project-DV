class_name PainelContratos
extends VBoxContainer

## As encomendas dos donos, jogáveis por botão: aceitar, recusar, cumprir.
##
## É a aba onde o degrau 2 da escada deixa de ser texto e vira decisão. A cidade
## beneficia sem risco nenhum — entrega, espera, busca. Aqui existe um prazo
## correndo na tela, e é ele que transforma "entregar" em "quando e quanto"
## (PRINCIPIOS §7). Se aceitar contrato não der frio na barriga, é para
## descobrir clicando aqui, antes de o artista desenhar a padaria.
##
## ---
##
## ## Padrão 2 — o clique vira ação, e pergunta antes
##
## `CumprirContratoAction` é uma `RemoveItemAction`: o `InventorySystem` tira o
## trigo da mochila **antes** de o contrato olhar o prazo. Despachar uma conta
## errada custaria o trigo — por isso o botão chama `pode_cumprir()` e obedece à
## resposta (receita 2, §4). Mesma exceção do plantio e da entrega.
##
## ## Padrão 3 — a tela sai do snapshot
##
## O pedido, o pagamento e o "já foi aceito?" saem de `snapshot()`, a mesma foto
## que o save grava. A contagem regressiva e o "cabe cumprir agora?" são
## perguntas de regra e saem do sistema.
##
## Nenhum `if` de regra mora aqui — nem o de quanto tempo falta. Quando a tela e
## a sim discordarem, quem errou é este arquivo.
##
## ## Os rótulos não são recriados
##
## O prazo anda a cada `MinuteTickedEvent`, que sai 60 vezes por segundo em ×60.
## Este painel reescreve `text` de meia dúzia de rótulos que já existem; remontar
## a aba a cada minuto é exatamente o sintoma que a receita 3 §4 avisa.

var _bridge: SimBridge
var _aviso: Label
var _ultimo_aviso: String = ""

## Qual dono o jogador acabou de abrir pelo mapa. Só destaque de tela.
var _destacado: String = ""

## id -> os nós daquele dono, para redesenhar sem remontar.
var _nomes: Dictionary = {}
var _pedidos: Dictionary = {}
var _prazos: Dictionary = {}
var _botoes: Dictionary = {}


func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_monta()
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza()


# --- Leitura: tudo o que aparece na tela vem daqui ---

## Os donos que a sim conhece. A lista não mora neste arquivo.
func estabelecimentos() -> Array[String]:
	var sistema := _sistema_contratos()
	return sistema.ids() if sistema != null else ([] as Array[String])

## Há encomenda na mesa deste dono, aceita ou não?
func tem_contrato(id: String) -> bool:
	return not _contrato(id).is_empty()

## O jogador já topou?
func aceito(id: String) -> bool:
	return bool(_contrato(id).get("aceito", false))

## O que ele pede, em unidades.
func qtd_pedida(id: String) -> int:
	return int(_contrato(id).get("qtd", 0))

## O que ele pede.
func item_pedido(id: String) -> String:
	return String(_contrato(id).get("item_id", ""))

## Quanto paga, já com o multiplicador do `.tres`.
func pagamento(id: String) -> int:
	return int(_contrato(id).get("pagamento", 0))

## Quanto falta para o prazo vencer, em minutos de jogo. É a sim que conta.
func minutos_restantes(id: String) -> int:
	var sistema := _sistema_contratos()
	return sistema.minutos_para_vencer(id) if sistema != null else 0

## O que a sim respondeu da última vez que ela disse não.
func ultimo_aviso() -> String:
	return _ultimo_aviso

func destacado() -> String:
	return _destacado

## Marca o dono que o jogador abriu pelo prédio no mapa.
func destaca(id: String) -> void:
	_destacado = id
	_mostra_destaque()


# --- Padrão 2: os botões ---

## Topa o compromisso. A partir daqui o prazo corre e falhar custa relação.
func aceita(id: String) -> void:
	_responde(id, true)

## Devolve a oferta. É de graça — e é justamente por ser de graça que aceitar é
## uma decisão, e não uma armadilha (PRINCIPIOS §6).
func recusa(id: String) -> void:
	_responde(id, false)

func _responde(id: String, topa: bool) -> void:
	var acao := ResponderContratoAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.aceita = topa
	_bridge.dispatch(acao)

## Entrega o que prometeu. Pergunta antes porque esta ação cobra o item antes de
## o contrato validar — a resposta é da sim, nunca um `if` daqui.
func cumpre(id: String) -> void:
	var sistema := _sistema_contratos()
	if sistema == null:
		return
	var item := item_pedido(id)
	var qtd := qtd_pedida(id)
	if not sistema.pode_cumprir(id, item, qtd):
		_mostra_aviso("a sim disse não: pode_cumprir(%s, %s, %d)" % [id, item, qtd])
		return

	var acao := CumprirContratoAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.item_id = item
	acao.qtd = qtd
	_bridge.dispatch(acao)

## Truque de dev: o que o pedido pede, na mão, para testar o prazo sem esperar
## a colheita. É uma `AddItemAction` de verdade — nenhum atalho mexe no state
## por fora.
func da_o_pedido(id: String) -> void:
	var qtd := qtd_pedida(id)
	if qtd <= 0:
		return
	var acao := AddItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_pedido(id)
	acao.qtd = qtd
	_bridge.dispatch(acao)


# --- Montagem ---

func _monta() -> void:
	add_child(_titulo("Contratos"))
	for id in estabelecimentos():
		add_child(_grupo_do_dono(id))

	_aviso = Label.new()
	_aviso.theme_type_variation = &"Micro"
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)
	_mostra_destaque()

func _grupo_do_dono(id: String) -> Control:
	var sistema := _sistema_contratos()
	var def := sistema.def_de(id)

	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"

	var nome := Label.new()
	nome.text = def.nome
	nome.theme_type_variation = &"Micro"
	caixa.add_child(nome)
	_nomes[id] = nome

	var pedido := Label.new()
	pedido.theme_type_variation = &"Dado"
	pedido.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(pedido)
	_pedidos[id] = pedido

	var prazo := Label.new()
	prazo.theme_type_variation = &"Rotulo"
	caixa.add_child(prazo)
	_prazos[id] = prazo

	var botoes := HFlowContainer.new()
	caixa.add_child(botoes)
	var meus: Dictionary = {}
	meus["aceitar"] = _botao(botoes, "Aceitar", aceita.bind(id))
	(meus["aceitar"] as Button).theme_type_variation = &"BotaoPrimario"
	meus["recusar"] = _botao(botoes, "Recusar", recusa.bind(id))
	meus["cumprir"] = _botao(botoes, "Cumprir", cumpre.bind(id))
	meus["truque"] = _botao(botoes, "+pedido", da_o_pedido.bind(id))
	(meus["truque"] as Button).theme_type_variation = &"Truque"
	_botoes[id] = meus
	return caixa

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label

func _botao(pai: Node, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao


# --- Evento vira tela ---

## O minuto que passa só mexe na contagem regressiva. Remontar a aba 60 vezes
## por segundo é o que a receita 3 §4 proíbe.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		_mostra_prazos()
		return
	if event is ActionRejectedEvent:
		var recusada := event as ActionRejectedEvent
		if recusada.acao == "ResponderContratoAction" \
				or recusada.acao == "CumprirContratoAction":
			_mostra_aviso("a sim recusou %s: %s" % [recusada.acao, recusada.motivo])
	if event is ContratoCumpridoEvent:
		var feito := event as ContratoCumpridoEvent
		_mostra_aviso("%s pagou %dg pelo contrato" % [_nome_de(feito.estabelecimento),
				feito.pagamento])
	if event is ContratoFalhouEvent:
		var fim := event as ContratoFalhouEvent
		_mostra_aviso("contrato de %s: %s" % [_nome_de(fim.estabelecimento), fim.motivo])
	_atualiza()

func _atualiza() -> void:
	if _bridge == null:
		return
	for id in estabelecimentos():
		_mostra_pedido(id)
		_mostra_botoes(id)
	_mostra_prazos()

func _mostra_pedido(id: String) -> void:
	var label := _pedidos[id] as Label
	if not tem_contrato(id):
		label.text = "sem encomenda hoje"
		return
	label.text = "%d %s → %dg%s" % [qtd_pedida(id), _nome_do_item(item_pedido(id)),
			pagamento(id), " · aceito" if aceito(id) else ""]

## A contagem regressiva. Enquanto a oferta está na mesa, o prazo é o de
## **responder**; depois de aceita, o de **cumprir** — o mesmo número, e é a sim
## que sabe qual dos dois é.
func _mostra_prazos() -> void:
	for id: String in _prazos:
		var label := _prazos[id] as Label
		if not tem_contrato(id):
			label.text = ""
			continue
		var quanto := PainelCidade.texto_do_tempo(minutos_restantes(id))
		label.text = "%s para %s" % [quanto, "cumprir" if aceito(id) else "responder"]
		label.theme_type_variation = &"Recusa" if aceito(id) and minutos_restantes(id) \
				< TimeSystem.MINUTOS_POR_DIA else &"Rotulo"

## Botão que não tem o que fazer some da tela. Isso não é regra de jogo virando
## `if` daqui: um "Aceitar" sem oferta na mesa não é uma decisão difícil, é um
## botão sem sentido. Quem recusa continua sendo a sim — o toast prova.
func _mostra_botoes(id: String) -> void:
	var meus: Dictionary = _botoes[id]
	var tem := tem_contrato(id)
	(meus["aceitar"] as Button).visible = tem and not aceito(id)
	(meus["recusar"] as Button).visible = tem and not aceito(id)
	(meus["cumprir"] as Button).visible = tem and aceito(id)
	(meus["truque"] as Button).visible = tem

func _mostra_destaque() -> void:
	for id: String in _nomes:
		var rotulo := _nomes[id] as Label
		var aqui := id == _destacado
		rotulo.theme_type_variation = &"Rotulo" if aqui else &"Micro"
		rotulo.text = "▸ %s" % _nome_de(id) if aqui else _nome_de(id)

func _mostra_aviso(texto: String) -> void:
	_ultimo_aviso = texto
	if _aviso != null:
		_aviso.text = texto


# --- A sim, pelos dois caminhos de sempre ---

## Padrão 3: o estado desenhado sai da mesma foto que o save grava.
func _contrato(id: String) -> Dictionary:
	if _bridge == null:
		return {}
	var bloco: Dictionary = _bridge.get_world().snapshot().get(SimFactory.CHAVE_CONTRATOS, {})
	var contratos: Dictionary = bloco.get("contratos", {})
	var bruto: Variant = contratos.get(id, {})
	return bruto if bruto is Dictionary else {}

## As perguntas de regra vão ao sistema, como `pode_plantar`.
func _sistema_contratos() -> SistemaContratos:
	if _bridge == null:
		return null
	for sistema in _bridge.get_world().get_systems():
		if sistema is SistemaContratos:
			return sistema
	return null

func _nome_de(id: String) -> String:
	var sistema := _sistema_contratos()
	var def := sistema.def_de(id) if sistema != null else null
	return def.nome if def != null and not def.nome.is_empty() else id

func _nome_do_item(item_id: String) -> String:
	if _bridge == null:
		return item_id
	var def := _bridge.get_item_catalog().get_def(item_id)
	return def.nome if def != null and not def.nome.is_empty() else item_id
