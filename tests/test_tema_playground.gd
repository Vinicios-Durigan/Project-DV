extends GutTest

## O tema tem que carregar do `.tres` já montado. É o teste que impede o modo
## de falha silencioso desta wave: um `Theme` que carrega vazio não quebra nada
## — os painéis só ficam com a cara padrão do Godot e ninguém percebe até
## abrir a janela.
##
## Também é aqui que se prova a decisão do arquivo: o tema **não guarda cor**,
## ele lê a `paleta.gd`. Se alguém salvar o `.tres` pelo editor com as cores
## cravadas dentro, a comparação com a paleta continua passando — mas o teste
## do arquivo cru pega.

const CAMINHO: String = "res://game/dev/tema_playground.tres"

var _tema: Theme


func before_all() -> void:
	_tema = load(CAMINHO) as Theme


func test_o_tres_carrega_e_e_o_tema_do_playground() -> void:
	assert_not_null(_tema, "o .tres não carregou")
	assert_true(_tema is TemaPlayground, "o .tres perdeu o script que o monta")

func test_o_tres_nao_guarda_cor_nenhuma() -> void:
	# Cor cravada no arquivo é a paleta deixando de mandar no tema.
	var cru := FileAccess.get_file_as_string(CAMINHO)
	assert_false(cru.contains("Color("), "cor cravada no .tres — o tema tem que ler a paleta")
	assert_false(cru.contains("StyleBoxFlat"), "estilo cravado no .tres — quem monta é o script")

func test_o_botao_tem_os_cinco_estados() -> void:
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_not_null(_tema.get_stylebox(estado, "Button"),
			"botão sem estado '%s'" % estado)

func test_o_botao_veste_a_paleta() -> void:
	var normal := _tema.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_eq(normal.bg_color, Paleta.PAINEL_2, "botão em repouso é painel-2")
	assert_eq(normal.corner_radius_top_left, Paleta.RAIO, "o raio é único: 4")
	assert_eq(_tema.get_color("font_color", "Button"), Paleta.TINTA)

func test_o_primario_e_verde_com_tinta_escura() -> void:
	var normal := _tema.get_stylebox("normal", "BotaoPrimario") as StyleBoxFlat
	assert_eq(normal.bg_color, Paleta.VERDE)
	assert_eq(_tema.get_color("font_color", "BotaoPrimario"), Paleta.TINTA_SOBRE_VERDE,
		"o único texto escuro da tela é o que fica sobre o verde")

func test_as_quatro_regioes_do_layout_existem() -> void:
	for regiao in ["Barra", "Rail", "Inspetor", "Diario"]:
		var caixa := _tema.get_stylebox("panel", regiao) as StyleBoxFlat
		assert_not_null(caixa, "região '%s' sem estilo" % regiao)
		assert_eq(caixa.bg_color, Paleta.PAINEL, "região '%s' fora da paleta" % regiao)

func test_o_relogio_e_ceu_e_o_dinheiro_e_ouro() -> void:
	# A regra do dono, no tema: nenhum painel precisa lembrar dela.
	assert_eq(_tema.get_color("font_color", "Relogio"), Paleta.CEU)
	assert_eq(_tema.get_color("font_color", "Dinheiro"), Paleta.OURO)

func test_as_fontes_do_design_system_estao_no_repo() -> void:
	# Sem os .ttf o tema não quebra, mas número deixa de ser mono — e essa é
	# uma decisão aprovada, não um detalhe.
	for arquivo in [TemaPlayground.FONTE_UI, TemaPlayground.FONTE_DADO]:
		assert_true(ResourceLoader.exists("%s/%s" % [TemaPlayground.PASTA_FONTES, arquivo]),
			"fonte %s ausente — número em mono é decisão do design system" % arquivo)

func test_o_numero_usa_a_familia_mono() -> void:
	var dado := _tema.get_font("font", "Dado")
	var relogio := _tema.get_font("font", "Relogio")
	assert_not_null(dado, "o dado tem que ter fonte própria")
	assert_eq(dado, relogio, "relógio e dado são a mesma família mono")
