extends GutTest

## `tools/fatiador.gd` é ferramenta de pipeline de arte, não regra de jogo — mas
## ganha teste pelo mesmo motivo que `sim/` ganha: erro dele é silencioso. Corte
## torto não quebra nada, só chega na hotbar semanas depois com o ícone fora de
## lugar, quando ninguém mais lembra de onde o PNG veio.
##
## Toda folha aqui é desenhada em código: teste de imagem que depende de arquivo
## em disco quebra quando o artista mexe no arquivo.

const FUNDO: Color = Color(0.17, 0.17, 0.19)
const TRANSPARENTE: Color = Color(0, 0, 0, 0)

var _fatiador: Fatiador


func before_each() -> void:
	_fatiador = Fatiador.new()


## Uma folha 64×40 com fundo chapado e quatro desenhos: três na linha de cima,
## um na de baixo feito de dois pedaços separados por 2px de vão.
func _folha_de_exemplo() -> Image:
	var imagem: Image = Image.create_empty(64, 40, false, Image.FORMAT_RGBA8)
	imagem.fill(FUNDO)
	imagem.fill_rect(Rect2i(2, 2, 8, 8), Color.RED)
	imagem.fill_rect(Rect2i(20, 3, 10, 6), Color.GREEN)
	imagem.fill_rect(Rect2i(40, 2, 6, 9), Color.BLUE)
	imagem.fill_rect(Rect2i(4, 22, 6, 6), Color.YELLOW)
	imagem.fill_rect(Rect2i(12, 24, 3, 3), Color.YELLOW)
	return imagem


func _folha_transparente() -> Image:
	var imagem: Image = Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	imagem.fill(TRANSPARENTE)
	imagem.fill_rect(Rect2i(2, 2, 4, 4), Color.RED)
	imagem.fill_rect(Rect2i(20, 5, 8, 8), Color.BLUE)
	return imagem


# --- fundo ---------------------------------------------------------------

func test_detecta_a_cor_de_fundo_pela_moldura() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	assert_almost_eq(_fatiador.cor_de_fundo_provavel().r, FUNDO.r, 0.01)
	assert_almost_eq(_fatiador.cor_de_fundo_provavel().g, FUNDO.g, 0.01)

## Folha que já tem alpha não deve ser mexida — o chamador desiste da remoção
## olhando o alpha da cor devolvida.
func test_folha_ja_transparente_devolve_fundo_sem_alpha() -> void:
	_fatiador.define_imagem(_folha_transparente())
	assert_lt(_fatiador.cor_de_fundo_provavel().a, 0.5, "não há fundo chapado a remover")

func test_remover_o_fundo_deixa_so_o_desenho() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	var pintados: int = 8 * 8 + 10 * 6 + 6 * 9 + 6 * 6 + 3 * 3
	_fatiador.remove_fundo(FUNDO, 4)
	assert_eq(_fatiador.pixels_com_desenho(), pintados, "sobra exatamente o que foi desenhado")

## O modo padrão espalha a partir da moldura. Um buraco da cor do fundo cercado
## pelo desenho — o vão do cabo, o olho preto — continua onde está: se fosse
## apagado por cor, o sprite sairia furado.
func test_fundo_cercado_pelo_desenho_nao_e_apagado() -> void:
	var imagem: Image = Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	imagem.fill(FUNDO)
	imagem.fill_rect(Rect2i(5, 5, 10, 10), Color.RED)
	imagem.fill_rect(Rect2i(9, 9, 2, 2), FUNDO)

	_fatiador.define_imagem(imagem)
	_fatiador.remove_fundo(FUNDO, 4)
	assert_true(_fatiador.tem_desenho(9, 9), "o miolo da cor do fundo faz parte do sprite")
	assert_false(_fatiador.tem_desenho(0, 0), "a moldura foi embora")

func test_fundo_em_tudo_apaga_ate_o_miolo() -> void:
	var imagem: Image = Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	imagem.fill(FUNDO)
	imagem.fill_rect(Rect2i(5, 5, 10, 10), Color.RED)
	imagem.fill_rect(Rect2i(9, 9, 2, 2), FUNDO)

	_fatiador.define_imagem(imagem)
	_fatiador.remove_fundo(FUNDO, 4, false)
	assert_false(_fatiador.tem_desenho(9, 9), "--fundo-em-tudo não poupa o miolo")

## JPEG e gradiente sujam o fundo chapado. Sem tolerância sobraria uma moldura
## de lixo em volta de cada sprite.
func test_tolerancia_pega_fundo_sujo() -> void:
	var imagem: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	imagem.fill(FUNDO)
	imagem.set_pixel(0, 0, Color(FUNDO.r + 0.02, FUNDO.g - 0.02, FUNDO.b + 0.01))
	imagem.fill_rect(Rect2i(6, 6, 4, 4), Color.RED)

	_fatiador.define_imagem(imagem)
	_fatiador.remove_fundo(FUNDO, 12)
	assert_eq(_fatiador.pixels_com_desenho(), 16, "o pixel quase-igual conta como fundo")


# --- achar os sprites ----------------------------------------------------

func test_acha_cada_desenho_da_folha() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	# Raio 3 alcança o vão de 2px e junta o sprite partido em dois pedaços.
	assert_eq(_fatiador.acha_sprites(3, 6).size(), 4, "quatro desenhos, quatro recortes")

## O raio é o botão a mexer quando a contagem sai errada: baixo demais parte um
## sprite em dois.
func test_raio_pequeno_parte_o_sprite_de_pedacos_soltos() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	assert_eq(_fatiador.acha_sprites(1, 6).size(), 5, "o pedaço solto vira um recorte à parte")

func test_recorte_e_justo_no_desenho() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var achados: Array[Rect2i] = Fatiador.em_ordem_de_leitura(_fatiador.acha_sprites(3, 6))
	assert_eq(achados[0], Rect2i(2, 2, 8, 8), "sem uma sobra de fundo em volta")

func test_sujeira_de_um_pixel_e_descartada() -> void:
	var imagem: Image = _folha_de_exemplo()
	imagem.set_pixel(60, 35, Color.WHITE)
	_fatiador.define_imagem(imagem)
	_fatiador.remove_fundo(FUNDO, 4)
	assert_eq(_fatiador.acha_sprites(3, 6).size(), 4, "1 pixel não é sprite")
	assert_eq(_fatiador.acha_sprites(3, 1).size(), 5, "--area-minima=1 aceita até isso")

func test_grade_fixa_joga_fora_a_celula_vazia() -> void:
	var imagem: Image = Image.create_empty(48, 16, false, Image.FORMAT_RGBA8)
	imagem.fill(TRANSPARENTE)
	imagem.fill_rect(Rect2i(2, 2, 8, 8), Color.RED)
	imagem.fill_rect(Rect2i(34, 4, 8, 8), Color.BLUE)

	_fatiador.define_imagem(imagem)
	var celulas: Array[Rect2i] = _fatiador.recorta_por_grade(16)
	assert_eq(celulas.size(), 2, "a célula do meio está vazia e não vira arquivo")
	assert_eq(celulas[0], Rect2i(0, 0, 16, 16), "a célula sai inteira, não aparada")


# --- ordem de leitura ----------------------------------------------------

## É o contrato de `--nomes`: a lista que o artista escreve casa com o que o
## olho dele vê, mesmo com os desenhos desalinhados na linha.
func test_ordem_de_leitura_agrupa_linhas_e_ordena_por_x() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var achados: Array[Rect2i] = Fatiador.em_ordem_de_leitura(_fatiador.acha_sprites(3, 6))

	assert_eq(achados[0].position, Vector2i(2, 2), "linha de cima, primeiro da esquerda")
	assert_eq(achados[1].position, Vector2i(20, 3), "o y maior não o joga para outra linha")
	assert_eq(achados[2].position, Vector2i(40, 2))
	assert_eq(achados[3].position, Vector2i(4, 22), "só então a linha de baixo")


# --- acabamento ----------------------------------------------------------

func test_celula_padroniza_o_tamanho_e_centraliza() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var pedaco: Image = _fatiador.recorte(Rect2i(2, 2, 8, 8), AcabamentoArte.pixel_art(16))

	assert_eq(pedaco.get_size(), Vector2i(16, 16), "sai no padrão do projeto")
	assert_lt(pedaco.get_pixel(3, 3).a, 0.5, "sobra transparente na borda")
	assert_gt(pedaco.get_pixel(8, 8).a, 0.5, "o desenho ficou no meio")
	assert_eq(pedaco.get_pixel(4, 4), Color.RED, "8×8 num canvas 16 começa em (4,4)")

func test_ancora_baixo_encosta_o_sprite_no_chao() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var pedaco: Image = _fatiador.recorte(Rect2i(2, 2, 8, 8),
		AcabamentoArte.pixel_art(16, Fatiador.Ancora.BAIXO))

	assert_gt(pedaco.get_pixel(8, 15).a, 0.5, "a última linha tem desenho")
	assert_lt(pedaco.get_pixel(8, 0).a, 0.5, "e o vazio foi todo para cima")

func test_ancora_por_nome_cai_no_centro_quando_nao_reconhece() -> void:
	assert_eq(Fatiador.ancora_por_nome("baixo"), Fatiador.Ancora.BAIXO)
	assert_eq(Fatiador.ancora_por_nome("topo"), Fatiador.Ancora.TOPO)
	assert_eq(Fatiador.ancora_por_nome("qualquer coisa"), Fatiador.Ancora.CENTRO)

## Arte que veio em 32px vira 16px sem borrar: qualquer filtro que não seja
## nearest inventa cor fora da paleta que o artista escolheu.
func test_escala_reduz_sem_inventar_cor() -> void:
	var imagem: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	imagem.fill(TRANSPARENTE)
	imagem.fill_rect(Rect2i(0, 0, 16, 16), Color.RED)

	_fatiador.define_imagem(imagem)
	var acabamento: AcabamentoArte = AcabamentoArte.pixel_art()
	acabamento.escala = 0.5
	var pedaco: Image = _fatiador.recorte(Rect2i(0, 0, 16, 16), acabamento)
	assert_eq(pedaco.get_size(), Vector2i(8, 8), "metade do tamanho")
	assert_eq(pedaco.get_pixel(4, 4), Color.RED, "vermelho puro, sem tom intermediário")

func test_escala_vem_antes_da_celula() -> void:
	var imagem: Image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	imagem.fill(TRANSPARENTE)
	imagem.fill_rect(Rect2i(0, 0, 32, 32), Color.RED)

	_fatiador.define_imagem(imagem)
	var acabamento: AcabamentoArte = AcabamentoArte.pixel_art(16)
	acabamento.escala = 0.5
	var pedaco: Image = _fatiador.recorte(Rect2i(0, 0, 32, 32), acabamento)
	assert_eq(pedaco.get_size(), Vector2i(16, 16), "32 escalado por 0.5 cabe na célula 16")
	assert_eq(pedaco.get_pixel(8, 8), Color.RED, "e preenche a célula inteira")

## Cortar o desenho para caber seria pior que devolver fora do padrão — o
## artista precisa ver que passou do tamanho.
func test_recorte_maior_que_a_celula_sai_inteiro() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var pedaco: Image = _fatiador.recorte(Rect2i(20, 3, 10, 6), AcabamentoArte.pixel_art(8))
	assert_eq(pedaco.get_size(), Vector2i(10, 6), "sai justo, sem perder pixel")


# --- conferência ---------------------------------------------------------

func test_folha_de_contato_cabe_todos_os_recortes() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	_fatiador.remove_fundo(FUNDO, 4)
	var achados: Array[Rect2i] = Fatiador.em_ordem_de_leitura(_fatiador.acha_sprites(3, 6))
	var folha: Image = _fatiador.folha_de_contato(achados, 2, 20)

	assert_eq(folha.get_size(), Vector2i(40, 40), "4 recortes em 2 colunas = 2 linhas de 20px")
	assert_gt(folha.get_pixel(10, 10).a, 0.5, "a célula tem xadrez de fundo, não vazio")

func test_folha_de_contato_sem_recorte_nao_quebra() -> void:
	_fatiador.define_imagem(_folha_de_exemplo())
	assert_eq(_fatiador.folha_de_contato([] as Array[Rect2i]).get_size(), Vector2i(1, 1))


# --- arte gerada por IA --------------------------------------------------

## Uma imagem grande, com borda suave e muitos tons — o que sai de um gerador de
## imagem ou de pintura digital, e que precisa virar pixel art antes de entrar
## no jogo.
func _arte_suave(lado: int) -> Image:
	var imagem: Image = Image.create_empty(lado, lado, false, Image.FORMAT_RGBA8)
	imagem.fill(TRANSPARENTE)
	var centro: float = lado / 2.0
	for y in lado:
		for x in lado:
			var distancia: float = Vector2(x - centro, y - centro).length() / centro
			if distancia > 0.9:
				continue
			# Gradiente contínuo: cada pixel um tom, como pintura de verdade.
			imagem.set_pixel(x, y, Color(
				0.9 - distancia * 0.5, 0.3 + distancia * 0.4, 0.2,
				clampf((0.9 - distancia) * 6.0, 0.0, 1.0)))
	return imagem

## Reduzir sem tratar deixa a imagem no tamanho certo mas com cara de foto
## encolhida. As três etapas juntas — encaixar, cortar o alfa e cortar a paleta —
## são o que faz virar sprite.
func test_arte_gerada_vira_pixel_art_de_16() -> void:
	_fatiador.define_imagem(_arte_suave(256))
	var achados: Array[Rect2i] = _fatiador.acha_sprites(2, 6)
	assert_eq(achados.size(), 1, "a arte é um desenho só")

	var pedaco: Image = _fatiador.recorte(achados[0], AcabamentoArte.arte_gerada(16))
	assert_eq(pedaco.get_size(), Vector2i(16, 16), "cabe na célula do projeto")
	assert_lte(Fatiador.conta_cores(pedaco), AcabamentoArte.CORES_PADRAO,
		"a paleta foi cortada ao teto")

func test_arte_gerada_perde_o_halo_de_alfa() -> void:
	_fatiador.define_imagem(_arte_suave(256))
	var achados: Array[Rect2i] = _fatiador.acha_sprites(2, 6)
	var pedaco: Image = _fatiador.recorte(achados[0], AcabamentoArte.arte_gerada(16))

	var meio_transparentes: int = 0
	for y in pedaco.get_height():
		for x in pedaco.get_width():
			var alfa: float = pedaco.get_pixel(x, y).a
			if alfa > 0.01 and alfa < 0.99:
				meio_transparentes += 1
	assert_eq(meio_transparentes, 0, "pixel art não tem transparência pela metade")

## `encaixar` é o que separa "não coube, azar" de "não coube, então reduz".
func test_encaixar_reduz_o_que_nao_cabia_na_celula() -> void:
	_fatiador.define_imagem(_arte_suave(128))
	var achados: Array[Rect2i] = _fatiador.acha_sprites(2, 6)

	var justo: Image = _fatiador.recorte(achados[0], AcabamentoArte.pixel_art(16))
	assert_gt(justo.get_width(), 16, "sem encaixar, sai fora do padrão")

	var acabamento: AcabamentoArte = AcabamentoArte.pixel_art(16)
	acabamento.encaixar = true
	assert_eq(_fatiador.recorte(achados[0], acabamento).get_size(), Vector2i(16, 16))

## Proporção preservada: um regador alto não pode sair quadrado.
func test_encaixar_preserva_a_proporcao() -> void:
	var alta: Image = Image.create_empty(64, 128, false, Image.FORMAT_RGBA8)
	alta.fill(Color.RED)
	var encaixada: Image = Fatiador.encaixa(alta, 16, Fatiador.Filtro.SUAVE)
	assert_eq(encaixada.get_size(), Vector2i(8, 16), "o dobro de altura continua o dobro")

func test_encaixar_nao_estica_o_que_ja_cabia() -> void:
	var pequena: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	pequena.fill(Color.RED)
	assert_eq(Fatiador.encaixa(pequena, 16, Fatiador.Filtro.NEAREST).get_size(), Vector2i(8, 8),
		"aumentar pixel art só engorda o desenho, não acrescenta detalhe")

func test_achatar_alfa_obriga_cada_pixel_a_escolher_um_lado() -> void:
	var imagem: Image = Image.create_empty(3, 1, false, Image.FORMAT_RGBA8)
	imagem.set_pixel(0, 0, Color(1, 0, 0, 0.2))
	imagem.set_pixel(1, 0, Color(1, 0, 0, 0.7))
	imagem.set_pixel(2, 0, Color(1, 0, 0, 1.0))

	var achatada: Image = Fatiador.achata_alfa(imagem, 128)
	assert_eq(achatada.get_pixel(0, 0).a, 0.0, "abaixo do corte some")
	assert_eq(achatada.get_pixel(1, 0).a, 1.0, "acima do corte vira opaco")
	assert_eq(achatada.get_pixel(2, 0).a, 1.0)

## O que faz uma imagem parecer pixel art não é só o tamanho — é a contagem de
## cores. Centenas de tons quase iguais viram mancha suja em 16×16.
func test_reduzir_paleta_corta_no_teto_pedido() -> void:
	var imagem: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			imagem.set_pixel(x, y, Color((x * 16) / 255.0, (y * 16) / 255.0, 0.5))
	assert_gt(Fatiador.conta_cores(imagem), 100, "o degradê tem cor demais")

	assert_lte(Fatiador.conta_cores(Fatiador.reduz_paleta(imagem, 8)), 8)

func test_reduzir_paleta_nao_mexe_em_quem_ja_tem_poucas_cores() -> void:
	var imagem: Image = Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	imagem.set_pixel(0, 0, Color.RED)
	imagem.set_pixel(1, 0, Color.GREEN)
	imagem.set_pixel(2, 0, Color.BLUE)
	imagem.set_pixel(3, 0, Color.RED)

	var reduzida: Image = Fatiador.reduz_paleta(imagem, 16)
	assert_eq(reduzida.get_pixel(1, 0), Color.GREEN, "3 cores com teto 16: nada muda")

func test_reduzir_paleta_preserva_o_recorte_do_alfa() -> void:
	var imagem: Image = Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	imagem.set_pixel(0, 0, Color(1, 0, 0, 1))
	imagem.set_pixel(1, 0, Color(0, 0, 0, 0))
	var reduzida: Image = Fatiador.reduz_paleta(imagem, 1)
	assert_eq(reduzida.get_pixel(1, 0).a, 0.0, "o transparente continua transparente")

## Nearest joga fora 99% dos pixels numa redução grande e o que sobra é ruído.
func test_filtro_suave_preserva_a_forma_que_o_nearest_perde() -> void:
	var listrada: Image = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	listrada.fill(Color.BLACK)
	for y in 64:
		for x in 64:
			if x % 2 == 0:
				listrada.set_pixel(x, y, Color.WHITE)

	var suave: Image = Fatiador.redimensiona(listrada, 8, 8, Fatiador.Filtro.SUAVE)
	var duro: Image = Fatiador.redimensiona(listrada, 8, 8, Fatiador.Filtro.NEAREST)
	assert_eq(Fatiador.conta_cores(duro), 1, "nearest pega só as colunas pares: tudo branco")
	assert_gt(Fatiador.conta_cores(suave), 1, "suave faz a média e guarda a informação")


# --- presets de acabamento -----------------------------------------------

func test_preset_de_pixel_art_nao_mexe_em_nada_alem_da_posicao() -> void:
	var acabamento: AcabamentoArte = AcabamentoArte.pixel_art(16)
	assert_eq(acabamento.cores, 0, "a paleta do artista é intocada")
	assert_eq(acabamento.alfa_corte, 0)
	assert_false(acabamento.encaixar)
	assert_eq(acabamento.filtro, Fatiador.Filtro.NEAREST)

func test_preset_de_arte_gerada_liga_as_quatro_etapas() -> void:
	var acabamento: AcabamentoArte = AcabamentoArte.arte_gerada(16)
	assert_true(acabamento.encaixar, "reduz o que não cabe")
	assert_eq(acabamento.filtro, Fatiador.Filtro.SUAVE, "sem serrilhar")
	assert_gt(acabamento.alfa_corte, 0, "sem halo")
	assert_gt(acabamento.cores, 0, "sem paleta de pintura")

func test_duplicar_o_acabamento_nao_deixa_referencia_solta() -> void:
	var original: AcabamentoArte = AcabamentoArte.arte_gerada(16)
	var copia: AcabamentoArte = original.duplica()
	copia.cores = 4
	assert_eq(original.cores, AcabamentoArte.CORES_PADRAO, "mexer na cópia não muda o original")
