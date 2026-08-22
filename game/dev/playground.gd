class_name Playground
extends Control

## Casca do playground: a fazenda de botões.
##
## Aqui a sim inteira é jogável sem um pixel de arte — mundo clicável, relógio,
## truques e o diário de avisos. É a implementação de referência dos três
## padrões de ligação entre `game/` e `sim/`; o jogo visual só implementa o que
## já foi jogado e aprovado aqui (CLAUDE.md, "Playground primeiro").
##
## Não entra no jogo final: `game/dev/` é ferramenta de time.
##
## ---
##
## ## O layout, desde a wave 11
##
## Cinco regiões, na disposição aprovada no design system v1: **barra de
## status** fixa no topo, **rail** à esquerda, **mundo** no centro, **inspetor**
## à direita e **diário** embaixo, colapsável. As regiões estão no `.tscn`; a
## casca só preenche as três que são chrome dela — a barra, os dois primeiros
## grupos do rail e o cabeçalho do diário.
##
## O resto continua sendo dos painéis: `StatusPanel` no rail, `MundoEsboco` no
## centro, `InspetorTile` e `MedidorDia` à direita, `EventFeed` embaixo. Por
## cima de tudo, quando o Tab pede, o `PainelMochila`.
##
## Nenhuma cor aqui: o visual sai todo do `tema_playground.tres`, aplicado na
## raiz desta cena, e das variações de tipo (`Relogio`, `Dinheiro`, `Micro`,
## `Truque`). Um `add_theme_color_override` é pintar na mão com outro nome.
##
## ---
##
## ## Padrão 1 — receber o fio
##
## Ninguém busca a sim. A `SimBridge` (nó raiz de `game/main.tscn`) chama
## `setup(self)` em todo filho direto que tiver o método; este nó faz o mesmo
## com os próprios filhos, e assim o fio desce a árvore inteira sem autoload e
## sem `get_node("/root/...")`.
##
## Um nó que não recebeu a bridge não fala com a sim — e isso é de propósito:
## é o que impede um botão perdido de mexer no jogo pelas costas.
##
## Copie daqui: `docs/receitas/receber-o-fio.md`.

## O nome de cada local na tela. Os ids são da sim; o texto é daqui.
const NOMES_LOCAIS: Dictionary = {
	EstadoLocais.FAZENDA: "Fazenda",
	EstadoLocais.CIDADE: "Cidade",
}

## O diário começa aberto: enquanto não existe sprite, ele é o jogo
## acontecendo. Fechar é para quando o mundo estiver apertado na tela.
const DIARIO_COMECA_ABERTO: bool = true

var _bridge: SimBridge
var _mundo: MundoEsboco
var _mira: MiraFerramentas
var _mochila: PainelMochila

var _relogio: Label
var _dinheiro: Label
var _botoes_velocidade: Dictionary = {}
var _botoes_locais: Dictionary = {}
var _rotulo_mao: Label
var _diario: Control
var _botao_diario: Button

## O fio chega aqui pela bridge e segue para baixo. É o único ponto de entrada
## deste nó: sem `setup`, o playground é um monte de botões que não fazem nada.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_mundo = get_node("Raiz/Corpo/Mundo/MundoEsboco") as MundoEsboco
	_mira = _mundo.get_node("MiraFerramentas") as MiraFerramentas
	_mochila = get_node("PainelMochila") as PainelMochila
	_passa_o_fio(self)

	_monta_barra()
	_monta_chrome_do_rail()
	_monta_cabecalho_do_diario()

	_bridge.sim_event.connect(_on_sim_event)
	_bridge.time_scale_changed.connect(_on_time_scale_changed)
	_mochila.alternado.connect(_mostra_mao_apos_fechar)
	# A casca é quem liga as duas pontas: o painel não sabe que existe um mundo,
	# e o mundo não sabe que existe uma mochila.
	_mochila.alternado.connect(_mundo.congela)
	# A porta e o balcão, pelo mesmo motivo: o prédio no mapa avisa qual é, e o
	# Tab abre já na aba certa. Nenhum dos dois conhece o outro.
	_mundo.predio_ativado.connect(_mochila.abre_cidade)

	_atualiza()

func get_bridge() -> SimBridge:
	return _bridge

## O mundo de esboço, para quem precisa dele e está longe na árvore (o
## inspetor, por exemplo). Sobe-se a árvore até achar quem tem este método —
## nenhum painel guarda caminho de nó.
func get_mundo() -> MundoEsboco:
	return _mundo

## Desce a árvore entregando a bridge a quem sabe recebê-la.
##
## Quem tem `setup` recebe e a recursão para ali: aquele nó é dono dos próprios
## filhos e decide se passa o fio adiante. Quem não tem é caixa de layout
## (margem, painel de região, rolagem) e não fala com a sim — a busca continua
## abaixo dele.
func _passa_o_fio(no: Node) -> void:
	for filho in no.get_children():
		if filho.has_method("setup"):
			filho.call("setup", _bridge)
			continue
		_passa_o_fio(filho)


# --- Barra de status ---

## Relógio à esquerda, velocidade no meio, dinheiro à direita — a mesma ordem
## do mock. Os três são número, e número é sempre mono (variações `Relogio`,
## `Dinheiro`).
func _monta_barra() -> void:
	var linha := get_node("Raiz/Barra/LinhaBarra") as HBoxContainer

	_relogio = Label.new()
	_relogio.theme_type_variation = &"Relogio"
	linha.add_child(_relogio)

	var velocidades := HBoxContainer.new()
	velocidades.add_theme_constant_override("separation", Paleta.ESPACO_ITEM)
	linha.add_child(velocidades)
	for escala: float in SimBridge.ESCALAS:
		_botoes_velocidade[escala] = _botao_de_velocidade(
			velocidades, "×%d" % int(escala), escala)
	# Pausa é assunto de apresentação: o relógio de parede para e a sim não
	# fica sabendo. É por isso que ela é uma velocidade, e não uma ação.
	_botoes_velocidade[0.0] = _botao_de_velocidade(velocidades, "⏸", 0.0)

	var folga := Control.new()
	folga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(folga)

	_dinheiro = Label.new()
	_dinheiro.theme_type_variation = &"Dinheiro"
	linha.add_child(_dinheiro)

func _botao_de_velocidade(pai: Node, texto: String, escala: float) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.theme_type_variation = &"Truque"
	botao.pressed.connect(func() -> void: _bridge.set_time_scale(escala))
	pai.add_child(botao)
	return botao


# --- Rail: onde você está e o que está na mão ---

func _monta_chrome_do_rail() -> void:
	var coluna := get_node("Raiz/Corpo/Rail/RolagemRail/ColunaRail/ChromeRail") as VBoxContainer

	var locais := _grupo(coluna, "Você está")
	for id: String in EstadoLocais.LOCAIS_VALIDOS:
		var rotulo := Label.new()
		rotulo.text = String(NOMES_LOCAIS.get(id, id))
		locais.add_child(rotulo)
		_botoes_locais[id] = rotulo

	# O grupo de ferramentas do rail morreu na wave 11.2: não existem mais quatro
	# ferramentas em teclas próprias, existe o item na mão. Quem mostra isso é a
	# hotbar, que fica sobre o mundo — perto do canteiro, e não numa coluna a
	# meia tela de distância.
	var mao := _grupo(coluna, "Na mão")
	_rotulo_mao = Label.new()
	_rotulo_mao.theme_type_variation = &"Rotulo"
	mao.add_child(_rotulo_mao)

	var dica := Label.new()
	dica.theme_type_variation = &"Micro"
	dica.text = "TECLAS 1–8 · TAB ABRE A MOCHILA"
	mao.add_child(dica)

## Um grupo do rail: micro-rótulo em caixa alta e os itens embaixo, na grade
## de 4px.
func _grupo(pai: Node, titulo: String) -> VBoxContainer:
	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"
	pai.add_child(caixa)

	var rotulo := Label.new()
	rotulo.text = titulo.to_upper()
	rotulo.theme_type_variation = &"Micro"
	caixa.add_child(rotulo)
	return caixa


# --- Diário colapsável ---

func _monta_cabecalho_do_diario() -> void:
	_diario = get_node("Raiz/Diario/ColunaDiario/EventFeed") as Control
	var cabecalho := get_node("Raiz/Diario/ColunaDiario/CabecalhoDiario") as HBoxContainer

	_botao_diario = Button.new()
	_botao_diario.theme_type_variation = &"Truque"
	_botao_diario.pressed.connect(_alterna_diario)
	cabecalho.add_child(_botao_diario)

	_diario.visible = DIARIO_COMECA_ABERTO
	_mostra_estado_do_diario()

func _alterna_diario() -> void:
	_diario.visible = not _diario.visible
	_mostra_estado_do_diario()

func _mostra_estado_do_diario() -> void:
	_botao_diario.text = "%s Diário de avisos" % ("▾" if _diario.visible else "▸")


# --- Evento vira texto ---

## Minuto que passa mexe no relógio e em nada mais; qualquer outro evento pode
## ter mexido no dinheiro ou no local.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		_mostra_relogio()
		return
	_atualiza()

func _on_time_scale_changed(_de: float, para: float) -> void:
	_mostra_velocidade(para)

func _atualiza() -> void:
	_mostra_relogio()
	_mostra_dinheiro()
	_mostra_local()
	_mostra_velocidade(_bridge.get_time_scale())
	_mostra_mao()

## Tudo o que a barra mostra sai do `snapshot()` — a mesma foto que o save
## grava (regra da wave 08).
func _snapshot(chave: String) -> Dictionary:
	return _bridge.get_world().snapshot().get(chave, {})

func _mostra_relogio() -> void:
	var time := _snapshot(SimFactory.CHAVE_TIME)
	var minuto := int(time.get("minuto", TimeState.MINUTO_DEFAULT))
	_relogio.text = "Dia %d · %s · %02d:%02d" % [
		int(time.get("dia", TimeState.DIA_DEFAULT)),
		String(time.get("estacao", TimeState.ESTACAO_DEFAULT)).capitalize(),
		minuto / 60,
		minuto % 60,
	]

func _mostra_dinheiro() -> void:
	var bruto: Variant = _snapshot(SimFactory.CHAVE_INVENTORY) \
		.get(str(SimFactory.PLAYER_PADRAO), {})
	var player: Dictionary = bruto if bruto is Dictionary else {}
	_dinheiro.text = "%dg" % int(player.get("dinheiro", 0))

## Onde o jogador está **segundo a sim**, nunca segundo a tela. Quando os dois
## discordarem, quem errou é `game/`.
func _mostra_local() -> void:
	var jogadores: Dictionary = _snapshot(SimFactory.CHAVE_LOCAIS).get("jogadores", {})
	var aqui := String(jogadores.get(str(SimFactory.PLAYER_PADRAO), EstadoLocais.LOCAL_DEFAULT))
	for id: String in _botoes_locais:
		var rotulo: Label = _botoes_locais[id]
		var presente := id == aqui
		rotulo.theme_type_variation = &"Rotulo" if presente else &"Micro"
		rotulo.text = "%s%s" % [String(NOMES_LOCAIS.get(id, id)), "   aqui" if presente else ""]

func _mostra_velocidade(escala: float) -> void:
	for valor: float in _botoes_velocidade:
		var botao: Button = _botoes_velocidade[valor]
		botao.button_pressed = is_equal_approx(valor, escala)
		botao.toggle_mode = true

## O que está na mão, pelo nome. A hotbar mostra o mesmo com destaque; este
## rótulo é para quem está lendo o rail e não a faixa de baixo.
func _mostra_mao() -> void:
	var item_id := _mochila.item_na_mao()
	if item_id.is_empty():
		_rotulo_mao.text = "mão vazia"
		return
	var def := _bridge.get_item_catalog().get_def(item_id)
	_rotulo_mao.text = def.nome if def != null and not def.nome.is_empty() else item_id

## Fechar a mochila pode ter mudado a mão.
func _mostra_mao_apos_fechar(_aberto: bool) -> void:
	_mostra_mao()
