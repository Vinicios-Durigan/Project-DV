class_name PainelMochila
extends Control

## A mochila em tela cheia, no **Tab**. Mochila de um lado, caixote do outro,
## clique manda o stack para o outro lado.
##
## ## Por que tela cheia, e não mais uma coluna
##
## Capacidade é a mecânica mais fácil de esquecer que existe. Numa lista ela é
## um número no título; numa grade com os **slots vazios desenhados**, ela é
## visível antes de encher — e é ela que vai fazer a cota da cidade doer.
##
## ## Por que é modal de verdade
##
## Com o painel aberto o mundo congela: não se anda, não se mira, não se age.
## Um clique atravessando o painel e arando um canteiro seria um bug que só
## aparece com alguém distraído — e que ninguém consegue reproduzir depois.
##
## ## Tab é briga com o Godot
##
## `Tab` é a tecla de navegação de foco do motor, tratada na fase de GUI. Se
## este nó esperasse por `_unhandled_key_input`, a tecla nunca chegaria: o
## primeiro botão da tela a receberia primeiro. Por isso o `Tab` é lido em
## `_input`, que roda **antes** da GUI, e é marcado como tratado ali mesmo.
##
## ---
##
## ## Padrões 2 e 3
##
## O clique não move item nenhum: ele monta `ShipItemAction` ou
## `WithdrawItemAction` e entrega para a bridge. Quem move é a sim, e o painel
## só redesenha quando o evento volta. É por isso que o teste de transferência
## não precisa de um único `await`.
##
## Tudo o que aparece aqui sai do `snapshot()` — a mesma foto que o save grava.

## A grade da mochila. 6 colunas cabem em 12 slots sem virar corredor.
const COLUNAS: int = 6
## Lado do quadrado de um slot, em pixels (múltiplo de 4).
const LADO_SLOT: float = 72.0
## Largura máxima da janela, para o painel não virar uma faixa no ultrawide.
const LARGURA_JANELA: float = 720.0

## Quantos slots ficam na faixa de baixo, sempre visível. GAMEPLAY §4: hotbar de
## 8 slots, teclas 1–8. A mochila tem 24 — a hotbar é a **fatia de cima dela**,
## não uma segunda mochila.
const SLOTS_HOTBAR: int = 8
## Lado do quadrado da hotbar. Menor que o da mochila: ela fica sobre o mundo.
const LADO_HOTBAR: float = 52.0
## Distância da hotbar até a base da tela.
const ALTURA_DA_HOTBAR: float = 12.0

## Espaço reservado ao ícone dentro do slot, já descontada a folga das bordas —
## sprite colado na borda parece apertado e some no contorno do quadrado.
##
## É **espaço disponível**, não o tamanho final: `_moldura_do_icone` encolhe até
## o maior múltiplo inteiro do sprite que caiba aqui. 52 vira 48 (3× de 16px) e
## 36 vira 32 (2×). Ver o cabeçalho da função — escala quebrada é o que faz
## pixel art boa parecer amadora.
const ESPACO_DO_ICONE: float = 52.0
## Na hotbar a folga é menor de cima: lá o número da tecla divide o espaço.
const ESPACO_DO_ICONE_HOTBAR: float = 36.0

## As duas abas do modal. `mochila` é a de sempre; `cidade` é o balcão do
## moinho e da padaria, que na wave 12 morava numa coluna de debug no rail.
##
## Aba, e não uma segunda tela modal: as duas disputariam a mesma tecla e o
## mesmo espaço. E juntas elas põem a **cota** ao lado da **capacidade da
## mochila** — os dois números que brigam entre si o jogo inteiro.
const ABA_MOCHILA: String = "mochila"
const ABA_CIDADE: String = "cidade"
const ABA_CONTRATOS: String = "contratos"
const ABAS: Array[String] = [ABA_MOCHILA, ABA_CIDADE, ABA_CONTRATOS]

## O nome de cada aba na tela. Os ids são de máquina; o texto é daqui.
const NOMES_ABAS: Dictionary = {
	ABA_MOCHILA: "Mochila",
	ABA_CIDADE: "Cidade",
	ABA_CONTRATOS: "Contratos",
}

var _bridge: SimBridge
var _modal: Control
var _hotbar: HBoxContainer
var _mochila: GridContainer
var _caixote: GridContainer
var _dinheiro: Label
var _capacidade: Label
var _vazio_caixote: Label
var _titulo: Label

## A aba aberta. Sobrevive a fechar e reabrir: quem estava conversando com o
## moleiro e apertou Tab sem querer não deveria ter que achar a aba de novo.
var _aba: String = ABA_MOCHILA
var _botoes_aba: Dictionary = {}
var _conteudo_mochila: Control
var _cidade: PainelCidade
var _contratos: PainelContratos


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A raiz não come clique: a hotbar mora nela e o mundo continua clicável ao
	# lado. Quem bloqueia é o véu, e só quando o modal está aberto.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monta()

## Padrão 3: recebe o fio e escuta. Redesenha fechado também — abrir tem que
## mostrar o estado de agora, não o de quando fechou.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	# A casca para de repassar o fio em quem tem `setup`: o balcão da cidade é
	# filho deste painel agora, então é este nó que o entrega.
	_cidade.setup(bridge)
	_contratos.setup(bridge)
	_atualiza()


# --- Abrir e fechar ---

## Aberto ou fechado. A casca escuta para congelar o mundo.
signal alternado(aberto: bool)

## Aberto é o **modal**, não este nó: a hotbar mora aqui e nunca some.
func aberto() -> bool:
	return _modal.visible

func hotbar_visivel() -> bool:
	return _hotbar.visible

func abre() -> void:
	if aberto():
		return
	_modal.visible = true
	_atualiza()
	alternado.emit(true)

func fecha() -> void:
	if not aberto():
		return
	_modal.visible = false
	alternado.emit(false)

func alterna() -> void:
	if aberto():
		fecha()
		return
	abre()


# --- As abas ---

## Qual aba está na frente.
func aba_atual() -> String:
	return _aba

## Troca de aba. Nome desconhecido não muda nada — a barra só oferece os que
## existem, e um id inventado não pode esvaziar a tela.
func mostra_aba(nome: String) -> void:
	if not ABAS.has(nome):
		_mostra_aba_na_tela()
		return
	_aba = nome
	_mostra_aba_na_tela()

func mochila_visivel() -> bool:
	return _conteudo_mochila.visible

func cidade_visivel() -> bool:
	return _cidade.visible

## O balcão da cidade, para quem precisa dele — os testes e a casca.
func painel_cidade() -> PainelCidade:
	return _cidade

func contratos_visivel() -> bool:
	return _contratos.visible

## A mesa dos contratos, para quem precisa dela — os testes e a casca.
func painel_contratos() -> PainelContratos:
	return _contratos

## Abre o modal já na aba de contratos, com o dono destacado. É o que a porta do
## mundo chama quando o prédio tem encomenda esperando resposta.
func abre_contratos(id: String) -> void:
	_contratos.destaca(id)
	mostra_aba(ABA_CONTRATOS)
	abre()

## Abre o modal já na aba da cidade, com o estabelecimento destacado.
##
## É o que a porta do mundo chama: quem entrou no moinho não quer procurar o
## moinho numa lista.
func abre_cidade(id: String) -> void:
	_cidade.destaca(id)
	mostra_aba(ABA_CIDADE)
	abre()

func _mostra_aba_na_tela() -> void:
	_conteudo_mochila.visible = _aba == ABA_MOCHILA
	_cidade.visible = _aba == ABA_CIDADE
	_contratos.visible = _aba == ABA_CONTRATOS
	_titulo.text = String(NOMES_ABAS.get(_aba, _aba)).to_upper()
	for nome: String in _botoes_aba:
		(_botoes_aba[nome] as Button).button_pressed = nome == _aba

## `_input` e não `_unhandled_key_input`: ver o cabeçalho — a fase de GUI
## engoliria o `Tab` na navegação de foco antes de ele chegar aqui. As teclas
## da hotbar vão pelo mesmo caminho para serem consumidas antes de o mundo
## vê-las.
func _input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return

	if tecla.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		alterna()
		return

	if aberto() and tecla.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fecha()
		return

	# Teclas 1–8: a hotbar. Funciona com o painel aberto ou fechado — trocar de
	# item é o gesto mais frequente do jogo e não pode pedir um clique.
	var slot := tecla.physical_keycode - KEY_1
	if slot >= 0 and slot < SLOTS_HOTBAR:
		get_viewport().set_input_as_handled()
		equipa(slot)


# --- Leitura (o que os testes e o resto da tela perguntam) ---

## Quantos slots a mochila comporta, segundo a sim.
func capacidade() -> int:
	return int(_jogador().get("capacity", 0))

## Quantos quadrados a hotbar desenhou.
func slots_da_hotbar() -> int:
	return _hotbar.get_child_count()

## Em que slot está a mão, segundo a sim.
func slot_na_mao() -> int:
	return int(_jogador().get("slot_na_mao", 0))

## O que está na mão, ou vazio. O índice pode apontar além dos stacks que
## existem — a mochila esvazia e a mão fica onde estava, como em qualquer
## hotbar.
func item_na_mao() -> String:
	var slots: Array = slots_ocupados()
	var indice := slot_na_mao()
	if indice < 0 or indice >= slots.size():
		return ""
	var slot: Dictionary = slots[indice]
	return String(slot.get("item_id", ""))

## Põe o slot na mão. Tecla e clique passam por aqui, e daqui sai uma ação da
## sim — o que está na mão é estado de jogo, não de tela.
func equipa(slot: int) -> void:
	var acao := EquiparSlotAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.slot = slot
	_bridge.dispatch(acao)

## Quantos quadrados a grade desenhou — cheios e vazios.
func slots_desenhados() -> int:
	return _mochila.get_child_count()

## Os stacks da mochila, crus, como vieram do snapshot.
func slots_ocupados() -> Array:
	return _jogador().get("slots", [])

## O item que está num endereço da mochila, ou vazio. Desde a wave 11.3 o slot
## tem posição fixa, então perguntar por índice passou a fazer sentido.
func item_no_slot(indice: int) -> String:
	var slots: Array = slots_ocupados()
	if indice < 0 or indice >= slots.size():
		return ""
	var slot: Dictionary = slots[indice]
	return String(slot.get("item_id", ""))

## Os stacks do caixote, crus.
func itens_do_caixote() -> Array:
	return _snapshot(SimFactory.CHAVE_SHIPPING).get("itens", [])


# --- Padrão 2: o clique vira ação ---

## Manda o stack inteiro para o caixote. `ShipItemAction` é uma
## `RemoveItemAction`: o inventário tira e o caixote guarda, nessa ordem, e
## ninguém desfaz nada.
func transfere_da_mochila(item_id: String, qtd: int) -> void:
	var acao := ShipItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)

## Traz de volta. Se a mochila estiver cheia, quem recusa é a sim — e o motivo
## aparece no toast, como qualquer outra recusa.
func transfere_do_caixote(item_id: String, qtd: int) -> void:
	var acao := WithdrawItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)


# --- Montagem ---

func _monta() -> void:
	_monta_hotbar()
	_monta_modal()

## A faixa de baixo, sempre na tela. É ela que responde "o que está na minha
## mão?" sem interromper o jogo — abrir a mochila inteira para conferir seria o
## contrário do que a hotbar existe para resolver.
func _monta_hotbar() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	centro.offset_top = -(LADO_HOTBAR + ALTURA_DA_HOTBAR * 2.0)
	centro.offset_bottom = -ALTURA_DA_HOTBAR
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", Paleta.ESPACO_ITEM)
	centro.add_child(_hotbar)

func _monta_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.visible = false
	add_child(_modal)

	var veu := PanelContainer.new()
	veu.theme_type_variation = &"Veu"
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# O véu é o que come o clique que passaria para o mundo atrás dele.
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(centro)

	var janela := PanelContainer.new()
	janela.theme_type_variation = &"Janela"
	janela.custom_minimum_size = Vector2(LARGURA_JANELA, 0)
	centro.add_child(janela)

	var coluna := VBoxContainer.new()
	coluna.theme_type_variation = &"Grupos"
	janela.add_child(coluna)

	coluna.add_child(_cabecalho())
	coluna.add_child(_barra_de_abas())

	# A aba da mochila: as duas grades que sempre estiveram aqui, agora dentro
	# de uma caixa que some quando a outra aba está na frente.
	_conteudo_mochila = VBoxContainer.new()
	_conteudo_mochila.theme_type_variation = &"Grupos"
	_conteudo_mochila.add_child(_secao("Mochila", true))
	_conteudo_mochila.add_child(_secao("Caixote", false))
	coluna.add_child(_conteudo_mochila)

	# A aba da cidade é o `PainelCidade` inteiro, montado aqui em vez de no
	# `.tscn`: ele é conteúdo deste modal, e quem entrega o fio a ele é este nó
	# — a casca para de repassar a bridge em quem tem `setup`.
	_cidade = PainelCidade.new()
	_cidade.name = "PainelCidade"
	coluna.add_child(_cidade)

	# Aba irmã da cidade, e não uma seção dentro dela: beneficiar é serviço que
	# o jogador contrata, contrato é pedido feito **a** ele. Misturar os dois
	# numa tela só faria a fila do moinho e o prazo do dono disputarem o mesmo
	# olhar — e é o prazo que tem hora para acabar.
	_contratos = PainelContratos.new()
	_contratos.name = "PainelContratos"
	coluna.add_child(_contratos)

	coluna.add_child(_rodape())
	_mostra_aba_na_tela()

func _cabecalho() -> Control:
	var linha := HBoxContainer.new()

	_titulo = Label.new()
	_titulo.theme_type_variation = &"Titulo"
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(_titulo)

	_capacidade = Label.new()
	_capacidade.theme_type_variation = &"Dado"
	linha.add_child(_capacidade)

	_dinheiro = Label.new()
	_dinheiro.theme_type_variation = &"Dinheiro"
	linha.add_child(_dinheiro)
	return linha

func _secao(titulo: String, e_mochila: bool) -> Control:
	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"

	var rotulo := Label.new()
	rotulo.text = titulo.to_upper()
	rotulo.theme_type_variation = &"Micro"
	caixa.add_child(rotulo)

	var grade := GridContainer.new()
	grade.columns = COLUNAS
	caixa.add_child(grade)
	if e_mochila:
		_mochila = grade
	else:
		_caixote = grade
		# O caixote não tem capacidade: vazio, ele não tem quadrado nenhum para
		# desenhar, e uma grade vazia parece um painel quebrado.
		_vazio_caixote = Label.new()
		_vazio_caixote.text = "vazio — clique num item da mochila para depositar"
		_vazio_caixote.theme_type_variation = &"Micro"
		caixa.add_child(_vazio_caixote)
	return caixa

## Uma fila de botões de aba. Nenhum deles nasce desabilitado: a aba aberta é
## um botão pressionado, e trocar de aba nunca é impossível.
func _barra_de_abas() -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", Paleta.ESPACO_ITEM)
	for nome: String in ABAS:
		var botao := Button.new()
		botao.text = String(NOMES_ABAS.get(nome, nome))
		botao.theme_type_variation = &"Truque"
		botao.toggle_mode = true
		botao.pressed.connect(mostra_aba.bind(nome))
		linha.add_child(botao)
		_botoes_aba[nome] = botao
	return linha

func _rodape() -> Control:
	var dica := Label.new()
	dica.theme_type_variation = &"Micro"
	dica.text = "CLIQUE MOVE O STACK INTEIRO · E ABRE O PRÉDIO NO MAPA · TAB OU ESC FECHA"
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return dica


# --- Evento vira tela ---

func _on_sim_event(_event: SimEvent) -> void:
	_atualiza()

func _snapshot(chave: String) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_world().snapshot().get(chave, {})

func _jogador() -> Dictionary:
	var bruto: Variant = _snapshot(SimFactory.CHAVE_INVENTORY) \
		.get(str(SimFactory.PLAYER_PADRAO), {})
	return bruto if bruto is Dictionary else {}

func _atualiza() -> void:
	if _bridge == null:
		return
	var jogador := _jogador()
	var slots: Array = jogador.get("slots", [])
	var total := capacidade()

	_capacidade.text = "%d / %d slots" % [slots.size(), total]
	_dinheiro.text = "%dg" % int(jogador.get("dinheiro", 0))

	_limpa(_mochila)
	for i in total:
		if i < slots.size():
			var slot: Dictionary = slots[i]
			_mochila.add_child(_quadrado(
				String(slot.get("item_id", "")), int(slot.get("qtd", 0)), true, i))
			continue
		_mochila.add_child(_quadrado("", 0, true, i))

	_limpa(_caixote)
	var itens := itens_do_caixote()
	_vazio_caixote.visible = itens.is_empty()
	for entrada: Variant in itens:
		var item: Dictionary = entrada
		_caixote.add_child(_quadrado(
			String(item.get("item_id", "")), int(item.get("qtd", 0)), false))

	_atualiza_hotbar(slots)

## A hotbar mostra os mesmos slots da mochila, com o da mão destacado. O clique
## aqui **equipa**; o clique na mochila aberta transfere para o caixote. São dois
## gestos diferentes em dois lugares diferentes — nunca no mesmo quadrado.
func _atualiza_hotbar(slots: Array) -> void:
	_limpa_filhos(_hotbar)
	var mao := slot_na_mao()
	for i in SLOTS_HOTBAR:
		var item_id := ""
		var qtd := 0
		if i < slots.size():
			var slot: Dictionary = slots[i]
			item_id = String(slot.get("item_id", ""))
			qtd = int(slot.get("qtd", 0))
		_hotbar.add_child(_quadrado_da_hotbar(i, item_id, qtd, i == mao))

func _quadrado_da_hotbar(indice: int, item_id: String, qtd: int, na_mao: bool) -> Control:
	var botao := _arrastavel(indice, item_id)
	botao.custom_minimum_size = Vector2(LADO_HOTBAR, LADO_HOTBAR)
	botao.clip_text = true
	botao.mouse_filter = Control.MOUSE_FILTER_STOP
	# O slot na mão tem estilo próprio, e não um "pressionado": ele precisa ser
	# óbvio de relance, porque é a resposta para "o que este clique vai fazer?".
	# Mão vazia também é um lugar — o destaque fica mesmo sem item.
	if na_mao:
		botao.theme_type_variation = &"SlotNaMao"
	elif item_id.is_empty():
		botao.theme_type_variation = &"Slot"
	else:
		botao.theme_type_variation = &"SlotCheio"

	var tecla := indice + 1
	if item_id.is_empty():
		botao.text = "%d\n—" % tecla if na_mao else "%d" % tecla
		botao.tooltip_text = "slot %d — vazio (mão vazia colhe)" % tecla
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.pressed.connect(equipa.bind(indice))
		return botao

	var nome := _nome_do_item(item_id)
	botao.tooltip_text = "%s — tecla %d" % [nome, tecla]

	# O número da tecla nunca sai da hotbar, com ícone ou sem: é ele que liga o
	# quadrado ao dedo, e é a informação que se olha no meio de uma corrida.
	var icone := _icone_do_item(item_id)
	if icone != null:
		botao.text = str(tecla)
		botao.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		botao.add_child(_moldura_do_icone(icone, ESPACO_DO_ICONE_HOTBAR))
		if qtd > 1:
			botao.add_child(_etiqueta_de_quantidade("×%d" % qtd))
	else:
		botao.text = "%d\n%s" % [tecla, nome] if qtd <= 1 else "%d\n%s ×%d" % [tecla, nome, qtd]
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	botao.pressed.connect(equipa.bind(indice))
	return botao


## O ícone que o `.tres` do item aponta, ou `null` enquanto a arte não chegou.
func _icone_do_item(item_id: String) -> Texture2D:
	if _bridge == null:
		return null
	return Icones.do_item(_bridge.get_item_catalog(), item_id)


## O ícone dentro do quadrado: centralizado, **nearest** e em escala **inteira**.
##
## ## Por que a escala inteira é obrigatória
##
## `nearest` não borra, mas também não inventa pixel: num aumento de 3,25× ele
## desenha algumas colunas do sprite com 3px e outras com 4px. O contorno fica
## mordido, a linha de 1px vira ora fina ora grossa, e a arte parece mal
## desenhada mesmo estando perfeita no arquivo. É o mesmo motivo pelo qual o
## `project.godot` proíbe zoom não-inteiro na câmera (GAMEPLAY §2) — a regra
## vale para o ícone no slot exatamente igual.
##
## Por isso `espaco` é o que **cabe**, e não o tamanho final: a moldura encolhe
## até o maior múltiplo inteiro do sprite. Um ícone de 16px em 52 de espaço fica
## com 48 (3×) e ganha 2px de folga a mais de cada lado — ninguém percebe a
## folga, todo mundo percebe o pixel torto.
##
## A conta sai do tamanho real da textura, e não de uma constante: sprite de
## 16×32 (o personagem, um dia) continua caindo em escala inteira sozinho.
##
## O nó ignora o mouse: o clique é do botão, não da imagem.
func _moldura_do_icone(icone: Texture2D, espaco: float) -> TextureRect:
	var imagem := TextureRect.new()
	imagem.texture = icone
	var lado := maxf(icone.get_width(), icone.get_height())
	var escala := maxf(floorf(espaco / lado), 1.0)
	var tamanho := Vector2(icone.get_size()) * escala
	imagem.custom_minimum_size = tamanho
	imagem.size = tamanho
	# Centralizado pelo próprio tamanho, e não pelas bordas do botão: assim o
	# ícone continua em escala inteira mesmo se a grade esticar o slot.
	imagem.set_anchors_and_offsets_preset(Control.PRESET_CENTER,
		Control.PRESET_MODE_KEEP_SIZE)
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return imagem


## A quantidade no canto de baixo, por cima do ícone. Fora do texto do botão
## porque o texto do botão fica no meio — e no meio ele cobriria o desenho.
func _etiqueta_de_quantidade(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.theme_type_variation = &"Micro"
	rotulo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rotulo.offset_left = -46.0
	rotulo.offset_top = -20.0
	rotulo.offset_right = -4.0
	rotulo.offset_bottom = -2.0
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rotulo

## Um slot: o ícone quando existe, o nome escrito quando ainda não existe, e a
## quantidade no canto.
##
## O texto não some por causa do ícone — ele **dá lugar** a ele. Enquanto a arte
## de um item não chegou, aquele slot continua legível, e o playground continua
## jogável com meia dúzia de sprites prontos. Uma tela que só funciona depois de
## toda a arte pronta seria o contrário do que o playground existe para fazer.
func _quadrado(item_id: String, qtd: int, da_mochila: bool, indice: int = -1) -> Control:
	var botao := _arrastavel(indice if da_mochila else -1, item_id)
	botao.custom_minimum_size = Vector2(LADO_SLOT, LADO_SLOT)
	botao.clip_text = true
	botao.theme_type_variation = &"SlotCheio" if not item_id.is_empty() else &"Slot"

	if item_id.is_empty():
		# Slot vazio não recebe clique — mas **recebe o que for solto nele**, que
		# é o gesto mais comum do arrastar. Por isso ele fica desabilitado em vez
		# de sair da grade: desabilitado é impossibilidade de interface, não
		# regra de jogo (que nunca desabilita botão).
		botao.disabled = true
		botao.focus_mode = Control.FOCUS_NONE
		return botao

	var nome := _nome_do_item(item_id)
	botao.tooltip_text = "%s — %d\n%s" % [nome, qtd,
		"clique manda para o caixote" if da_mochila else "clique traz para a mochila"]

	var icone := _icone_do_item(item_id)
	if icone != null:
		botao.add_child(_moldura_do_icone(icone, ESPACO_DO_ICONE))
		botao.add_child(_etiqueta_de_quantidade("×%d" % qtd))
	else:
		botao.text = "%s\n×%d" % [nome, qtd]
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if da_mochila:
		botao.pressed.connect(transfere_da_mochila.bind(item_id, qtd))
	else:
		botao.pressed.connect(transfere_do_caixote.bind(item_id, qtd))
	return botao

## O quadrado que se arrasta. Índice negativo é quadrado que não participa do
## rearranjo — hoje, o do caixote, que não é slot de mochila.
##
## Um `SlotArrastavel` e não um `Button`: o arrastar do Godot mora em métodos
## virtuais, e virtual não se sobrescreve num nó criado com `.new()`.
func _arrastavel(indice: int, item_id: String) -> SlotArrastavel:
	var botao := SlotArrastavel.new()
	botao.indice = indice
	botao.tem_item = not item_id.is_empty()
	if indice >= 0:
		botao.soltou.connect(move)
	return botao

## Arrastar virou soltar: monta a ação e entrega. Quem move é a sim — a tela só
## redesenha quando o `SlotMovidoEvent` volta.
func move(de: int, para: int) -> void:
	var acao := MoverSlotAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.de = de
	acao.para = para
	_bridge.dispatch(acao)

## Nome bonito é conteúdo do `ItemDef`; item sem definição continua aparecendo
## pelo id, porque sumir da tela seria pior.
func _nome_do_item(item_id: String) -> String:
	var def := _bridge.get_item_catalog().get_def(item_id)
	return def.nome if def != null and not def.nome.is_empty() else item_id

func _limpa(grade: GridContainer) -> void:
	_limpa_filhos(grade)

func _limpa_filhos(caixa: Node) -> void:
	for filho in caixa.get_children():
		caixa.remove_child(filho)
		filho.queue_free()
