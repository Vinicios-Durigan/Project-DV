extends GutTest

## `tools/peca_recortada.gd` é o que faz uma folha ter mais de um destino: o
## tipo mora na peça, não na folha. A folha real do projeto traz os estágios da
## cenoura, os do rabanete, o pão, o regador e a enxada na mesma imagem.


func test_o_tipo_da_peca_decide_a_pasta() -> void:
	assert_eq(PecaRecortada.nova(Rect2i(), "pao", DestinoArte.Tipo.ITEM).pasta(),
		"res://assets/items")
	assert_eq(PecaRecortada.nova(Rect2i(), "caixote", DestinoArte.Tipo.OBJETO).pasta(),
		"res://assets/objects")

## O slug sai do próprio nome: o artista já digitou "cenoura" ao nomear, e pedir
## de novo num segundo campo seria trabalho repetido.
func test_cultura_tira_a_subpasta_do_proprio_nome() -> void:
	for nome in ["cenoura_estagio_0", "cenoura_estagio_3", "cenoura_semente", "cenoura_fruto"]:
		assert_eq(PecaRecortada.nova(Rect2i(), nome, DestinoArte.Tipo.CULTURA).pasta(),
			"res://assets/crops/cenoura", nome)

func test_cultura_fora_da_convencao_cai_no_nome_padrao() -> void:
	var peca: PecaRecortada = PecaRecortada.nova(Rect2i(), "coisa", DestinoArte.Tipo.CULTURA)
	assert_eq(peca.pasta("abobora"), "res://assets/crops/abobora",
		"sem sufixo conhecido, quem responde é o padrão da janela")
	assert_eq(peca.pasta(), "res://assets/crops",
		"e sem padrão nenhum sobra a pasta mãe — a janela trava a gravação nesse caso")

func test_o_nome_do_arquivo_e_a_pasta_mais_o_nome() -> void:
	var peca: PecaRecortada = PecaRecortada.nova(Rect2i(), "trigo_fruto", DestinoArte.Tipo.CULTURA)
	assert_eq(peca.arquivo(), "res://assets/crops/trigo/trigo_fruto.png")

func test_tipo_livre_nao_chuta_arquivo() -> void:
	assert_eq(PecaRecortada.nova(Rect2i(), "x", DestinoArte.Tipo.LIVRE).arquivo(), "",
		"'outro' é o caso em que o artista digita o caminho")

func test_a_peca_sabe_dizer_que_passou_do_tamanho() -> void:
	var peca: PecaRecortada = PecaRecortada.nova(Rect2i(), "enxada", DestinoArte.Tipo.ITEM)
	var grande: Image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	peca.define_imagem(grande)

	assert_true(peca.passou_da_celula(16), "32 não cabe em 16")
	assert_false(peca.passou_da_celula(0), "sem célula não há padrão a estourar")
	assert_false(peca.passou_da_celula(32), "cabe justo")

## Textura criada dentro do `_draw` é liberada antes de a placa desenhar, e o
## sprite sai branco. Ela nasce junto com a imagem.
func test_definir_a_imagem_cria_a_textura_junto() -> void:
	var peca: PecaRecortada = PecaRecortada.nova(Rect2i(), "x", DestinoArte.Tipo.ITEM)
	assert_null(peca.textura, "antes não há o que desenhar")
	peca.define_imagem(Image.create_empty(16, 16, false, Image.FORMAT_RGBA8))
	assert_not_null(peca.textura)
	assert_eq(peca.textura.get_size(), Vector2(16, 16))


# --- leitura do slug -----------------------------------------------------

func test_o_nome_da_cultura_sai_do_nome_do_arquivo() -> void:
	assert_eq(DestinoArte.slug_do_nome("cenoura_estagio_0"), "cenoura")
	assert_eq(DestinoArte.slug_do_nome("abobora_semente"), "abobora")
	assert_eq(DestinoArte.slug_do_nome("morango_fruto"), "morango")

func test_nome_sem_sufixo_de_cultura_nao_inventa_slug() -> void:
	assert_eq(DestinoArte.slug_do_nome("regador"), "")
	assert_eq(DestinoArte.slug_do_nome("pao"), "")
	assert_eq(DestinoArte.slug_do_nome("_semente"), "", "sem nada antes do sufixo não há nome")


# --- juntar --------------------------------------------------------------

## O detector separa por vizinhança e não tem como saber que dois pedaços são um
## grão partido. Subir o raio até colá-los colaria também os vizinhos — então a
## junção é manual.
func test_juntar_cobre_a_area_das_duas() -> void:
	var pecas: Array[PecaRecortada] = [
		PecaRecortada.nova(Rect2i(4, 4, 6, 6), "semente", DestinoArte.Tipo.ITEM),
		PecaRecortada.nova(Rect2i(12, 10, 5, 5), "sprite_16", DestinoArte.Tipo.CULTURA),
	]
	var uma: PecaRecortada = PecaRecortada.juntadas(pecas)
	assert_eq(uma.area, Rect2i(4, 4, 13, 11), "a área nova cobre as duas e o vão entre elas")

## O vão entre os pedaços é transparente e some no recorte — juntar não escurece
## nada, só amplia a moldura.
func test_juntar_fica_com_o_nome_e_o_tipo_da_primeira() -> void:
	var pecas: Array[PecaRecortada] = [
		PecaRecortada.nova(Rect2i(4, 4, 6, 6), "semente_trigo", DestinoArte.Tipo.ITEM),
		PecaRecortada.nova(Rect2i(12, 10, 5, 5), "sprite_16", DestinoArte.Tipo.CULTURA),
	]
	var uma: PecaRecortada = PecaRecortada.juntadas(pecas)
	assert_eq(uma.nome, "semente_trigo", "a de cima e à esquerda é a que o artista já viu")
	assert_eq(uma.tipo, DestinoArte.Tipo.ITEM)

func test_juntar_aceita_mais_de_duas() -> void:
	var pecas: Array[PecaRecortada] = [
		PecaRecortada.nova(Rect2i(0, 0, 4, 4), "a", DestinoArte.Tipo.ITEM),
		PecaRecortada.nova(Rect2i(10, 0, 4, 4), "b", DestinoArte.Tipo.ITEM),
		PecaRecortada.nova(Rect2i(0, 10, 4, 4), "c", DestinoArte.Tipo.ITEM),
	]
	assert_eq(PecaRecortada.juntadas(pecas).area, Rect2i(0, 0, 14, 14))

func test_juntar_nada_nao_quebra() -> void:
	assert_null(PecaRecortada.juntadas([] as Array[PecaRecortada]))
