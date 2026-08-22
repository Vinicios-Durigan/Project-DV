extends GutTest

## A janela do fatiador (`tools/fatiar_visual.tscn`) não tem regra própria — ela
## liga `Fatiador`, `DestinoArte` e `PecaRecortada`, todos já testados. O que
## este teste garante é a fiação: que a tela monta, que abrir uma folha acha os
## sprites, que o tipo de cada peça manda no destino dela, e que o zoom e o
## clique respondem.
##
## Sem isto, um erro de montagem só apareceria quando alguém abrisse a janela —
## e ninguém abre a janela numa rodada de testes.

const CENA: String = "res://tools/fatiar_visual.tscn"
const FUNDO: Color = Color(0.17, 0.17, 0.19)

var _janela: Control


func before_each() -> void:
	_janela = add_child_autofree(load(CENA).instantiate())


## Uma folha gravada em disco, porque a janela carrega por caminho de arquivo —
## é assim que ela vai receber a arte de verdade.
func _folha_em_disco() -> String:
	var imagem: Image = Image.create_empty(64, 40, false, Image.FORMAT_RGBA8)
	imagem.fill(FUNDO)
	imagem.fill_rect(Rect2i(2, 2, 8, 8), Color.RED)
	imagem.fill_rect(Rect2i(20, 3, 10, 6), Color.GREEN)
	imagem.fill_rect(Rect2i(40, 2, 6, 9), Color.BLUE)
	imagem.fill_rect(Rect2i(4, 22, 6, 6), Color.YELLOW)

	var caminho: String = ProjectSettings.globalize_path("user://folha_de_teste.png")
	imagem.save_png(caminho)
	return caminho


func _com_folha() -> void:
	_janela._carrega_folha(_folha_em_disco())


func test_a_janela_monta_sem_erro() -> void:
	assert_not_null(_janela, "a cena instancia")
	assert_gt(_janela.get_child_count(), 0, "os controles foram criados no _ready")


func test_comeca_sem_folha_e_com_o_botao_de_gravar_travado() -> void:
	assert_true(_janela._botao_gravar.disabled, "sem folha não há o que gravar")


func test_abrir_uma_folha_acha_os_sprites() -> void:
	_com_folha()
	assert_eq(_janela._pecas.size(), 4, "quatro desenhos, quatro peças")
	assert_false(_janela._botao_gravar.disabled, "com folha nomeada, dá para gravar")


## O palpite de cor vai para o seletor: o artista precisa ver qual cor foi
## detectada para poder corrigi-la a partir dela.
func test_a_cor_de_fundo_detectada_aparece_no_seletor() -> void:
	_com_folha()
	assert_almost_eq(_janela._fundo_cor.color.r, FUNDO.r, 0.02)


func test_mexer_no_corte_reprocessa_a_folha() -> void:
	_com_folha()
	_janela._area_minima.value = 999
	assert_eq(_janela._pecas.size(), 0, "área mínima absurda descarta tudo")
	assert_true(_janela._botao_gravar.disabled, "sem peça não grava")


## Mexer na tolerância não pode apagar o trabalho de nomear — é o ajuste que
## mais se repete, e renomear 29 sprites de novo seria inaceitável.
func test_reprocessar_preserva_nome_e_tipo_ja_escolhidos() -> void:
	_com_folha()
	_janela._pecas[0].nome = "regador"
	_janela._pecas[0].tipo = DestinoArte.Tipo.OBJETO
	_janela._tolerancia.value = 20

	assert_eq(_janela._pecas[0].nome, "regador", "o nome ficou")
	assert_eq(_janela._pecas[0].tipo, DestinoArte.Tipo.OBJETO, "e o tipo também")


# --- destino por sprite --------------------------------------------------

## O ponto da lista: uma folha com cultura, pão e regador junto vira arquivos em
## pastas diferentes numa passada só.
func test_cada_peca_vai_para_a_pasta_do_tipo_dela() -> void:
	_com_folha()
	_janela._pecas[0].nome = "cenoura_estagio_0"
	_janela._pecas[0].tipo = DestinoArte.Tipo.CULTURA
	_janela._pecas[1].nome = "pao"
	_janela._pecas[1].tipo = DestinoArte.Tipo.ITEM
	_janela._pecas[2].nome = "caixote"
	_janela._pecas[2].tipo = DestinoArte.Tipo.OBJETO

	assert_eq(_janela._pecas[0].pasta(), "res://assets/crops/cenoura")
	assert_eq(_janela._pecas[1].pasta(), "res://assets/items")
	assert_eq(_janela._pecas[2].pasta(), "res://assets/objects")


func test_o_tipo_padrao_se_aplica_a_todos_de_uma_vez() -> void:
	_com_folha()
	_janela._tipo_padrao.select(_janela._tipo_padrao.get_item_index(DestinoArte.Tipo.OBJETO))
	_janela._aplica_tipo_padrao_a_todos()

	for peca in _janela._pecas:
		assert_eq(peca.tipo, DestinoArte.Tipo.OBJETO)




# --- o que impede de gravar ----------------------------------------------

## Dois sprites com o mesmo nome na mesma pasta viram um arquivo só, em
## silêncio. É o pior erro possível aqui.
func test_nome_repetido_na_mesma_pasta_trava_a_gravacao() -> void:
	_com_folha()
	_janela._pecas[0].nome = "cenoura"
	_janela._pecas[1].nome = "cenoura"
	_janela._atualiza_resumo()
	assert_true(_janela._botao_gravar.disabled, "não grava com nome repetido")

func test_o_mesmo_nome_em_pastas_diferentes_e_permitido() -> void:
	_com_folha()
	_janela._pecas[0].nome = "cenoura"
	_janela._pecas[0].tipo = DestinoArte.Tipo.ITEM
	_janela._pecas[1].nome = "cenoura"
	_janela._pecas[1].tipo = DestinoArte.Tipo.OBJETO
	_janela._atualiza_resumo()
	assert_false(_janela._botao_gravar.disabled, "pastas diferentes, arquivos diferentes")

func test_peca_sem_nome_trava_a_gravacao() -> void:
	_com_folha()
	_janela._pecas[0].nome = ""
	_janela._atualiza_resumo()
	assert_true(_janela._botao_gravar.disabled)

## Cultura sem nome de cultura iria para `assets/crops/` solta, fora da subpasta
## que o `.tres` espera.
func test_cultura_sem_nome_de_cultura_trava_a_gravacao() -> void:
	_com_folha()
	_janela._pecas[0].tipo = DestinoArte.Tipo.CULTURA
	_janela._pecas[0].nome = "coisa"
	_janela._slug.text = ""
	_janela._atualiza_resumo()
	assert_true(_janela._botao_gravar.disabled)

	_janela._slug.text = "cenoura"
	_janela._atualiza_resumo()
	assert_false(_janela._botao_gravar.disabled, "o nome padrão resolve")


# --- zoom e arrasto ------------------------------------------------------

## Uma folha de 1536px não cabe na tela e não se confere de longe.
func test_o_zoom_comeca_ajustado_e_passa_a_obedecer_depois_do_primeiro_passo() -> void:
	_com_folha()
	assert_eq(_janela._zoom, 0.0, "zero significa ajustar sozinho ao espaço")

	_janela._muda_zoom(2.0)
	assert_gt(_janela._zoom, 0.0, "a partir daqui quem manda é o valor pedido")

	_janela._ajusta_o_enquadramento()
	assert_eq(_janela._zoom, 0.0, "e o botão Ajustar devolve o automático")
	assert_eq(_janela._deslocamento, Vector2.ZERO, "junto com o enquadramento")

func test_o_zoom_respeita_os_limites() -> void:
	_com_folha()
	for i in 40:
		_janela._muda_zoom(2.0)
	assert_lte(_janela._zoom, _janela.ZOOM_MAXIMO)

	for i in 60:
		_janela._muda_zoom(0.5)
	assert_gte(_janela._zoom, _janela.ZOOM_MINIMO)

## Clicar num sprite escolhe ele — é como o número verde na folha vira a linha
## da lista.
func test_clicar_dentro_de_um_sprite_escolhe_ele() -> void:
	_com_folha()
	_janela._tela.size = Vector2(400, 300)
	var zoom: float = _janela._zoom_efetivo()
	var area: Rect2i = _janela._pecas[2].area
	var centro: Vector2 = (_janela._canto(zoom)
		+ (Vector2(area.position) + Vector2(area.size) * 0.5) * zoom)

	assert_eq(_janela._sprite_em(centro), 2, "achou o de baixo do cursor")
	assert_eq(_janela._sprite_em(Vector2(-50, -50)), -1, "fora da folha não escolhe nada")


# --- a tela --------------------------------------------------------------

## O projeto roda esticado por escala inteira (viewport 640×360). Numa
## ferramenta isso amplia todo controle 2× e o painel deixa de caber — foi
## exatamente o que aconteceu na primeira versão.
func test_a_janela_nao_mexe_no_stretch_quando_nao_e_a_cena_que_roda() -> void:
	assert_ne(get_tree().current_scene, _janela, "a cena de teste não é a cena raiz")
	assert_ne(_janela.get_window().content_scale_mode, Window.CONTENT_SCALE_MODE_DISABLED,
		"a janela do teste ficou como estava")

## Texturas criadas dentro do `_draw` são liberadas antes de a placa desenhar, e
## o sprite sai branco na tela. Elas vivem junto com a peça.
func test_cada_peca_carrega_a_propria_textura() -> void:
	_com_folha()
	for peca in _janela._pecas:
		assert_not_null(peca.imagem, "a imagem acabada")
		assert_not_null(peca.textura, "e a textura que a desenha")

func test_a_peca_sai_no_tamanho_da_celula() -> void:
	_com_folha()
	_janela._celula.value = 16
	for peca in _janela._pecas:
		assert_eq(peca.imagem.get_size(), Vector2i(16, 16), "é o que vai para o disco")


# --- acabamento ----------------------------------------------------------

## O interruptor de arte gerada mexe nos controles finos, e não num estado
## escondido: o artista precisa ver o que foi ligado para desligar item por
## item.
func test_o_interruptor_de_ia_liga_os_controles_finos() -> void:
	_com_folha()
	_janela._de_ia.button_pressed = true

	assert_true(_janela._encaixar.button_pressed)
	assert_true(_janela._suave.button_pressed)
	assert_eq(int(_janela._alfa_corte.value), AcabamentoArte.ALFA_CORTE_PADRAO)
	assert_eq(int(_janela._cores.value), AcabamentoArte.CORES_PADRAO)

func test_desligar_o_interruptor_devolve_o_modo_pixel_art() -> void:
	_janela._de_ia.button_pressed = true
	_janela._de_ia.button_pressed = false

	assert_false(_janela._encaixar.button_pressed)
	assert_eq(int(_janela._cores.value), 0, "a paleta do artista volta a ser intocada")

## A janela e a linha de comando montam o mesmo objeto de acabamento. Se
## divergirem, o artista vê um resultado na tela e outro no arquivo.
func test_o_acabamento_da_janela_e_o_mesmo_do_preset() -> void:
	_janela._celula.value = 16
	_janela._de_ia.button_pressed = true
	var referencia: AcabamentoArte = AcabamentoArte.arte_gerada(16)
	var atual: AcabamentoArte = _janela._acabamento_atual()

	assert_eq(atual.encaixar, referencia.encaixar)
	assert_eq(atual.filtro, referencia.filtro)
	assert_eq(atual.alfa_corte, referencia.alfa_corte)
	assert_eq(atual.cores, referencia.cores)
	assert_eq(atual.celula, referencia.celula)


# --- juntar e remover na lista -------------------------------------------

func _marca(indices: Array) -> void:
	for i in indices:
		_janela._marcas[i].button_pressed = true

## O caso real: os recortes 15 e 16 da folha do projeto são um grão só, partido
## em dois pedaços.
func test_juntar_dois_recortes_vira_um_sprite_so() -> void:
	_com_folha()
	var antes: int = _janela._pecas.size()
	var area_a: Rect2i = _janela._pecas[0].area
	var area_b: Rect2i = _janela._pecas[1].area
	_marca([0, 1])
	_janela._junta_marcados()

	assert_eq(_janela._pecas.size(), antes - 1, "dois viraram um")
	var esperada: Rect2i = area_a.merge(area_b)
	var achou: bool = false
	for peca in _janela._pecas:
		if peca.area == esperada:
			achou = true
	assert_true(achou, "e a área nova cobre as duas")

func test_o_botao_de_juntar_so_liga_com_dois_marcados() -> void:
	_com_folha()
	assert_true(_janela._botao_juntar.disabled, "nada marcado, nada a juntar")

	_marca([0])
	assert_true(_janela._botao_juntar.disabled, "um só não se junta a nada")
	assert_false(_janela._botao_remover.disabled, "mas dá para remover")

	_marca([1])
	assert_false(_janela._botao_juntar.disabled)

func test_remover_descarta_o_marcado() -> void:
	_com_folha()
	var antes: int = _janela._pecas.size()
	var area: Rect2i = _janela._pecas[1].area
	_marca([1])
	_janela._remove_marcados()

	assert_eq(_janela._pecas.size(), antes - 1)
	for peca in _janela._pecas:
		assert_ne(peca.area, area, "o removido não voltou")

## Depois de mexer na lista os números têm de continuar em ordem de leitura,
## senão a junção seguinte é feita às cegas.
func test_a_lista_volta_para_a_ordem_de_leitura_depois_de_juntar() -> void:
	_com_folha()
	_marca([0, 3])
	_janela._junta_marcados()

	var anterior: Rect2i = _janela._pecas[0].area
	for i in range(1, _janela._pecas.size()):
		var atual: Rect2i = _janela._pecas[i].area
		assert_true(atual.position.y >= anterior.position.y
			or atual.position.x >= anterior.position.x, "ordem de leitura mantida")
		anterior = atual

func test_a_juncao_reaproveita_o_nome_e_refaz_a_imagem() -> void:
	_com_folha()
	_janela._pecas[0].nome = "semente_trigo"
	_marca([0, 1])
	_janela._junta_marcados()

	var juntada: PecaRecortada = null
	for peca in _janela._pecas:
		if peca.nome == "semente_trigo":
			juntada = peca
	assert_not_null(juntada, "o nome sobreviveu à junção")
	assert_not_null(juntada.imagem, "e a imagem foi refeita na área nova")

## Refazer é a saída para desfazer junções e remoções sem reabrir o arquivo.
func test_refazer_a_lista_volta_ao_que_o_detector_achou() -> void:
	_com_folha()
	var antes: int = _janela._pecas.size()
	_marca([0, 1])
	_janela._junta_marcados()
	assert_eq(_janela._pecas.size(), antes - 1)

	_janela._reprocessa()
	assert_eq(_janela._pecas.size(), antes, "voltou tudo")


# --- nomear em lote ------------------------------------------------------

## O trabalho real: 25 sprites de cultura na folha. Nomear um a um dói, e
## digitar o mesmo nome em todos — o atalho natural — produz 25 arquivos que se
## sobrescrevem. O lote é o irmão do "Juntar marcados": mesma marcação, outra
## ação.
func test_nomear_marcados_distribui_os_sufixos_na_ordem() -> void:
	_com_folha()
	_marca([0, 1, 2, 3])
	_janela._nome_base.text = "abobora"
	_janela._padrao_de_nome.select(_janela._padrao_de_nome.get_item_index(
		DestinoArte.Padrao.CULTURA_SEMENTE_PRIMEIRO))
	_janela._nomeia_marcados()

	assert_eq(_janela._pecas[0].nome, "abobora_semente", "o pacote vem primeiro nesta folha")
	assert_eq(_janela._pecas[1].nome, "abobora_estagio_0")
	assert_eq(_janela._pecas[2].nome, "abobora_estagio_1")
	assert_eq(_janela._pecas[3].nome, "abobora_fruto")

func test_nomear_em_lote_resolve_o_nome_repetido() -> void:
	_com_folha()
	for peca in _janela._pecas:
		peca.nome = "abobora"
	_janela._atualiza_resumo()
	assert_true(_janela._botao_gravar.disabled, "quatro 'abobora' na mesma pasta")

	_marca([0, 1, 2, 3])
	for peca in _janela._pecas:
		peca.tipo = DestinoArte.Tipo.CULTURA
	_janela._nome_base.text = "abobora"
	_janela._nomeia_marcados()
	assert_false(_janela._botao_gravar.disabled, "com os sufixos, cada um é um arquivo")

## Nomear só toca no que está marcado — o pão e o regador da mesma folha ficam
## com o nome que o artista deu.
func test_nomear_em_lote_nao_toca_no_que_nao_esta_marcado() -> void:
	_com_folha()
	_janela._pecas[3].nome = "regador"
	_marca([0, 1])
	_janela._nome_base.text = "abobora"
	_janela._nomeia_marcados()

	assert_eq(_janela._pecas[3].nome, "regador")

func test_nomear_sem_nome_base_nao_faz_nada() -> void:
	_com_folha()
	_janela._pecas[0].nome = "regador"
	_marca([0])
	_janela._nome_base.text = "   "
	_janela._nomeia_marcados()
	assert_eq(_janela._pecas[0].nome, "regador", "sem base não há o que aplicar")

func test_marcar_todos_e_limpar() -> void:
	_com_folha()
	_janela._marca_todos(true)
	assert_eq(_janela._marcados().size(), _janela._pecas.size(), "marcar 25 um a um seria pior")
	assert_false(_janela._botao_nomear.disabled)

	_janela._marca_todos(false)
	assert_eq(_janela._marcados().size(), 0)
	assert_true(_janela._botao_nomear.disabled)
