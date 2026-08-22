class_name StatusPanel
extends VBoxContainer

## Situação, tempo, truques e o vaivém mochila↔caixote. É o painel que deixa a
## sim inteira ser jogada sem tocar no teclado.
##
## Três regras valem aqui, e é por elas que este painel não vira um jogo
## paralelo:
##
## 1. **Tudo o que aparece sai do `snapshot()`**, nunca do state vivo. O painel
##    mostra exatamente o que iria para o arquivo de save — o inspetor de save
##    sai de graça, e campo que não aparece aqui é campo que não está sendo
##    salvo.
## 2. **Todo truque é uma ação formal.** "+500 moedas" é `AddMoneyAction`, e a
##    semente de graça é `AddItemAction`. Nenhum atalho mexe no state por fora:
##    se o truque quebra o jogo, quem estava quebrada era a mecânica.
## 3. **Zero `if` de regra.** O botão manda; a sim aceita ou rejeita, e o diário
##    conta.

## Largura mínima da coluna, em pixels.
const LARGURA: float = 320.0

## Quanto cada truque dá de uma vez.
const TRUQUE_MOEDAS: int = 500
const TRUQUE_SEMENTES: int = 5

## Quanto os botões de adiantar empurram o relógio, em minutos de jogo.
const PULO_CURTO: int = 10
const PULO_LONGO: int = 60

var _bridge: SimBridge
var _label_relogio: Label
var _label_dinheiro: Label
var _label_velocidade: Label
var _label_save: Label
var _label_mochila: Label
var _label_caixote: Label
var _lista_mochila: VBoxContainer
var _lista_caixote: VBoxContainer
var _loja: HFlowContainer

func _ready() -> void:
	custom_minimum_size = Vector2(LARGURA, 0)
	_monta_situacao()
	_monta_tempo()
	_monta_truques()
	_monta_loja()
	_monta_save()
	_monta_listas()

func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_bridge.time_scale_changed.connect(_on_time_scale_changed)
	_escuta_o_gateway()
	_preenche_loja()
	_atualiza()
	_mostra_velocidade(_bridge.get_time_scale())

# --- Montagem ---

func _monta_situacao() -> void:
	add_child(_titulo("Situação"))
	_label_relogio = Label.new()
	add_child(_label_relogio)
	_label_dinheiro = Label.new()
	add_child(_label_dinheiro)
	_label_velocidade = Label.new()
	add_child(_label_velocidade)

func _monta_tempo() -> void:
	add_child(_titulo("Tempo"))
	var linha := HFlowContainer.new()
	add_child(linha)
	_botao(linha, "+%d min" % PULO_CURTO, _adianta.bind(PULO_CURTO))
	_botao(linha, "+%d h" % (PULO_LONGO / 60), _adianta.bind(PULO_LONGO))
	_botao(linha, "Dormir", _dorme)
	_botao(linha, "Velocidade", _troca_velocidade)
	_botao(linha, "Pausar", _alterna_pausa)

## Truques são ações formais, não desvios: entram pelo mesmo cano de qualquer
## clique.
func _monta_truques() -> void:
	add_child(_titulo("Truques"))
	var linha := HFlowContainer.new()
	add_child(linha)
	_botao(linha, "+%d moedas" % TRUQUE_MOEDAS, _da_dinheiro)
	_botao(linha, "+%d de cada semente" % TRUQUE_SEMENTES, _da_sementes)

func _monta_loja() -> void:
	add_child(_titulo("Loja de sementes"))
	_loja = HFlowContainer.new()
	add_child(_loja)

func _monta_save() -> void:
	add_child(_titulo("Save"))
	var linha := HFlowContainer.new()
	add_child(linha)
	_botao(linha, "Salvar agora", _salva)
	_botao(linha, "Carregar", _carrega)
	_label_save = Label.new()
	_label_save.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label_save)

func _monta_listas() -> void:
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(rolagem)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(coluna)

	_label_mochila = _titulo("Mochila")
	coluna.add_child(_label_mochila)
	_lista_mochila = VBoxContainer.new()
	coluna.add_child(_lista_mochila)

	_label_caixote = _titulo("Caixote")
	coluna.add_child(_label_caixote)
	_lista_caixote = VBoxContainer.new()
	coluna.add_child(_lista_caixote)

## O catálogo é leitura livre: o preço na etiqueta vem do `CropDef`, e quem
## cobra continua sendo o `InventorySystem`.
func _preenche_loja() -> void:
	for crop_id in _bridge.get_crop_catalog().ids():
		var def := _bridge.get_crop_catalog().get_def(crop_id)
		_botao(_loja, "%s (%d)" % [def.nome, def.preco_semente], _compra.bind(crop_id))

## O gateway avisa o que fez com o disco; o painel só repete para o time.
func _escuta_o_gateway() -> void:
	var gateway := _save_gateway()
	if gateway == null:
		_label_save.text = "sem SaveGateway nesta cena"
		return
	gateway.game_saved.connect(_on_game_saved)
	gateway.game_loaded.connect(_on_game_loaded)
	gateway.save_rejected.connect(_on_save_rejected)
	# o boot já aconteceu quando o fio chega aqui: o gateway é o primeiro filho
	# da bridge e carrega o slot antes de a UI existir. Por isso o rótulo começa
	# com o slot, e não com o resultado do carregamento.
	_label_save.text = "slot %s" % gateway.slot

# --- Botões viram ações ---

func _adianta(minutos: int) -> void:
	_bridge.advance(minutos)

func _dorme() -> void:
	_bridge.dispatch(SleepAction.new())

func _troca_velocidade() -> void:
	_bridge.cycle_time_scale()

func _da_dinheiro() -> void:
	var acao := AddMoneyAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.valor = TRUQUE_MOEDAS
	_bridge.dispatch(acao)

func _da_sementes() -> void:
	for crop_id in _bridge.get_crop_catalog().ids():
		var def := _bridge.get_crop_catalog().get_def(crop_id)
		var acao := AddItemAction.new()
		acao.player_id = SimFactory.PLAYER_PADRAO
		acao.item_id = def.item_semente_id()
		acao.qtd = TRUQUE_SEMENTES
		_bridge.dispatch(acao)

func _compra(crop_id: String) -> void:
	var acao := BuySeedAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.crop_id = crop_id
	acao.qtd = 1
	_bridge.dispatch(acao)

## Manda o stack inteiro para o caixote. `ShipItemAction` é uma
## `RemoveItemAction`: o inventário tira e o caixote guarda, nessa ordem, sem
## ninguém desfazer nada.
func _manda_pro_caixote(item_id: String, qtd: int) -> void:
	var acao := ShipItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

func _tira_do_caixote(item_id: String, qtd: int) -> void:
	var acao := WithdrawItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

## Pausa é assunto de apresentação: o relógio de parede para e a sim não fica
## sabendo. Retomar volta em ×1, que é a velocidade de jogar.
func _alterna_pausa() -> void:
	_bridge.set_time_scale(0.0 if _bridge.get_time_scale() > 0.0 else 1.0)

func _salva() -> void:
	var gateway := _save_gateway()
	if gateway == null:
		return
	if not gateway.save():
		_label_save.text = "o disco recusou"

## Carregar é reabrir a cena: o `SaveGateway` carrega o slot no boot, e é esse o
## caminho que o jogador percorre de verdade. Um "load" só do playground seria
## um caminho que ninguém mais usa — e que ninguém testaria.
func _carrega() -> void:
	get_tree().reload_current_scene()

## O gateway é irmão nesta cena, não um serviço global: disco é assunto de
## apresentação e mora ao lado da bridge, nunca dentro da sim.
func _save_gateway() -> SaveGateway:
	if _bridge == null:
		return null
	return _bridge.get_node_or_null("SaveGateway") as SaveGateway

# --- Evento vira texto ---

## Minuto que passa mexe no relógio e em nada mais. Redesenhar mochila e caixote
## 60 vezes por segundo em ×60 só gastaria botão.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		_mostra_relogio(_bridge.get_world().snapshot().get(SimFactory.CHAVE_TIME, {}))
		return
	_atualiza()

func _on_time_scale_changed(_de: float, para: float) -> void:
	_mostra_velocidade(para)

func _on_game_saved(slot: String) -> void:
	_label_save.text = "salvo em %s" % slot

func _on_game_loaded(slot: String, carregado: bool) -> void:
	_label_save.text = "%s: %s" % [slot, "carregado" if carregado else "partida nova"]

func _on_save_rejected(slot: String) -> void:
	_label_save.text = "save de %s recusado — partida nova" % slot

## Tudo o que o painel mostra sai de um `snapshot()` só: a mesma foto que o save
## grava.
func _atualiza() -> void:
	var snapshot := _bridge.get_world().snapshot()
	_mostra_relogio(snapshot.get(SimFactory.CHAVE_TIME, {}))
	_mostra_mochila(snapshot.get(SimFactory.CHAVE_INVENTORY, {}))
	_mostra_caixote(snapshot.get(SimFactory.CHAVE_SHIPPING, {}))

func _mostra_relogio(time: Dictionary) -> void:
	var minuto := int(time.get("minuto", TimeState.MINUTO_DEFAULT))
	_label_relogio.text = "dia %d de %s — %02d:%02d" % [
		int(time.get("dia", TimeState.DIA_DEFAULT)),
		String(time.get("estacao", TimeState.ESTACAO_DEFAULT)),
		minuto / 60,
		minuto % 60,
	]

func _mostra_velocidade(escala: float) -> void:
	_label_velocidade.text = "relógio parado" if escala <= 0.0 else "velocidade ×%s" % escala

func _mostra_mochila(inventory: Dictionary) -> void:
	_limpa(_lista_mochila)
	var bruto: Variant = inventory.get(str(SimFactory.PLAYER_PADRAO), {})
	var player: Dictionary = bruto if bruto is Dictionary else {}
	var slots: Array = player.get("slots", [])
	_label_dinheiro.text = "%d moedas" % int(player.get("dinheiro", 0))
	_label_mochila.text = "Mochila (%d/%d)" % [slots.size(), int(player.get("capacity", 0))]

	for entrada: Variant in slots:
		var slot: Dictionary = entrada as Dictionary
		var item_id := String(slot.get("item_id", ""))
		var qtd := int(slot.get("qtd", 0))
		_linha_de_item(_lista_mochila, item_id, qtd, "→ caixote", _manda_pro_caixote)

func _mostra_caixote(shipping: Dictionary) -> void:
	_limpa(_lista_caixote)
	var itens: Array = shipping.get("itens", [])
	_label_caixote.text = "Caixote (%d tipos)" % itens.size()

	for entrada: Variant in itens:
		var item: Dictionary = entrada as Dictionary
		var item_id := String(item.get("item_id", ""))
		var qtd := int(item.get("qtd", 0))
		_linha_de_item(_lista_caixote, item_id, qtd, "← mochila", _tira_do_caixote)

## Uma linha "nome ×qtd" com o botão que move o stack inteiro para o outro lado.
func _linha_de_item(lista: VBoxContainer, item_id: String, qtd: int, rotulo: String,
		acao: Callable) -> void:
	var linha := HBoxContainer.new()
	lista.add_child(linha)
	var nome := Label.new()
	nome.text = "%s ×%d" % [_nome_do_item(item_id), qtd]
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	_botao(linha, rotulo, acao.bind(item_id, qtd))

## Nome bonito é conteúdo do `ItemDef`; item sem definição continua aparecendo
## pelo id, porque sumir da tela seria pior.
func _nome_do_item(item_id: String) -> String:
	var def := _bridge.get_item_catalog().get_def(item_id)
	return def.nome if def != null and not def.nome.is_empty() else item_id

# --- Utilitários de layout ---

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto
	return label

func _botao(pai: Node, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao

func _limpa(container: Node) -> void:
	for filho in container.get_children():
		container.remove_child(filho)
		filho.queue_free()
