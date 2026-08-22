extends Control

## A ferramenta de recorte com janela: abre a folha, mostra o que ela achou
## marcado por cima da imagem e grava cada sprite na pasta do tipo dele.
##
## Como abrir: `tools\fatiar.bat`. Ou, na Godot, `tools/fatiar_visual.tscn` → F6.
##
## Três colunas, porque são três perguntas diferentes:
##
## - **esquerda**, como cortar — fundo, raio, acabamento. Mexer aqui muda quais
##   sprites existem.
## - **meio**, a folha — com zoom e arrasto, que uma folha de 1536px exige.
## - **direita**, a lista — um nome e um tipo por sprite. É aqui que uma folha
##   misturada (culturas + pão + regador) vira arquivos em pastas diferentes
##   numa passada só.
##
## A lógica de verdade mora em `tools/fatiador.gd`, `tools/destino_arte.gd` e
## `tools/peca_recortada.gd`, todos com teste. Aqui não há regra nenhuma: só
## montagem de controles, leitura do que o artista mexeu e desenho. É a mesma
## separação que `game/` tem de `sim/`, pelo mesmo motivo.
##
## Não é o jogo e não é wave visual: é ferramenta de pipeline de arte, e não
## disputa a fila de mecânicas do `CLAUDE.md`.

const LARGURA_AJUSTES: int = 340
const LARGURA_LISTA: int = 330
const MARGEM: int = 12

## Tamanho de janela que cabe as três colunas sem aperto.
const JANELA_PADRAO: Vector2i = Vector2i(1560, 900)
const JANELA_MINIMA: Vector2i = Vector2i(1100, 640)

const ZOOM_MINIMO: float = 0.1
const ZOOM_MAXIMO: float = 24.0
const PASSO_DO_ZOOM: float = 1.25
## Arrasto menor que isto conta como clique, e clique seleciona um sprite.
const ARRASTO_MINIMO: float = 4.0

const COR_FUNDO: Color = Color(0.11, 0.11, 0.13)
const COR_XADREZ_A: Color = Color(0.16, 0.16, 0.19)
const COR_XADREZ_B: Color = Color(0.20, 0.20, 0.23)
const COR_RECORTE: Color = Color(0.35, 0.85, 0.45)
const COR_ESCOLHIDO: Color = Color(1.0, 0.75, 0.25)
const COR_ALERTA: Color = Color(0.95, 0.65, 0.25)
const COR_ERRO: Color = Color(0.95, 0.40, 0.35)
const COR_OK: Color = Color(0.55, 0.85, 0.55)

var _fatiador: Fatiador = Fatiador.new()
var _folha_original: Image = null
var _textura: ImageTexture = null
var _pecas: Array[PecaRecortada] = []
var _escolhido: int = -1

## 0 = a folha se ajusta sozinha ao espaço. Qualquer outro valor é zoom que o
## artista pediu, e aí a ferramenta para de reenquadrar sozinha.
var _zoom: float = 0.0
var _deslocamento: Vector2 = Vector2.ZERO
var _arrastando: bool = false
var _andou: float = 0.0

var _abrir_folha: FileDialog
var _escolher_pasta: FileDialog
var _rotulo_folha: Label
var _tipo_padrao: OptionButton
var _slug: LineEdit
var _linha_slug: HBoxContainer
var _raiz: LineEdit
var _fundo_modo: OptionButton
var _fundo_cor: ColorPickerButton
var _tolerancia: HSlider
var _fundo_em_tudo: CheckBox
var _usar_grade: CheckBox
var _grade: SpinBox
var _raio: HSlider
var _area_minima: SpinBox
var _celula: SpinBox
var _ancora: OptionButton
var _escala: SpinBox
var _de_ia: CheckBox
var _encaixar: CheckBox
var _suave: CheckBox
var _alfa_corte: HSlider
var _cores: HSlider
var _lista: VBoxContainer
var _campos_de_nome: Array[LineEdit] = []
var _campos_de_tipo: Array[OptionButton] = []
var _marcas: Array[CheckBox] = []
var _botao_juntar: Button
var _botao_remover: Button
var _botao_nomear: Button
var _nome_base: LineEdit
var _padrao_de_nome: OptionButton
var _miniaturas: Array[TextureRect] = []
var _medidas: Array[Label] = []
var _botao_gravar: Button
var _resumo: RichTextLabel
var _rotulo_zoom: Label
var _tela: Control


func _ready() -> void:
	_ajusta_a_janela()
	_monta()
	_aplica_tipo_padrao_a_todos()
	_atualiza_resumo()


## O projeto roda num viewport de 640×360 esticado por escala inteira — é o que
## faz o *jogo* ter pixel grande e nítido (`project.godot`, `display/stretch`).
##
## Para uma ferramenta isso é veneno: todo controle sai ampliado 2× e o painel
## deixa de caber na tela. Aqui o stretch é desligado e a janela passa a medir
## em pixels de verdade.
##
## Só mexe na janela quando esta cena **é** a que está rodando. Dentro do teste,
## ou embutida em outra cena, a janela é de outra pessoa e não se toca nela.
func _ajusta_a_janela() -> void:
	if get_tree() == null or get_tree().current_scene != self:
		return

	var janela: Window = get_window()
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	janela.content_scale_factor = 1.0
	janela.title = "Fatiador — Project-DV"
	janela.min_size = JANELA_MINIMA
	janela.size = JANELA_PADRAO
	janela.move_to_center()


# --- montagem ------------------------------------------------------------

## `HBoxContainer` com larguras fixas nas laterais, e não `HSplitContainer`: o
## split mede o divisor a partir do centro da janela, e a coluna de ajustes
## acabava espremida a um terço da largura pedida.
func _monta() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fundo: ColorRect = ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var colunas: HBoxContainer = HBoxContainer.new()
	colunas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colunas.add_theme_constant_override("separation", 0)
	add_child(colunas)

	colunas.add_child(_monta_coluna_de_ajustes())
	colunas.add_child(VSeparator.new())
	colunas.add_child(_monta_coluna_da_folha())
	colunas.add_child(VSeparator.new())
	colunas.add_child(_monta_coluna_da_lista())

	_abrir_folha = _monta_dialogo(FileDialog.FILE_MODE_OPEN_FILE, "Abrir folha de sprites")
	_abrir_folha.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.bmp", "Imagens")
	_abrir_folha.file_selected.connect(_carrega_folha)

	_escolher_pasta = _monta_dialogo(FileDialog.FILE_MODE_OPEN_DIR, "Pasta de destino")
	_escolher_pasta.dir_selected.connect(func(caminho: String) -> void:
		_raiz.text = caminho
		_atualiza_resumo())


func _monta_dialogo(modo: FileDialog.FileMode, titulo: String) -> FileDialog:
	var dialogo: FileDialog = FileDialog.new()
	dialogo.file_mode = modo
	dialogo.access = FileDialog.ACCESS_FILESYSTEM
	dialogo.title = titulo
	dialogo.size = Vector2i(820, 560)
	dialogo.use_native_dialog = true
	add_child(dialogo)
	return dialogo


## A coluna esquerda rola, mas o resumo e o botão de gravar ficam **fixos** no
## rodapé: nenhuma tela cabe todas as seções, e descer até o fim a cada
## tentativa seria o passo mais repetido do trabalho.
func _monta_coluna_de_ajustes() -> Control:
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(LARGURA_AJUSTES, 0)
	coluna.add_theme_constant_override("separation", 0)

	var rolagem: ScrollContainer = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dentro: VBoxContainer = _caixa_com_margem(rolagem)

	_monta_secao_folha(dentro)
	_monta_secao_destino(dentro)
	_monta_secao_fundo(dentro)
	_monta_secao_corte(dentro)
	_monta_secao_acabamento(dentro)
	_monta_secao_ia(dentro)
	coluna.add_child(rolagem)

	coluna.add_child(HSeparator.new())
	var rodape: VBoxContainer = VBoxContainer.new()
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, MARGEM)
	margem.add_child(rodape)
	coluna.add_child(margem)
	_monta_rodape(rodape)
	return coluna


func _caixa_com_margem(pai: Control) -> VBoxContainer:
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 8)
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, MARGEM)
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.add_child(coluna)
	pai.add_child(margem)
	return coluna


func _monta_secao_folha(coluna: VBoxContainer) -> void:
	_titulo(coluna, "1. A folha")
	var botao: Button = Button.new()
	botao.text = "Abrir imagem..."
	botao.pressed.connect(func() -> void: _abrir_folha.popup_centered())
	coluna.add_child(botao)

	_rotulo_folha = Label.new()
	_rotulo_folha.text = "nenhuma folha aberta"
	_rotulo_folha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_folha.add_theme_font_size_override("font_size", 11)
	_rotulo_folha.modulate = Color(1, 1, 1, 0.6)
	coluna.add_child(_rotulo_folha)


## O tipo aqui é o **padrão**, não o destino final: ele preenche a lista da
## direita de uma vez, e lá cada sprite pode ser corrigido. Uma folha com
## culturas, pão e regador junto é o caso normal, não a exceção.
func _monta_secao_destino(coluna: VBoxContainer) -> void:
	_titulo(coluna, "2. Tipo padrão")

	_tipo_padrao = OptionButton.new()
	for tipo in DestinoArte.tipos_em_ordem():
		_tipo_padrao.add_item(DestinoArte.rotulo(tipo), tipo)
	coluna.add_child(_tipo_padrao)

	var aplicar: Button = Button.new()
	aplicar.text = "Aplicar a todos da lista"
	aplicar.pressed.connect(_aplica_tipo_padrao_a_todos)
	coluna.add_child(aplicar)

	_slug = LineEdit.new()
	_slug.placeholder_text = "cenoura"
	_slug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slug.text_changed.connect(func(_t: String) -> void: _atualiza_resumo())
	_linha_slug = _linha(coluna, "Cultura (padrão)", _slug)

	var dica: Label = _rotulo("Em Cultura, a subpasta sai do próprio nome:\n"
		+ "cenoura_estagio_0 → assets/crops/cenoura/")
	dica.modulate = Color(1, 1, 1, 0.55)
	coluna.add_child(dica)

	_raiz = LineEdit.new()
	_raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raiz.editable = false
	_raiz.text = "res://assets"
	var procurar: Button = Button.new()
	procurar.text = "..."
	procurar.tooltip_text = "Trocar a raiz de assets/ (raro — só se o projeto mudar de lugar)"
	procurar.pressed.connect(func() -> void: _escolher_pasta.popup_centered())
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_child(_raiz)
	linha.add_child(procurar)
	coluna.add_child(_rotulo("Raiz"))
	coluna.add_child(linha)


func _monta_secao_fundo(coluna: VBoxContainer) -> void:
	_titulo(coluna, "3. Fundo")

	_fundo_modo = OptionButton.new()
	_fundo_modo.add_item("Detectar sozinho", 0)
	_fundo_modo.add_item("Esta cor", 1)
	_fundo_modo.add_item("Não mexer", 2)
	_fundo_modo.item_selected.connect(func(_i: int) -> void: _reprocessa())
	coluna.add_child(_fundo_modo)

	_fundo_cor = ColorPickerButton.new()
	_fundo_cor.color = Color(0.17, 0.17, 0.19)
	_fundo_cor.custom_minimum_size = Vector2(0, 26)
	_fundo_cor.color_changed.connect(func(_c: Color) -> void:
		if _fundo_modo.selected == 1:
			_reprocessa())
	coluna.add_child(_fundo_cor)

	_tolerancia = HSlider.new()
	_tolerancia.min_value = 0
	_tolerancia.max_value = 96
	_tolerancia.value = 12
	_linha_com_valor(coluna, "Tolerância", _tolerancia, "%d")

	_fundo_em_tudo = CheckBox.new()
	_fundo_em_tudo.text = "Apagar a cor na imagem toda"
	_fundo_em_tudo.tooltip_text = ("Sem isto, a limpeza espalha a partir das bordas e o fundo"
		+ " cercado pelo desenho é preservado. Ligue só se sobrar fundo dentro do sprite.")
	_fundo_em_tudo.toggled.connect(func(_v: bool) -> void: _reprocessa())
	coluna.add_child(_fundo_em_tudo)


func _monta_secao_corte(coluna: VBoxContainer) -> void:
	_titulo(coluna, "4. Corte")

	_usar_grade = CheckBox.new()
	_usar_grade.text = "A folha está em grade fixa"
	_usar_grade.toggled.connect(func(_v: bool) -> void: _reprocessa())
	coluna.add_child(_usar_grade)

	_grade = _spin(coluna, "Lado da grade", 4, 256, 16, 1)
	_raio = HSlider.new()
	_raio.min_value = 1
	_raio.max_value = 16
	_raio.value = 2
	_linha_com_valor(coluna, "Juntar pedaços a até", _raio, "%d px")
	_area_minima = _spin(coluna, "Ignorar menor que", 1, 999, 6, 1)

	var dica: Label = _rotulo("Sprite partido em dois? aumente o raio.\n"
		+ "Dois colados num só? diminua.")
	dica.modulate = Color(1, 1, 1, 0.55)
	coluna.add_child(dica)


func _monta_secao_acabamento(coluna: VBoxContainer) -> void:
	_titulo(coluna, "5. Acabamento")
	_celula = _spin(coluna, "Célula (0 = justo)", 0, 256, 16, 1, false)

	_ancora = OptionButton.new()
	_ancora.add_item("Centro", Fatiador.Ancora.CENTRO)
	_ancora.add_item("Encostado embaixo", Fatiador.Ancora.BAIXO)
	_ancora.add_item("Encostado em cima", Fatiador.Ancora.TOPO)
	_ancora.item_selected.connect(func(_i: int) -> void: _refaz_as_imagens())
	coluna.add_child(_rotulo("Onde encosta na célula"))
	coluna.add_child(_ancora)

	_escala = _spin(coluna, "Escala", 0.05, 8.0, 1.0, 0.05, false)


## O caso mais comum hoje: a imagem veio de um gerador, grande e suave. O
## interruptor liga as quatro etapas juntas porque elas só funcionam juntas —
## reduzir sem cortar o alfa deixa halo, cortar o alfa sem cortar a paleta
## deixa a mancha de pintura.
func _monta_secao_ia(coluna: VBoxContainer) -> void:
	_titulo(coluna, "6. Imagem grande ou de IA")

	_de_ia = CheckBox.new()
	_de_ia.text = "Tratar como arte gerada"
	_de_ia.tooltip_text = ("Reduz até caber, suaviza a redução, tira o halo de transparência"
		+ " e corta a paleta. Transforma uma imagem de 512px em sprite de 16px.")
	_de_ia.toggled.connect(_liga_preset_de_ia)
	coluna.add_child(_de_ia)

	_encaixar = CheckBox.new()
	_encaixar.text = "Reduzir o que não couber na célula"
	_encaixar.toggled.connect(func(_v: bool) -> void: _refaz_as_imagens())
	coluna.add_child(_encaixar)

	_suave = CheckBox.new()
	_suave.text = "Reduzir suavizando"
	_suave.toggled.connect(func(_v: bool) -> void: _refaz_as_imagens())
	coluna.add_child(_suave)

	_alfa_corte = HSlider.new()
	_alfa_corte.min_value = 0
	_alfa_corte.max_value = 254
	_linha_com_valor(coluna, "Corte de alfa (0 = não)", _alfa_corte, "%d", false)

	_cores = HSlider.new()
	_cores.min_value = 0
	_cores.max_value = 64
	_linha_com_valor(coluna, "Máximo de cores (0 = não)", _cores, "%d", false)


func _monta_rodape(coluna: VBoxContainer) -> void:
	var titulo: Label = Label.new()
	titulo.text = "Gravar"
	titulo.add_theme_font_size_override("font_size", 14)
	coluna.add_child(titulo)

	_resumo = RichTextLabel.new()
	_resumo.bbcode_enabled = true
	_resumo.fit_content = true
	_resumo.custom_minimum_size = Vector2(0, 92)
	coluna.add_child(_resumo)

	_botao_gravar = Button.new()
	_botao_gravar.text = "Gravar os PNGs"
	_botao_gravar.custom_minimum_size = Vector2(0, 36)
	_botao_gravar.pressed.connect(_grava)
	coluna.add_child(_botao_gravar)


func _monta_coluna_da_folha() -> Control:
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var barra: HBoxContainer = HBoxContainer.new()
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 6)
	margem.add_child(barra)
	coluna.add_child(margem)

	_rotulo_zoom = _rotulo("roda do mouse: zoom  •  arrastar: mover  •  clique: escolher")
	_rotulo_zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_rotulo_zoom)

	for texto in ["−", "+"]:
		var botao: Button = Button.new()
		botao.text = texto
		botao.custom_minimum_size = Vector2(34, 0)
		botao.pressed.connect(_muda_zoom.bind(PASSO_DO_ZOOM if texto == "+" else 1.0 / PASSO_DO_ZOOM))
		barra.add_child(botao)

	var ajustar: Button = Button.new()
	ajustar.text = "Ajustar"
	ajustar.pressed.connect(_ajusta_o_enquadramento)
	barra.add_child(ajustar)

	_tela = Control.new()
	_tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tela.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tela.mouse_filter = Control.MOUSE_FILTER_STOP
	_tela.clip_contents = true
	_tela.draw.connect(_desenha_tela)
	_tela.gui_input.connect(_mouse_na_tela)
	_tela.resized.connect(func() -> void: _tela.queue_redraw())
	coluna.add_child(_tela)
	return coluna


## A lista é o que resolve a folha misturada: um nome e um tipo por sprite, com
## a miniatura do resultado ao lado para não haver dúvida sobre qual é qual.
func _monta_coluna_da_lista() -> Control:
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(LARGURA_LISTA, 0)
	coluna.add_theme_constant_override("separation", 0)

	var cabecalho: VBoxContainer = VBoxContainer.new()
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, MARGEM)
	margem.add_child(cabecalho)
	coluna.add_child(margem)

	var titulo: Label = Label.new()
	titulo.text = "Os sprites"
	titulo.add_theme_font_size_override("font_size", 14)
	cabecalho.add_child(titulo)

	# Nomear 25 sprites um a um é onde o trabalho realmente dói — e digitar o
	# mesmo nome em todos, que é o atalho natural, produz 25 arquivos que se
	# sobrescrevem. O lote resolve os dois: um nome base, e os sufixos saem
	# certos na ordem de leitura.
	_nome_base = LineEdit.new()
	_nome_base.placeholder_text = "abobora"
	_nome_base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(_rotulo("Nome base do lote"))
	cabecalho.add_child(_nome_base)

	_padrao_de_nome = OptionButton.new()
	for padrao in DestinoArte.padroes_em_ordem():
		_padrao_de_nome.add_item(DestinoArte.rotulo_do_padrao(padrao), padrao)
	_padrao_de_nome.tooltip_text = ("A ordem de leitura da folha decide. Olhe os números na"
		+ " imagem: o pacote de semente vem antes ou depois dos estágios?")
	cabecalho.add_child(_padrao_de_nome)

	_botao_nomear = Button.new()
	_botao_nomear.text = "Nomear marcados"
	_botao_nomear.pressed.connect(_nomeia_marcados)
	cabecalho.add_child(_botao_nomear)

	var marcacao: HBoxContainer = HBoxContainer.new()
	for texto in ["Marcar todos", "Limpar marcas"]:
		var botao: Button = Button.new()
		botao.text = texto
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(_marca_todos.bind(texto == "Marcar todos"))
		marcacao.add_child(botao)
	cabecalho.add_child(marcacao)

	# Há desenho que o detector não tem como saber que é um item só — um grão
	# partido, um cabo afastado da lâmina. Aumentar o raio até colar esses dois
	# cola também os vizinhos, então a decisão é manual.
	var acoes: HBoxContainer = HBoxContainer.new()
	_botao_juntar = Button.new()
	_botao_juntar.text = "Juntar marcados"
	_botao_juntar.tooltip_text = ("Marque dois ou mais quadradinhos e junte: eles viram um"
		+ " sprite só, na área que cobre todos.")
	_botao_juntar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_juntar.pressed.connect(_junta_marcados)
	acoes.add_child(_botao_juntar)

	_botao_remover = Button.new()
	_botao_remover.text = "Remover"
	_botao_remover.tooltip_text = "Descarta os marcados — para sujeira que virou recorte."
	_botao_remover.pressed.connect(_remove_marcados)
	acoes.add_child(_botao_remover)
	cabecalho.add_child(acoes)

	var refazer: Button = Button.new()
	refazer.text = "Refazer a lista do zero"
	refazer.tooltip_text = "Desfaz junções e remoções, voltando ao que o detector achou."
	refazer.pressed.connect(_reprocessa)
	cabecalho.add_child(refazer)

	var dica: Label = _rotulo("Junções e nomes se perdem se você mexer no corte (seção 4).\n"
		+ "Acerte o corte primeiro, depois a lista.")
	dica.modulate = Color(1, 1, 1, 0.55)
	cabecalho.add_child(dica)

	var rolagem: ScrollContainer = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista = _caixa_com_margem(rolagem)
	coluna.add_child(rolagem)
	return coluna


# --- controles auxiliares ------------------------------------------------

func _titulo(coluna: VBoxContainer, texto: String) -> void:
	if coluna.get_child_count() > 0:
		coluna.add_child(HSeparator.new())
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", 14)
	coluna.add_child(rotulo)


func _rotulo(texto: String) -> Label:
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", 11)
	rotulo.modulate = Color(1, 1, 1, 0.7)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return rotulo


func _linha(coluna: VBoxContainer, texto: String, controle: Control) -> HBoxContainer:
	var caixa: HBoxContainer = HBoxContainer.new()
	var rotulo: Label = _rotulo(texto)
	rotulo.custom_minimum_size = Vector2(120, 0)
	caixa.add_child(rotulo)
	caixa.add_child(controle)
	coluna.add_child(caixa)
	return caixa


## `refaz_o_corte` separa os dois tipos de controle: mexer na tolerância muda
## quais sprites existem e obriga a varrer a folha de novo; mexer no corte de
## alfa só muda como cada recorte é acabado, e refazer a busca ali seria
## trabalho jogado fora a cada arrasto do slider.
func _linha_com_valor(coluna: VBoxContainer, texto: String, slider: HSlider,
		formato: String, refaz_o_corte: bool = true) -> Label:
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(110, 0)
	var valor: Label = Label.new()
	valor.text = formato % int(slider.value)
	valor.custom_minimum_size = Vector2(48, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var caixa: HBoxContainer = HBoxContainer.new()
	var rotulo: Label = _rotulo(texto)
	rotulo.custom_minimum_size = Vector2(120, 0)
	caixa.add_child(rotulo)
	caixa.add_child(slider)
	caixa.add_child(valor)
	coluna.add_child(caixa)

	slider.value_changed.connect(func(v: float) -> void:
		valor.text = formato % int(v)
		if refaz_o_corte:
			_reprocessa()
		else:
			_refaz_as_imagens())
	return valor


func _spin(coluna: VBoxContainer, texto: String, minimo: float, maximo: float,
		valor: float, passo: float, refaz_o_corte: bool = true) -> SpinBox:
	var caixa: SpinBox = SpinBox.new()
	caixa.min_value = minimo
	caixa.max_value = maximo
	caixa.step = passo
	caixa.value = valor
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.value_changed.connect(func(_v: float) -> void:
		if refaz_o_corte:
			_reprocessa()
		else:
			_refaz_as_imagens())
	_linha(coluna, texto, caixa)
	return caixa


## O interruptor mexe nos controles finos em vez de guardar um estado próprio:
## assim o artista vê o que foi ligado e pode desfazer item por item.
func _liga_preset_de_ia(ligado: bool) -> void:
	var modelo: AcabamentoArte = (AcabamentoArte.arte_gerada(int(_celula.value))
		if ligado else AcabamentoArte.pixel_art(int(_celula.value)))
	_encaixar.set_pressed_no_signal(modelo.encaixar)
	_suave.set_pressed_no_signal(modelo.filtro == Fatiador.Filtro.SUAVE)
	_alfa_corte.set_value_no_signal(modelo.alfa_corte)
	_cores.set_value_no_signal(modelo.cores)
	_refaz_as_imagens()


# --- o trabalho ----------------------------------------------------------

func _carrega_folha(caminho: String) -> void:
	var imagem: Image = Image.load_from_file(caminho)
	if imagem == null:
		_rotulo_folha.text = "não consegui abrir esse arquivo"
		_rotulo_folha.modulate = COR_ERRO
		return

	_folha_original = imagem
	_rotulo_folha.modulate = Color(1, 1, 1, 0.6)
	_rotulo_folha.text = "%s — %d×%d" % [caminho.get_file(), imagem.get_width(), imagem.get_height()]

	# O palpite de cor entra no seletor: o artista precisa ver qual cor foi
	# detectada para poder corrigi-la a partir dela.
	var sonda: Fatiador = Fatiador.new()
	sonda.define_imagem(imagem)
	var provavel: Color = sonda.cor_de_fundo_provavel()
	if provavel.a >= 0.5:
		_fundo_cor.color = provavel

	_zoom = 0.0
	_deslocamento = Vector2.ZERO
	_reprocessa()


## Toda mexida num controle de corte passa por aqui: limpa o fundo de novo a
## partir da imagem original e reencontra os sprites. Refazer do zero é mais
## barato que desfazer, e é o que deixa cada slider responder na hora.
##
## Nome e tipo já digitados são preservados por posição — mexer na tolerância
## não pode apagar o trabalho de nomear.
func _reprocessa() -> void:
	if _folha_original == null:
		_atualiza_resumo()
		return

	var antes: Array[PecaRecortada] = _pecas
	_fatiador.define_imagem(_folha_original)

	match _fundo_modo.selected:
		0:
			var provavel: Color = _fatiador.cor_de_fundo_provavel()
			if provavel.a >= 0.5:
				_fatiador.remove_fundo(provavel, int(_tolerancia.value),
					not _fundo_em_tudo.button_pressed)
		1:
			_fatiador.remove_fundo(_fundo_cor.color, int(_tolerancia.value),
				not _fundo_em_tudo.button_pressed)

	var areas: Array[Rect2i] = (_fatiador.recorta_por_grade(int(_grade.value))
		if _usar_grade.button_pressed
		else _fatiador.acha_sprites(int(_raio.value), int(_area_minima.value)))
	areas = Fatiador.em_ordem_de_leitura(areas)

	var padrao: DestinoArte.Tipo = _tipo_padrao.get_selected_id() as DestinoArte.Tipo
	_pecas = []
	for i in areas.size():
		var nome: String = antes[i].nome if i < antes.size() else "sprite_%02d" % i
		var tipo: DestinoArte.Tipo = antes[i].tipo if i < antes.size() else padrao
		_pecas.append(PecaRecortada.nova(areas[i], nome, tipo))

	_escolhido = clampi(_escolhido, -1, _pecas.size() - 1)
	_textura = ImageTexture.create_from_image(_fatiador.imagem())
	_refaz_as_imagens()
	_remonta_a_lista()
	_atualiza_rotulo_de_zoom()


## O acabamento que a janela está pedindo agora — o mesmo objeto que a linha de
## comando monta, para que os dois caminhos não possam divergir.
func _acabamento_atual() -> AcabamentoArte:
	var acabamento: AcabamentoArte = AcabamentoArte.pixel_art(
		int(_celula.value), _ancora.get_selected_id() as Fatiador.Ancora)
	acabamento.escala = _escala.value
	acabamento.encaixar = _encaixar.button_pressed
	acabamento.filtro = (Fatiador.Filtro.SUAVE if _suave.button_pressed
		else Fatiador.Filtro.NEAREST)
	acabamento.alfa_corte = int(_alfa_corte.value)
	acabamento.cores = int(_cores.value)
	return acabamento


## Refaz só os sprites acabados, sem varrer a folha de novo. É o que responde na
## hora quando o artista arrasta o corte de alfa ou o número de cores.
func _refaz_as_imagens() -> void:
	if _folha_original != null:
		var acabamento: AcabamentoArte = _acabamento_atual()
		for peca in _pecas:
			peca.define_imagem(_fatiador.recorte(peca.area, acabamento))
	for i in mini(_miniaturas.size(), _pecas.size()):
		_miniaturas[i].texture = _pecas[i].textura
	for i in mini(_medidas.size(), _pecas.size()):
		_medidas[i].text = _medida_da_peca(_pecas[i])
		_medidas[i].modulate = (Color(1, 1, 1, 0.5)
			if not _pecas[i].passou_da_celula(int(_celula.value)) else COR_ALERTA)
	_tela.queue_redraw()
	_atualiza_resumo()


func _aplica_tipo_padrao_a_todos() -> void:
	var padrao: DestinoArte.Tipo = _tipo_padrao.get_selected_id() as DestinoArte.Tipo
	for i in _pecas.size():
		_pecas[i].tipo = padrao
		if i < _campos_de_tipo.size():
			_campos_de_tipo[i].select(_campos_de_tipo[i].get_item_index(padrao))
	_atualiza_resumo()


## Nomeia de uma vez todos os sprites marcados, na ordem de leitura.
##
## É o irmão do "Juntar marcados": mesma marcação, outra ação. Marcar os seis
## quadrinhos da abóbora e digitar `abobora` produz `abobora_semente`,
## `abobora_estagio_0` até `_3` e `abobora_fruto` — em vez de seis arquivos
## `abobora` que se sobrescreveriam.
func _nomeia_marcados() -> void:
	var indices: Array[int] = _marcados()
	if indices.is_empty():
		return

	var padrao: DestinoArte.Padrao = _padrao_de_nome.get_selected_id() as DestinoArte.Padrao
	var nomes: PackedStringArray = DestinoArte.nomes_em_lote(
		_nome_base.text, indices.size(), padrao)
	if nomes.is_empty():
		return

	for ordem in indices.size():
		var i: int = indices[ordem]
		_pecas[i].nome = nomes[ordem]
		if i < _campos_de_nome.size():
			_campos_de_nome[i].text = nomes[ordem]
	_atualiza_resumo()


## Marcar 25 quadradinhos um a um seria pior que o problema que o lote resolve.
func _marca_todos(ligado: bool) -> void:
	for marca in _marcas:
		marca.set_pressed_no_signal(ligado)
	_atualiza_acoes_da_lista()


# --- a lista -------------------------------------------------------------

func _remonta_a_lista() -> void:
	for filho in _lista.get_children():
		filho.queue_free()
	_campos_de_nome = []
	_campos_de_tipo = []
	_miniaturas = []
	_medidas = []
	_marcas = []

	for i in _pecas.size():
		_lista.add_child(_monta_linha_da_lista(i))
	_atualiza_acoes_da_lista()
	_atualiza_resumo()


func _monta_linha_da_lista(indice: int) -> Control:
	var peca: PecaRecortada = _pecas[indice]

	var caixa: PanelContainer = PanelContainer.new()
	var dentro: VBoxContainer = VBoxContainer.new()
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 6)
	margem.add_child(dentro)
	caixa.add_child(margem)

	var topo: HBoxContainer = HBoxContainer.new()

	var marca: CheckBox = CheckBox.new()
	marca.tooltip_text = "Marcar para juntar ou remover"
	marca.toggled.connect(func(_v: bool) -> void: _atualiza_acoes_da_lista())
	topo.add_child(marca)
	_marcas.append(marca)

	var numero: Label = Label.new()
	numero.text = str(indice)
	numero.custom_minimum_size = Vector2(20, 0)
	numero.modulate = Color(1, 1, 1, 0.5)
	topo.add_child(numero)

	var miniatura: TextureRect = TextureRect.new()
	miniatura.custom_minimum_size = Vector2(34, 34)
	miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Nearest: a miniatura é pixel art e qualquer filtro mentiria sobre o corte.
	miniatura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	miniatura.texture = peca.textura
	topo.add_child(miniatura)
	_miniaturas.append(miniatura)

	var nome: LineEdit = LineEdit.new()
	nome.text = peca.nome
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.text_changed.connect(func(texto: String) -> void:
		_pecas[indice].nome = texto.strip_edges()
		_atualiza_resumo())
	nome.focus_entered.connect(func() -> void: _escolhe(indice))
	topo.add_child(nome)
	_campos_de_nome.append(nome)
	dentro.add_child(topo)

	var medida: Label = _rotulo(_medida_da_peca(peca))
	medida.custom_minimum_size = Vector2(74, 0)
	topo.add_child(medida)
	_medidas.append(medida)

	var tipo: OptionButton = OptionButton.new()
	for opcao in DestinoArte.tipos_em_ordem():
		tipo.add_item(DestinoArte.rotulo(opcao), opcao)
	tipo.select(tipo.get_item_index(peca.tipo))
	tipo.item_selected.connect(func(escolha: int) -> void:
		_pecas[indice].tipo = tipo.get_item_id(escolha) as DestinoArte.Tipo
		_atualiza_resumo())
	dentro.add_child(tipo)
	_campos_de_tipo.append(tipo)
	return caixa


## O tamanho final ao lado do nome: a miniatura mostra o desenho, mas nao diz
## se ele saiu 16×16 ou 31×22. É a conferência mais rápida da lista.
func _medida_da_peca(peca: PecaRecortada) -> String:
	if peca.imagem == null:
		return ""
	return "%d×%d" % [peca.imagem.get_width(), peca.imagem.get_height()]


func _escolhe(indice: int) -> void:
	_escolhido = indice
	_tela.queue_redraw()


func _marcados() -> Array[int]:
	var indices: Array[int] = []
	for i in mini(_marcas.size(), _pecas.size()):
		if _marcas[i].button_pressed:
			indices.append(i)
	return indices


func _atualiza_acoes_da_lista() -> void:
	var quantos: int = _marcados().size()
	_botao_juntar.disabled = quantos < 2
	_botao_remover.disabled = quantos < 1
	_botao_nomear.disabled = quantos < 1


## Dois recortes que são o mesmo desenho viram um só. O detector separa por
## vizinhança e não tem como saber que aqueles dois pedaços são um grão partido
## — e subir o raio até colá-los cola também os vizinhos.
##
## A área nova cobre as duas, então o vão entre elas entra junto: é transparente,
## e some no recorte.
func _junta_marcados() -> void:
	var indices: Array[int] = _marcados()
	if indices.size() < 2:
		return

	var escolhidas: Array[PecaRecortada] = []
	for i in indices:
		escolhidas.append(_pecas[i])

	var restantes: Array[PecaRecortada] = []
	for i in _pecas.size():
		if not indices.has(i):
			restantes.append(_pecas[i])
	restantes.append(PecaRecortada.juntadas(escolhidas))

	_troca_as_pecas(restantes)


func _remove_marcados() -> void:
	var indices: Array[int] = _marcados()
	if indices.is_empty():
		return

	var restantes: Array[PecaRecortada] = []
	for i in _pecas.size():
		if not indices.has(i):
			restantes.append(_pecas[i])
	_troca_as_pecas(restantes)


## Reordena em ordem de leitura depois de mexer na lista: o número que aparece
## na folha tem de continuar batendo com a posição na lista, senão a junção
## seguinte é feita às cegas.
func _troca_as_pecas(novas: Array[PecaRecortada]) -> void:
	var por_area: Dictionary = {}
	var areas: Array[Rect2i] = []
	for peca in novas:
		por_area[peca.area] = peca
		areas.append(peca.area)

	_pecas = []
	for area in Fatiador.em_ordem_de_leitura(areas):
		_pecas.append(por_area[area])

	_escolhido = -1
	_refaz_as_imagens()
	_remonta_a_lista()


# --- zoom e arrasto ------------------------------------------------------

## Uma folha de 1536px não cabe na tela e não se confere de longe: sem zoom e
## sem arrasto não dá para ver se o retângulo verde pegou o sprite inteiro.
func _mouse_na_tela(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var botao: InputEventMouseButton = evento
		match botao.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if botao.pressed:
					_muda_zoom(PASSO_DO_ZOOM, botao.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if botao.pressed:
					_muda_zoom(1.0 / PASSO_DO_ZOOM, botao.position)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				_arrastando = botao.pressed
				if botao.pressed:
					_andou = 0.0
				elif _andou < ARRASTO_MINIMO and botao.button_index == MOUSE_BUTTON_LEFT:
					# Arrastou de menos: era clique, e clique escolhe o sprite.
					_escolhe(_sprite_em(botao.position))

	elif evento is InputEventMouseMotion and _arrastando:
		var movimento: InputEventMouseMotion = evento
		_andou += movimento.relative.length()
		_deslocamento += movimento.relative
		_tela.queue_redraw()


func _muda_zoom(fator: float, ancora: Vector2 = Vector2.INF) -> void:
	if _textura == null:
		return

	var antes: float = _zoom_efetivo()
	var ponto: Vector2 = ancora if ancora.is_finite() else _tela.size * 0.5
	# Onde o cursor estava sobre a folha, em pixels da folha: é esse ponto que
	# tem de continuar embaixo do cursor depois do zoom.
	var na_folha: Vector2 = (ponto - _canto(antes)) / antes

	_zoom = clampf(antes * fator, ZOOM_MINIMO, ZOOM_MAXIMO)
	_deslocamento = Vector2.ZERO
	_deslocamento = ponto - (na_folha * _zoom + _canto(_zoom))
	_tela.queue_redraw()
	_atualiza_rotulo_de_zoom()


func _ajusta_o_enquadramento() -> void:
	_zoom = 0.0
	_deslocamento = Vector2.ZERO
	_tela.queue_redraw()
	_atualiza_rotulo_de_zoom()


## Com `_zoom` em 0 a folha se ajusta sozinha ao espaço; a partir do primeiro
## zoom manual, o valor pedido manda.
func _zoom_efetivo() -> float:
	if _zoom > 0.0:
		return _zoom
	if _textura == null:
		return 1.0
	var tamanho: Vector2 = _textura.get_size()
	if tamanho.x <= 0 or tamanho.y <= 0:
		return 1.0
	return clampf(minf((_tela.size.x - MARGEM * 2) / tamanho.x,
		(_tela.size.y - MARGEM * 2) / tamanho.y), ZOOM_MINIMO, ZOOM_MAXIMO)


func _canto(zoom: float) -> Vector2:
	if _textura == null:
		return Vector2.ZERO
	return ((_tela.size - _textura.get_size() * zoom) * 0.5).floor() + _deslocamento


func _sprite_em(ponto: Vector2) -> int:
	var zoom: float = _zoom_efetivo()
	var canto: Vector2 = _canto(zoom)
	# De trás para a frente: o desenhado por último é o que está por cima.
	for i in range(_pecas.size() - 1, -1, -1):
		var area: Rect2i = _pecas[i].area
		if Rect2(canto + Vector2(area.position) * zoom, Vector2(area.size) * zoom).has_point(ponto):
			return i
	return -1


func _atualiza_rotulo_de_zoom() -> void:
	var zoom: float = _zoom_efetivo()
	_rotulo_zoom.text = ("zoom %s  •  roda: zoom  •  arrastar: mover  •  clique: escolher"
		% ("%d×" % roundi(zoom) if zoom >= 1.0 else "%.0f%%" % (zoom * 100.0)))


# --- resumo e gravação ---------------------------------------------------

func _atualiza_resumo() -> void:
	var linhas: PackedStringArray = PackedStringArray()

	if _folha_original == null:
		linhas.append("[color=#%s]abra uma folha para começar[/color]" % COR_ALERTA.to_html(false))
	else:
		linhas.append("[b]%d sprites[/b]" % _pecas.size())
		linhas.append_array(_linhas_de_destino())
		linhas.append_array(_linhas_de_tamanho())

	_resumo.text = "\n".join(linhas)
	_botao_gravar.disabled = _folha_original == null or _pecas.is_empty() or not _problemas().is_empty()


## Uma linha por pasta, com quantos vão para cada uma. É a conferência final da
## folha misturada: dá para ver de relance que as culturas foram para
## `crops/cenoura` e que o pão não foi junto.
func _linhas_de_destino() -> PackedStringArray:
	var por_pasta: Dictionary = {}
	for peca in _pecas:
		var destino: String = peca.pasta(_slug.text)
		por_pasta[destino] = int(por_pasta.get(destino, 0)) + 1

	var linhas: PackedStringArray = PackedStringArray()
	for destino: String in por_pasta:
		linhas.append("%d → %s" % [por_pasta[destino], destino])

	for problema in _problemas():
		linhas.append("[color=#%s]%s[/color]" % [COR_ERRO.to_html(false), problema])
	return linhas


## O que impede de gravar. Nome repetido é o pior deles: dois sprites com o
## mesmo nome na mesma pasta viram um arquivo só, em silêncio.
func _problemas() -> PackedStringArray:
	var problemas: PackedStringArray = PackedStringArray()
	var vistos: Dictionary = {}
	var repetidos: int = 0
	var sem_nome: int = 0
	var sem_cultura: int = 0

	for peca in _pecas:
		if peca.nome.is_empty():
			sem_nome += 1
			continue
		if peca.tipo == DestinoArte.Tipo.LIVRE:
			continue
		if (peca.tipo == DestinoArte.Tipo.CULTURA
				and DestinoArte.slug_do_nome(peca.nome).is_empty()
				and DestinoArte.normaliza_slug(_slug.text).is_empty()):
			sem_cultura += 1
		var caminho: String = peca.arquivo(_slug.text)
		if vistos.has(caminho):
			repetidos += 1
		vistos[caminho] = true

	if sem_nome > 0:
		problemas.append("%d sem nome" % sem_nome)
	if repetidos > 0:
		problemas.append("%d nomes repetidos na mesma pasta" % repetidos)
	if sem_cultura > 0:
		problemas.append("%d culturas sem nome de cultura" % sem_cultura)
	return problemas


func _linhas_de_tamanho() -> PackedStringArray:
	var linhas: PackedStringArray = PackedStringArray()
	var celula: int = int(_celula.value)
	var maior: Vector2i = Vector2i.ZERO
	var fora: int = 0
	for peca in _pecas:
		if peca.imagem != null:
			maior = maior.max(peca.imagem.get_size())
		if peca.passou_da_celula(celula):
			fora += 1

	if celula <= 0:
		linhas.append("saem no tamanho justo, o maior com %dpx" % maxi(maior.x, maior.y))
	elif fora > 0:
		linhas.append("[color=#%s]%d não cabem em %d e saem com %dpx — ligue \"reduzir para caber\"[/color]"
			% [COR_ALERTA.to_html(false), fora, celula, maxi(maior.x, maior.y)])
	else:
		linhas.append("[color=#%s]todos saem %d×%d[/color]" % [COR_OK.to_html(false), celula, celula])
	return linhas


func _grava() -> void:
	var existentes: PackedStringArray = PackedStringArray()
	var pastas: Dictionary = {}
	for peca in _pecas:
		pastas[peca.pasta(_slug.text)] = true
		if FileAccess.file_exists(peca.arquivo(_slug.text)):
			existentes.append(peca.nome + ".png")

	for pasta: String in pastas:
		var erro: int = DirAccess.make_dir_recursive_absolute(pasta)
		if erro != OK and erro != ERR_ALREADY_EXISTS:
			_avisa("não consegui criar a pasta %s (código %d)" % [pasta, erro])
			return

	if existentes.is_empty():
		_grava_de_fato()
		return

	# Arte é trabalho manual: só sobrescreve depois de perguntar, com a lista do
	# que seria apagado na frente.
	var pergunta: ConfirmationDialog = ConfirmationDialog.new()
	pergunta.title = "Já existem arquivos com esses nomes"
	pergunta.dialog_text = ("%d arquivos serão substituídos:\n\n%s\n\nSubstituir?"
		% [existentes.size(), "\n".join(existentes)])
	pergunta.ok_button_text = "Substituir"
	pergunta.cancel_button_text = "Cancelar"
	pergunta.confirmed.connect(_grava_de_fato)
	pergunta.visibility_changed.connect(func() -> void:
		if not pergunta.visible:
			pergunta.queue_free())
	add_child(pergunta)
	pergunta.popup_centered()


func _grava_de_fato() -> void:
	var escritos: int = 0
	var pastas: Dictionary = {}
	for peca in _pecas:
		if peca.imagem == null:
			continue
		if peca.imagem.save_png(peca.arquivo(_slug.text)) == OK:
			escritos += 1
			pastas[peca.pasta(_slug.text)] = true

	var recado: String = "%d PNGs gravados em %d pastas:\n\n%s" % [
		escritos, pastas.size(), "\n".join(PackedStringArray(pastas.keys()))]
	recado += "\n\nRode `godot --headless --import` para a Godot enxergar os arquivos."
	_avisa(recado)


func _avisa(texto: String) -> void:
	var caixa: AcceptDialog = AcceptDialog.new()
	caixa.title = "Fatiador"
	caixa.dialog_text = texto
	caixa.visibility_changed.connect(func() -> void:
		if not caixa.visible:
			caixa.queue_free())
	add_child(caixa)
	caixa.popup_centered()


# --- a folha na tela -----------------------------------------------------

func _desenha_tela() -> void:
	var fonte: Font = ThemeDB.fallback_font
	if _textura == null:
		_tela.draw_string(fonte, Vector2(MARGEM * 2, _tela.size.y / 2),
			"Abra uma folha de sprites para vê-la aqui.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.45))
		return

	var zoom: float = _zoom_efetivo()
	var canto: Vector2 = _canto(zoom)
	var moldura: Rect2 = Rect2(canto, _textura.get_size() * zoom)

	_desenha_xadrez(moldura, maxf(4.0, zoom * 2.0))
	_tela.draw_texture_rect(_textura, moldura, false)

	for i in _pecas.size():
		var area: Rect2i = _pecas[i].area
		var caixa: Rect2 = Rect2(canto + Vector2(area.position) * zoom, Vector2(area.size) * zoom)
		var escolhido: bool = i == _escolhido
		_tela.draw_rect(caixa, COR_ESCOLHIDO if escolhido else COR_RECORTE, false,
			2.0 if escolhido else 1.0)
		_tela.draw_string(fonte, caixa.position + Vector2(2, -3), str(i),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			COR_ESCOLHIDO if escolhido else Color(1, 1, 1, 0.85))

	if _escolhido >= 0 and _escolhido < _pecas.size():
		_tela.draw_string(fonte, Vector2(MARGEM, _tela.size.y - MARGEM),
			"escolhido: %d — %s" % [_escolhido, _pecas[_escolhido].nome],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COR_ESCOLHIDO)


## Xadrez atrás da folha: sem ele não dá para distinguir fundo transparente de
## fundo preto, que é exatamente o que precisa ser conferido aqui.
func _desenha_xadrez(moldura: Rect2, lado: float) -> void:
	var visivel: Rect2 = moldura.intersection(Rect2(Vector2.ZERO, _tela.size))
	if visivel.size.x <= 0 or visivel.size.y <= 0:
		return

	var primeira_coluna: int = int(floorf((visivel.position.x - moldura.position.x) / lado))
	var primeira_linha: int = int(floorf((visivel.position.y - moldura.position.y) / lado))
	var colunas: int = ceili(visivel.size.x / lado) + 1
	var linhas: int = ceili(visivel.size.y / lado) + 1

	for linha in range(primeira_linha, primeira_linha + linhas):
		for coluna in range(primeira_coluna, primeira_coluna + colunas):
			var quadro: Rect2 = Rect2(
				moldura.position + Vector2(coluna * lado, linha * lado),
				Vector2(lado, lado)).intersection(visivel)
			if quadro.size.x > 0 and quadro.size.y > 0:
				_tela.draw_rect(quadro, COR_XADREZ_A if (coluna + linha) % 2 == 0 else COR_XADREZ_B)
