class_name PainelCidade
extends VBoxContainer

## A cidade no playground: entregar, esperar, buscar — tudo por botão.
##
## É aqui que a tese do jogo fica jogável antes de existir um pixel de arte: o
## trigo sozinho é o pior negócio da fazenda, e é a cidade que o transforma em
## dinheiro. Se a mecânica for morna, é para descobrir clicando neste painel, e
## não depois de o artista desenhar um moinho.
##
## ---
##
## ## Padrão 2 — o clique vira ação, e às vezes pergunta antes
##
## `EntregarAction` é uma `RemoveItemAction`: o `InventorySystem` tira o trigo
## da mochila **antes** de a cidade olhar a cota. Despachar um lote que a sim ia
## recusar custaria o trigo — por isso este painel chama `pode_entregar()` e
## obedece à resposta (receita 2, §4). É a mesma exceção do plantio.
##
## `RetirarAction` é uma `AddMoneyAction` com o valor negativo da taxa, e o
## número **não é inventado aqui**: sai de `taxa_a_pagar()`. A sim confere na
## chegada e recusa se não bater.
##
## ## Padrão 3 — a tela sai do snapshot
##
## Fila e relógio saem de `snapshot()`, a mesma foto que o save grava. Cota,
## taxa e "cabe este lote?" são **perguntas de regra** e saem do sistema, como
## `pode_plantar` — não são estado desenhado, são a sim respondendo.
##
## Nenhum `if` de regra mora aqui: quando a tela e a sim discordarem, quem
## errou é este arquivo.

## Quanto o truque de matéria-prima entrega de uma vez, em lotes. Três lotes
## enchem a cota inicial do moinho — é o que deixa a cota doer no primeiro
## minuto de teste, que é justamente o que se quer sentir.
const LOTES_DO_TRUQUE: int = 3

var _bridge: SimBridge
var _aviso: Label
var _ultimo_aviso: String = ""

## Qual estabelecimento o jogador acabou de abrir pelo mapa. Só destaque de
## tela: não muda o que se pode fazer com os outros.
var _destacado: String = ""
var _nomes: Dictionary = {}

## id -> os nós daquele estabelecimento, para redesenhar sem remontar.
var _resumos: Dictionary = {}
var _filas: Dictionary = {}
var _botoes_retirar: Dictionary = {}


func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_monta()
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza()


# --- Leitura: tudo o que aparece na tela vem daqui ---

## Os estabelecimentos que a sim conhece. A lista não mora neste arquivo.
func estabelecimentos() -> Array[String]:
	var sistema := _sistema_cidade()
	return sistema.ids() if sistema != null else ([] as Array[String])

## Quantas unidades de entrada estão comprometidas — em andamento e prontas
## esperando o jogador buscar.
func cota_usada(id: String) -> int:
	var total := 0
	for entrada: Variant in fila(id):
		total += int((entrada as Dictionary).get("qtd_entrada", 0))
	return total

## A cota vigente, respondida pela sim: ela depende da relação, e relação é
## regra de jogo.
func cota_total(id: String) -> int:
	var sistema := _sistema_cidade()
	return sistema.cota_de(id) if sistema != null else 0

## Quantos dias diferentes tiveram entrega aqui.
func dias_de_relacao(id: String) -> int:
	return int(_registro(id).get("dias_com_entrega", 0))

## Quanto custa buscar o que está pronto. Zero quando não há nada pronto.
func taxa_a_pagar(id: String) -> int:
	var sistema := _sistema_cidade()
	return sistema.taxa_a_pagar(id) if sistema != null else 0

## A fila deste estabelecimento, crua, como saiu do snapshot.
func fila(id: String) -> Array:
	var bruto: Variant = _registro(id).get("encomendas", [])
	return bruto if bruto is Array else []

## Quanto falta para a encomenda da posição `indice`, em minutos de jogo. Zero
## quando já está pronta.
func minutos_restantes(id: String, indice: int) -> int:
	var linhas := fila(id)
	if indice < 0 or indice >= linhas.size():
		return 0
	var enc: Dictionary = linhas[indice]
	return maxi(int(enc.get("minuto_conclusao", 0)) - _relogio(), 0)

## O que a sim respondeu da última vez que ela disse não.
func ultimo_aviso() -> String:
	return _ultimo_aviso

## Qual estabelecimento está em destaque, ou `""`.
func destacado() -> String:
	return _destacado

## Marca o estabelecimento que o jogador abriu pelo prédio no mapa. É só tela:
## os botões dos outros continuam clicáveis, porque estar no moinho não é regra
## que a sim conheça — ela só sabe que o jogador está na cidade.
func destaca(id: String) -> void:
	_destacado = id
	_mostra_destaque()

func _mostra_destaque() -> void:
	for id: String in _nomes:
		var rotulo := _nomes[id] as Label
		var aqui := id == _destacado
		rotulo.theme_type_variation = &"Rotulo" if aqui else &"Micro"
		rotulo.text = "▸ %s" % _nome_de(id) if aqui else _nome_de(id)

func _nome_de(id: String) -> String:
	var sistema := _sistema_cidade()
	var def := sistema.def_de(id) if sistema != null else null
	return def.nome if def != null and not def.nome.is_empty() else id


# --- Padrão 2: os botões ---

## Manda um lote. Pergunta antes porque esta ação cobra o item antes de a cidade
## validar — a resposta é da sim, nunca um `if` daqui.
func entrega(id: String) -> void:
	var sistema := _sistema_cidade()
	var def := sistema.def_de(id) if sistema != null else null
	if def == null:
		return

	if not sistema.pode_entregar(id, def.item_entrada, def.entram):
		_mostra_aviso("a sim disse não: pode_entregar(%s, %d)" % [id, def.entram])
		return

	var acao := EntregarAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.item_id = def.item_entrada
	acao.qtd = def.entram
	_bridge.dispatch(acao)

## Busca tudo o que está pronto, pagando a taxa combinada. Sem nada pronto a sim
## recusa com `nada_pronto` e o toast conta — o botão não se desabilita por
## regra de jogo.
func retira(id: String) -> void:
	var acao := RetirarAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.estabelecimento = id
	acao.valor = -taxa_a_pagar(id)
	_bridge.dispatch(acao)

## Truque de dev: matéria-prima na mão para testar sem esperar cinco dias de
## colheita. É uma `AddItemAction` de verdade — nenhum atalho mexe no state por
## fora.
func da_materia_prima(id: String) -> void:
	var sistema := _sistema_cidade()
	var def := sistema.def_de(id) if sistema != null else null
	if def == null:
		return
	var acao := AddItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = def.item_entrada
	acao.qtd = def.entram * LOTES_DO_TRUQUE
	_bridge.dispatch(acao)


# --- Texto ---

## "pronta", "45min", "4h", "2h13". Hora cheia não ganha zeros à toa.
##
## Estática porque o selo do prédio no mapa formata pelo mesmo lugar. Dois
## formatadores dariam "2h13" numa tela e "133min" na outra, no mesmo instante.
static func texto_do_tempo(minutos: int) -> String:
	if minutos <= 0:
		return "pronta"
	if minutos < 60:
		return "%dmin" % minutos
	@warning_ignore("integer_division")
	var horas := minutos / 60
	var resto := minutos % 60
	return "%dh" % horas if resto == 0 else "%dh%02d" % [horas, resto]


# --- Montagem ---

func _monta() -> void:
	add_child(_titulo("Cidade"))
	for id in estabelecimentos():
		add_child(_grupo_do_estabelecimento(id))

	_aviso = Label.new()
	_aviso.theme_type_variation = &"Micro"
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)
	_mostra_destaque()

func _grupo_do_estabelecimento(id: String) -> Control:
	var def := _sistema_cidade().def_de(id)

	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"

	var nome := Label.new()
	nome.text = def.nome
	nome.theme_type_variation = &"Micro"
	caixa.add_child(nome)
	_nomes[id] = nome

	# A receita sai do `.tres`: definição é leitura livre, e é ela que o
	# designer edita para mudar o jogo sem tocar em código.
	var receita := Label.new()
	receita.theme_type_variation = &"Micro"
	receita.text = "%d %s → %d %s · %s · %dg/un" % [
		def.entram, _nome_do_item(def.item_entrada),
		def.saem, _nome_do_item(def.item_saida),
		texto_do_tempo(def.prazo_minutos), def.taxa_por_unidade,
	]
	receita.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(receita)

	var resumo := Label.new()
	resumo.theme_type_variation = &"Dado"
	caixa.add_child(resumo)
	_resumos[id] = resumo

	var fila_caixa := VBoxContainer.new()
	caixa.add_child(fila_caixa)
	_filas[id] = fila_caixa

	var botoes := HFlowContainer.new()
	caixa.add_child(botoes)
	_botao(botoes, "Entregar %d %s" % [def.entram, _nome_do_item(def.item_entrada)],
		entrega.bind(id)).theme_type_variation = &"BotaoPrimario"
	_botoes_retirar[id] = _botao(botoes, "Retirar", retira.bind(id))
	_botao(botoes, "+%d %s" % [def.entram * LOTES_DO_TRUQUE, _nome_do_item(def.item_entrada)],
		da_materia_prima.bind(id)).theme_type_variation = &"Truque"
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

## O minuto que passa só mexe no tempo restante da fila: reescrever o texto de
## meia dúzia de rótulos aguenta ×60. Remontar a fila inteira não aguentaria.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		_mostra_tempos()
		return
	if event is ActionRejectedEvent:
		var recusa := event as ActionRejectedEvent
		if recusa.acao == "EntregarAction" or recusa.acao == "RetirarAction":
			_mostra_aviso("a sim recusou %s: %s" % [recusa.acao, recusa.motivo])
	_atualiza()

func _atualiza() -> void:
	if _bridge == null:
		return
	for id in estabelecimentos():
		_mostra_resumo(id)
		_monta_fila(id)
		(_botoes_retirar[id] as Button).text = _texto_do_retirar(id)

func _mostra_resumo(id: String) -> void:
	var label := _resumos[id] as Label
	label.text = "relação %d %s · cota %d/%d" % [
		dias_de_relacao(id),
		"dia" if dias_de_relacao(id) == 1 else "dias",
		cota_usada(id), cota_total(id),
	]

func _texto_do_retirar(id: String) -> String:
	var taxa := taxa_a_pagar(id)
	return "Retirar" if taxa <= 0 else "Retirar (%dg)" % taxa

## A fila cresce e encolhe, mas os rótulos **não** são recriados: o pool só
## aumenta e o que sobra fica escondido.
##
## O motivo é o relógio. Em ×60 esta função roda 60 vezes por segundo, e
## `queue_free()` a cada minuto de jogo deixaria um rastro de nós órfãos
## esperando o fim do frame. Reescrever texto não aloca nada.
func _monta_fila(id: String) -> void:
	var caixa := _filas[id] as VBoxContainer
	var linhas := fila(id)
	# Fila vazia ainda ocupa uma linha: "nada em produção" é mais honesto que
	# um buraco no painel.
	var usadas := maxi(linhas.size(), 1)
	while caixa.get_child_count() < usadas:
		caixa.add_child(Label.new())

	for i in caixa.get_child_count():
		var linha := caixa.get_child(i) as Label
		linha.visible = i < usadas
		if not linha.visible:
			continue
		if linhas.is_empty():
			linha.theme_type_variation = &"Micro"
			linha.text = "nada em produção"
			continue
		linha.theme_type_variation = &"Dado"
		linha.text = _texto_da_encomenda(id, i)

## O que roda a cada minuto de jogo: só as filas, sem tocar em cota nem em taxa
## — essas duas são perguntas para a sim, e não mudam sozinhas com o relógio.
func _mostra_tempos() -> void:
	for id in estabelecimentos():
		_monta_fila(id)

func _texto_da_encomenda(id: String, indice: int) -> String:
	var enc: Dictionary = fila(id)[indice]
	return "%d %s · %s" % [
		int(enc.get("qtd", 0)),
		_nome_do_item(String(enc.get("item_id", ""))),
		texto_do_tempo(minutos_restantes(id, indice)),
	]

func _mostra_aviso(texto: String) -> void:
	_ultimo_aviso = texto
	if _aviso != null:
		_aviso.text = texto


# --- De onde vêm os dados ---

## O sistema é dono das perguntas de regra; achar quem responde é problema de
## quem pergunta. `game/` nunca guarda referência de state — só de quem sabe.
func _sistema_cidade() -> SistemaCidade:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			return system as SistemaCidade
	return null

func _bloco() -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_world().snapshot().get(SimFactory.CHAVE_CIDADE, {})

func _relogio() -> int:
	return int(_bloco().get("relogio", EstadoCidade.RELOGIO_DEFAULT))

## A ficha do estabelecimento no save. Estabelecimento nunca visitado não tem
## entrada — e um dicionário vazio desenha tudo em zero, que é o certo.
func _registro(id: String) -> Dictionary:
	var bruto: Variant = _bloco().get("estabelecimentos", {}).get(id, {})
	return bruto if bruto is Dictionary else {}

## Nome bonito é conteúdo do `ItemDef`; item sem definição continua aparecendo
## pelo id, porque sumir da tela seria pior.
func _nome_do_item(item_id: String) -> String:
	var def := _bridge.get_item_catalog().get_def(item_id)
	return def.nome if def != null and not def.nome.is_empty() else item_id
