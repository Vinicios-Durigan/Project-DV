class_name StatusPanel
extends VBoxContainer

## Tempo, truques, loja e save. É o painel que deixa a sim inteira ser jogada
## sem tocar no teclado.
##
## Desde a wave 11 ele mora no rail esquerdo e foi perdendo o que não era
## botão: relógio, dinheiro e velocidade subiram para a barra de status, e a
## mochila e o caixote viraram o painel do Tab (`PainelMochila`). O que ficou
## aqui é o que se clica.
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

## Recomeçar apaga o save. Pede confirmação no próprio botão — modal para isso
## seria mais código do que a ação merece, e um clique perdido não pode custar
## a partida de alguém.
const ROTULO_RECOMECAR: String = "Recomeçar"
const ROTULO_CONFIRMA: String = "Apagar o save?"
## Quanto a confirmação fica de pé antes de o botão voltar ao normal.
const SEGUNDOS_PARA_CONFIRMAR: float = 4.0

var _bridge: SimBridge
var _label_save: Label
var _loja: HFlowContainer
var _botao_recomecar: Button
var _confirmando: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(LARGURA, 0)
	_monta_tempo()
	_monta_truques()
	_monta_loja()
	_monta_save()

func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_escuta_o_gateway()
	_preenche_loja()
	_atualiza()

# --- Montagem ---

func _monta_tempo() -> void:
	add_child(_titulo("Tempo"))
	var linha := HFlowContainer.new()
	add_child(linha)
	_botao(linha, "+%d min" % PULO_CURTO, _adianta.bind(PULO_CURTO))
	_botao(linha, "+%d h" % (PULO_LONGO / 60), _adianta.bind(PULO_LONGO))
	_botao(linha, "Dormir", _dorme).theme_type_variation = &"BotaoPrimario"

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
	_botao_recomecar = _botao(linha, ROTULO_RECOMECAR, _recomeca)
	_botao_recomecar.theme_type_variation = &"BotaoPerigo"
	_label_save = Label.new()
	_label_save.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label_save)

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

## Apaga o save e reabre a cena: sem arquivo, o gateway começa uma partida nova.
## É o mesmo caminho do "carregar", e é por isso que ele testa o boot de verdade
## em vez de montar um mundo à mão.
##
## Dois cliques: o primeiro arma, o segundo executa. Apagar progresso não pode
## acontecer por um clique perdido, e uma janela de confirmação seria mais código
## do que a ação merece num painel de dev.
func _recomeca() -> void:
	if not _confirmando:
		_confirmando = true
		_botao_recomecar.text = ROTULO_CONFIRMA
		get_tree().create_timer(SEGUNDOS_PARA_CONFIRMAR).timeout.connect(_desarma)
		return

	var gateway := _save_gateway()
	if gateway != null:
		gateway.get_manager().delete_slot(gateway.slot)
	get_tree().reload_current_scene()

func _desarma() -> void:
	if not is_instance_valid(_botao_recomecar):
		return
	_confirmando = false
	_botao_recomecar.text = ROTULO_RECOMECAR

## O gateway é irmão nesta cena, não um serviço global: disco é assunto de
## apresentação e mora ao lado da bridge, nunca dentro da sim.
func _save_gateway() -> SaveGateway:
	if _bridge == null:
		return null
	return _bridge.get_node_or_null("SaveGateway") as SaveGateway

# --- Evento vira texto ---

## Minuto que passa não mexe em nada aqui: quem mostra o relógio é a barra de
## status. Redesenhar mochila e caixote 60 vezes por segundo em ×60 só gastaria
## botão.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	_atualiza()

func _on_game_saved(slot: String) -> void:
	_label_save.text = "salvo em %s" % slot

func _on_game_loaded(slot: String, carregado: bool) -> void:
	_label_save.text = "%s: %s" % [slot, "carregado" if carregado else "partida nova"]

func _on_save_rejected(slot: String) -> void:
	_label_save.text = "save de %s recusado — partida nova" % slot

## Este painel não mostra mais mochila nem caixote — quem mostra é o
## `PainelMochila`, no Tab. O que sobrou de estado aqui é o rótulo do save, que
## o gateway atualiza sozinho, então não há o que redesenhar por evento.
##
## O método continua existindo porque `setup` e `_on_sim_event` chamam por ele:
## quando o próximo painel de estado entrar neste rail, é aqui que ele entra.
func _atualiza() -> void:
	pass

# --- Utilitários de layout ---

## Título de grupo: micro-rótulo em caixa alta, do design system. Quem escreve
## em maiúsculas é aqui — fonte não faz caixa.
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

