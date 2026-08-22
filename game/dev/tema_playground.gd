class_name TemaPlayground
extends Theme

## O tema do playground, montado em código a partir da `paleta.gd`.
##
## ## Por que um `Theme` com script, e não um `.tres` de cores cravadas
##
## A decisão da wave 11 é "nenhum nó pinta cor na mão; trocar o tema inteiro é
## editar um arquivo". Um `.tres` salvo pelo editor guarda **cópias** das cores
## dentro de cada `StyleBoxFlat` — mudar a paleta deixaria de mudar o tema, e a
## decisão morreria em silêncio na primeira troca de cor.
##
## Então `tema_playground.tres` existe (é o recurso que a cena carrega e o que o
## editor mostra), mas ele não guarda cor nenhuma: guarda só o script que monta
## tudo a partir da `Paleta` no `_init`.
##
## ## O que o tema resolve
##
## Botão, painel e pílula em todos os estados — normal, hover, pressed,
## disabled, focus. Aplicado na raiz da janela do playground, os painéis herdam
## e nenhum deles precisa saber que existe um tema.
##
## As **variações** (`theme_type_variation`) são o vocabulário do design system
## em nome de nó: `BotaoPrimario`, `Barra`, `Relogio`, `PilulaVerde`. Um painel
## novo nasce vestido escolhendo a variação certa — sem `add_theme_*_override`,
## que é a forma de pintar na mão com outro nome.
##
## Não entra no jogo final: `game/dev/` é ferramenta de time.

const PASTA_FONTES: String = "res://assets/ui/fontes"
const FONTE_UI: String = "FamiljenGrotesk-Regular.ttf"
const FONTE_UI_FORTE: String = "FamiljenGrotesk-SemiBold.ttf"
const FONTE_UI_TITULO: String = "FamiljenGrotesk-Bold.ttf"
const FONTE_DADO: String = "JetBrainsMono-Regular.ttf"
const FONTE_DADO_FORTE: String = "JetBrainsMono-Bold.ttf"

## Espaço interno do botão: 8 na vertical, 18 na horizontal (grade de 4, com o
## 18 herdado do mock por ser o único ímpar que o design system fixa).
const RESPIRO_BOTAO_V: int = 8
const RESPIRO_BOTAO_H: int = 18


func _init() -> void:
	_monta_fontes()
	_monta_botoes()
	_monta_paineis()
	_monta_pilulas()
	_monta_textos()
	_monta_containers()


# --- Fontes ---

## Fonte que existe no disco, ou `null`. Sem os `.ttf`, o tema cai na fonte
## padrão do Godot e tudo continua funcionando — feio, não quebrado.
func _fonte(arquivo: String) -> Font:
	var caminho := "%s/%s" % [PASTA_FONTES, arquivo]
	if not ResourceLoader.exists(caminho):
		return null
	return load(caminho) as Font

func _monta_fontes() -> void:
	default_font_size = Paleta.TAMANHO_ROTULO
	var ui := _fonte(FONTE_UI)
	if ui != null:
		default_font = ui

	# Número é sempre mono: relógio, dinheiro, cota, coordenada. Quem carrega a
	# variação certa é o painel; a família vem daqui.
	var dado := _fonte(FONTE_DADO)
	var dado_forte := _fonte(FONTE_DADO_FORTE)
	var forte := _fonte(FONTE_UI_FORTE)
	var titulo := _fonte(FONTE_UI_TITULO)

	for variacao in ["Dado", "Relogio", "Micro"]:
		_fonte_de("Label", variacao, dado, Paleta.TAMANHO_DADO)
	_fonte_de("Label", "Dinheiro", dado_forte, Paleta.TAMANHO_DADO)
	_fonte_de("Label", "Titulo", titulo, Paleta.TAMANHO_TITULO)
	_fonte_de("Label", "Rotulo", forte, Paleta.TAMANHO_ROTULO)
	_fonte_de("RichTextLabel", "Diario", dado, Paleta.TAMANHO_DADO)
	_fonte_de("Button", "BotaoPrimario", forte, Paleta.TAMANHO_ROTULO)
	_fonte_de("Button", "Truque", forte, Paleta.TAMANHO_DADO)

	# O micro-rótulo é mono em caixa alta e pequeno: quem escreve o texto em
	# maiúsculas é o painel — fonte não faz caixa.
	set_font_size("font_size", "Micro", Paleta.TAMANHO_MICRO)

func _fonte_de(tipo: String, variacao: String, fonte: Font, tamanho: int) -> void:
	set_type_variation(variacao, tipo)
	set_font_size("font_size", variacao, tamanho)
	if fonte != null:
		set_font("font", variacao, fonte)


# --- Caixas ---

## Uma `StyleBoxFlat` da paleta: fundo, borda e o raio único de 4.
func _caixa(fundo: Color, borda: Color = Paleta.NADA, espessura: int = Paleta.BORDA,
		raio: int = Paleta.RAIO) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = fundo
	caixa.set_border_width_all(espessura if borda.a > 0.0 else 0)
	caixa.border_color = borda
	caixa.set_corner_radius_all(raio)
	return caixa

## Painel de região: sem raio e com borda de um lado só — é o que separa a barra
## do rail, e o rail do mundo, sem desenhar caixinha dentro de caixinha.
func _faixa(lado: Side) -> StyleBoxFlat:
	var caixa := _caixa(Paleta.PAINEL, Paleta.LINHA, Paleta.BORDA, 0)
	caixa.set_border_width_all(0)
	caixa.set_border_width(lado, Paleta.BORDA)
	caixa.border_color = Paleta.LINHA
	return caixa

func _respiro(caixa: StyleBoxFlat, vertical: int, horizontal: int) -> StyleBoxFlat:
	caixa.content_margin_top = vertical
	caixa.content_margin_bottom = vertical
	caixa.content_margin_left = horizontal
	caixa.content_margin_right = horizontal
	return caixa


# --- Botões ---

## Os cinco estados, uma vez só. `focus` é borda verde de 2px por cima do que
## já está: o teclado precisa mostrar onde está, e o playground é jogado com as
## duas mãos.
func _estados_de_botao(variacao: String, normal: StyleBoxFlat, hover: StyleBoxFlat,
		pressionado: StyleBoxFlat, desligado: StyleBoxFlat) -> void:
	set_stylebox("normal", variacao, _respiro(normal, RESPIRO_BOTAO_V, RESPIRO_BOTAO_H))
	set_stylebox("hover", variacao, _respiro(hover, RESPIRO_BOTAO_V, RESPIRO_BOTAO_H))
	set_stylebox("pressed", variacao, _respiro(pressionado, RESPIRO_BOTAO_V, RESPIRO_BOTAO_H))
	set_stylebox("disabled", variacao, _respiro(desligado, RESPIRO_BOTAO_V, RESPIRO_BOTAO_H))

	var foco := _caixa(Paleta.NADA, Paleta.VERDE, Paleta.BORDA_FOCO)
	set_stylebox("focus", variacao, _respiro(foco, RESPIRO_BOTAO_V, RESPIRO_BOTAO_H))

## O slot é quadrado e o texto mora dentro dele: respiro pequeno e igual nos
## dois eixos, senão a grade deixa de ser grade.
func _estados_de_slot(variacao: String, repouso: StyleBoxFlat, aceso: StyleBoxFlat) -> void:
	set_stylebox("normal", variacao, _respiro(repouso, Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	set_stylebox("hover", variacao, _respiro(aceso, Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	set_stylebox("pressed", variacao,
		_respiro(_caixa(Paleta.PAINEL_3, Paleta.VERDE, Paleta.BORDA_FOCO),
			Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	set_stylebox("disabled", variacao,
		_respiro(_caixa(Paleta.FUNDO, Paleta.LINHA), Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	set_stylebox("focus", variacao,
		_respiro(_caixa(Paleta.NADA, Paleta.VERDE, Paleta.BORDA_FOCO),
			Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))

func _monta_botoes() -> void:
	# Secundário é o padrão: o botão comum do playground.
	_estados_de_botao("Button",
		_caixa(Paleta.PAINEL_2, Paleta.LINHA_2),
		_caixa(Paleta.PAINEL_3, Paleta.LINHA_2),
		_caixa(Paleta.PAINEL_3, Paleta.VERDE),
		_caixa(Paleta.PAINEL_2, Paleta.LINHA))
	set_color("font_color", "Button", Paleta.TINTA)
	set_color("font_hover_color", "Button", Paleta.TINTA)
	set_color("font_pressed_color", "Button", Paleta.VERDE)
	set_color("font_focus_color", "Button", Paleta.TINTA)
	# Desabilitado é raro de propósito: regra de jogo nunca desabilita botão — o
	# clique vai à sim e a recusa volta em toast. Desabilitado é só
	# impossibilidade de interface.
	set_color("font_disabled_color", "Button", Paleta.TINTA_3)

	# Primário: um por painel, a ação que o jogador provavelmente quer.
	set_type_variation("BotaoPrimario", "Button")
	_estados_de_botao("BotaoPrimario",
		_caixa(Paleta.VERDE),
		_caixa(Paleta.VERDE.lightened(0.10)),
		_caixa(Paleta.VERDE.darkened(0.12)),
		_caixa(Paleta.PAINEL_2, Paleta.LINHA))
	set_color("font_color", "BotaoPrimario", Paleta.TINTA_SOBRE_VERDE)
	set_color("font_hover_color", "BotaoPrimario", Paleta.TINTA_SOBRE_VERDE)
	set_color("font_pressed_color", "BotaoPrimario", Paleta.TINTA_SOBRE_VERDE)
	set_color("font_disabled_color", "BotaoPrimario", Paleta.TINTA_3)

	# Perigo: contorno de alerta, fundo só no hover. Arrancar cultura, apagar
	# save — o que dói se for sem querer.
	set_type_variation("BotaoPerigo", "Button")
	_estados_de_botao("BotaoPerigo",
		_caixa(Paleta.NADA, Paleta.ALERTA),
		_caixa(Paleta.veu(Paleta.ALERTA), Paleta.ALERTA),
		_caixa(Paleta.veu(Paleta.ALERTA, 0.24), Paleta.ALERTA),
		_caixa(Paleta.PAINEL_2, Paleta.LINHA))
	set_color("font_color", "BotaoPerigo", Paleta.ALERTA)
	set_color("font_hover_color", "BotaoPerigo", Paleta.ALERTA)
	set_color("font_pressed_color", "BotaoPerigo", Paleta.ALERTA)

	# Truque: botão do rail, texto pequeno e alinhado à esquerda.
	set_type_variation("Truque", "Button")
	set_stylebox("normal", "Truque",
		_respiro(_caixa(Paleta.PAINEL_2, Paleta.LINHA), 6, 10))
	set_stylebox("hover", "Truque",
		_respiro(_caixa(Paleta.PAINEL_3, Paleta.LINHA_2), 6, 10))
	set_stylebox("pressed", "Truque",
		_respiro(_caixa(Paleta.PAINEL_3, Paleta.VERDE), 6, 10))
	set_stylebox("disabled", "Truque",
		_respiro(_caixa(Paleta.PAINEL_2, Paleta.LINHA), 6, 10))
	set_stylebox("focus", "Truque",
		_respiro(_caixa(Paleta.NADA, Paleta.VERDE, Paleta.BORDA_FOCO), 6, 10))
	set_color("font_color", "Truque", Paleta.TINTA_2)
	set_color("font_hover_color", "Truque", Paleta.TINTA)
	set_color("font_pressed_color", "Truque", Paleta.VERDE)

	# Slot de mochila. O vazio é um buraco na grade — fundo afundado e borda
	# discreta; ele existe para a capacidade ser vista antes de acabar.
	set_type_variation("Slot", "Button")
	_estados_de_slot("Slot",
		_caixa(Paleta.FUNDO, Paleta.LINHA),
		_caixa(Paleta.FUNDO, Paleta.LINHA))
	set_color("font_disabled_color", "Slot", Paleta.TINTA_3)

	# Slot cheio: sobe uma superfície e ganha borda de controle. Hover e
	# pressionado usam o verde da ação, porque clicar aqui É a ação.
	set_type_variation("SlotCheio", "Button")
	_estados_de_slot("SlotCheio",
		_caixa(Paleta.PAINEL_2, Paleta.LINHA_2),
		_caixa(Paleta.PAINEL_3, Paleta.VERDE))
	# O slot que está na mão. Precisa ser óbvio de relance, sem ler o texto: é a
	# resposta para "o que este clique vai fazer?". Três sinais, como a cultura
	# pronta — fundo aceso, borda verde grossa e texto verde.
	set_type_variation("SlotNaMao", "Button")
	var na_mao := _caixa(Paleta.veu(Paleta.VERDE, 0.22), Paleta.VERDE, Paleta.BORDA_FOCO)
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		set_stylebox(estado, "SlotNaMao",
			_respiro(_caixa(Paleta.veu(Paleta.VERDE, 0.22), Paleta.VERDE, Paleta.BORDA_FOCO),
				Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	set_stylebox("normal", "SlotNaMao",
		_respiro(na_mao, Paleta.ESPACO_ITEM, Paleta.ESPACO_ITEM))
	for cor in ["font_color", "font_hover_color", "font_pressed_color",
			"font_disabled_color", "font_focus_color"]:
		set_color(cor, "SlotNaMao", Paleta.VERDE)
	set_font_size("font_size", "SlotNaMao", Paleta.TAMANHO_DADO)

	set_color("font_color", "SlotCheio", Paleta.TINTA)
	set_color("font_hover_color", "SlotCheio", Paleta.VERDE)
	set_color("font_pressed_color", "SlotCheio", Paleta.VERDE)
	set_font_size("font_size", "SlotCheio", Paleta.TAMANHO_DADO)
	set_font_size("font_size", "Slot", Paleta.TAMANHO_DADO)

	# A caixinha de "mostrar minutos" segue o mesmo texto dos rótulos.
	set_color("font_color", "CheckBox", Paleta.TINTA_2)
	set_color("font_hover_color", "CheckBox", Paleta.TINTA)
	set_color("font_pressed_color", "CheckBox", Paleta.VERDE)


# --- Painéis ---

func _monta_paineis() -> void:
	for tipo in ["Panel", "PanelContainer"]:
		set_stylebox("panel", tipo,
			_respiro(_caixa(Paleta.PAINEL, Paleta.LINHA), Paleta.RESPIRO, Paleta.RESPIRO))

	# As quatro regiões do layout aprovado. Cada uma é uma faixa com borda de um
	# lado só, na direção de quem ela separa.
	_regiao("Barra", SIDE_BOTTOM, 10, Paleta.RESPIRO_LARGO)
	_regiao("Rail", SIDE_RIGHT, Paleta.RESPIRO + 2, Paleta.RESPIRO)
	_regiao("Inspetor", SIDE_LEFT, Paleta.RESPIRO + 2, Paleta.RESPIRO + 2)
	_regiao("Diario", SIDE_TOP, Paleta.ESPACO_CONTROLE, Paleta.RESPIRO_LARGO)

	# O mundo não é painel: é o chão da janela, e quem pinta terreno é o
	# `MundoEsboco` com a paleta.
	set_type_variation("Mundo", "PanelContainer")
	set_stylebox("panel", "Mundo", _caixa(Paleta.FUNDO, Paleta.NADA, 0, 0))

	# O véu do modal: o fundo escurecido que separa o painel do mundo e come o
	# clique. Escurece em vez de borrar — borrão custa shader, e o playground
	# não paga por enfeite.
	set_type_variation("Veu", "PanelContainer")
	set_stylebox("panel", "Veu", _caixa(Paleta.veu(Paleta.FUNDO, 0.82), Paleta.NADA, 0, 0))

	# A janela do modal: painel com respiro largo e borda forte, para se
	# descolar do véu.
	set_type_variation("Janela", "PanelContainer")
	set_stylebox("panel", "Janela", _respiro(
		_caixa(Paleta.PAINEL, Paleta.LINHA_2), Paleta.ESPACO_GRUPO, Paleta.ESPACO_GRUPO))

	# ScrollContainer sem moldura: a moldura é da região que o contém.
	set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

func _regiao(variacao: String, lado: Side, vertical: int, horizontal: int) -> void:
	set_type_variation(variacao, "PanelContainer")
	set_stylebox("panel", variacao, _respiro(_faixa(lado), vertical, horizontal))


# --- Pílulas ---

## Etiqueta de estado: "pronta", "contrato ativo", "em obra · 2 dias". Cor do
## assunto no texto e na borda, o mesmo assunto a 12% no fundo.
func _monta_pilulas() -> void:
	_pilula("PilulaVerde", Paleta.VERDE)
	_pilula("PilulaTerra", Paleta.TERRA)
	_pilula("PilulaOuro", Paleta.OURO)
	_pilula("PilulaAlerta", Paleta.ALERTA)

	set_type_variation("PilulaNeutra", "PanelContainer")
	set_stylebox("panel", "PilulaNeutra",
		_respiro(_caixa(Paleta.PAINEL_2, Paleta.LINHA_2, Paleta.BORDA, 3), 3, 8))

	# O toast de recusa: painel com contorno de alerta e a borda esquerda
	# grossa. A barra da esquerda é o que faz o olho achá-lo no canto da tela
	# sem ler — a cor sozinha não bastaria.
	set_type_variation("Toast", "PanelContainer")
	var toast := _caixa(Paleta.PAINEL, Paleta.ALERTA)
	toast.border_width_left = 3
	set_stylebox("panel", "Toast", _respiro(toast, Paleta.ESPACO_CONTROLE, 14))

func _pilula(variacao: String, dono: Color) -> void:
	set_type_variation(variacao, "PanelContainer")
	set_stylebox("panel", variacao,
		_respiro(_caixa(Paleta.veu(dono), dono, Paleta.BORDA, 3), 3, 8))


# --- Texto ---

func _monta_textos() -> void:
	set_color("font_color", "Label", Paleta.TINTA)
	set_color("default_color", "RichTextLabel", Paleta.TINTA_2)
	set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	set_stylebox("normal", "Diario", StyleBoxEmpty.new())
	set_color("default_color", "Diario", Paleta.TINTA_2)

	# Cada rótulo com dono: o relógio é céu, o dinheiro é ouro, o micro é a
	# tinta apagada. Nenhum painel precisa lembrar disso.
	set_color("font_color", "Titulo", Paleta.TINTA)
	set_color("font_color", "Rotulo", Paleta.TINTA)
	set_color("font_color", "Dado", Paleta.TINTA)
	set_color("font_color", "Relogio", Paleta.CEU)
	set_color("font_color", "Dinheiro", Paleta.OURO)
	set_color("font_color", "Micro", Paleta.TINTA_3)
	set_font_size("font_size", "Micro", Paleta.TAMANHO_MICRO)

	# O texto do toast: alerta é o dono da recusa, e é o único texto vermelho
	# da tela.
	set_type_variation("Recusa", "Label")
	set_color("font_color", "Recusa", Paleta.ALERTA)
	set_font_size("font_size", "Recusa", Paleta.TAMANHO_ROTULO)


# --- Espaço ---

## A grade de 4px vira separação de container: 4 dentro de um grupo, 8 entre
## controles. Painel que quiser outro respiro usa `MarginContainer`, não
## override de cor.
func _monta_containers() -> void:
	set_constant("separation", "VBoxContainer", Paleta.ESPACO_ITEM)
	set_constant("separation", "HBoxContainer", Paleta.ESPACO_CONTROLE)
	set_constant("h_separation", "HFlowContainer", Paleta.ESPACO_ITEM)
	set_constant("v_separation", "HFlowContainer", Paleta.ESPACO_ITEM)

	set_type_variation("Grupo", "VBoxContainer")
	set_constant("separation", "Grupo", Paleta.ESPACO_ITEM)
	set_type_variation("Grupos", "VBoxContainer")
	set_constant("separation", "Grupos", Paleta.ESPACO_GRUPO)
