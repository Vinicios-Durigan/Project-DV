extends GutTest

## `tools/destino_arte.gd` é o `docs/ARTE.md` escrito em código: pasta certa e
## nome certo por tipo de arte. Se os dois se separarem, a arte vai para o lugar
## errado e simplesmente não aparece no jogo — sem erro, sem aviso.
##
## Este teste é quem percebe a separação.


func test_cada_tipo_tem_uma_pasta_dentro_de_assets() -> void:
	for tipo in DestinoArte.tipos_em_ordem():
		if tipo == DestinoArte.Tipo.LIVRE:
			continue
		var pasta: String = DestinoArte.pasta(tipo, "trigo")
		assert_true(pasta.begins_with("res://assets/"),
			"%s: toda arte mora em assets/ (%s)" % [DestinoArte.rotulo(tipo), pasta])

func test_o_tipo_livre_nao_chuta_pasta() -> void:
	assert_eq(DestinoArte.pasta(DestinoArte.Tipo.LIVRE), "",
		"'outro' é justamente o caso em que o artista digita o caminho")

## Cultura é a única que mora em subpasta própria — `assets/crops/trigo/` —
## como manda o ARTE.md §2.
func test_cultura_ganha_subpasta_com_o_nome_dela() -> void:
	assert_eq(DestinoArte.pasta(DestinoArte.Tipo.CULTURA, "trigo"), "res://assets/crops/trigo")
	assert_true(DestinoArte.precisa_de_slug(DestinoArte.Tipo.CULTURA))

func test_item_ignora_o_slug() -> void:
	assert_eq(DestinoArte.pasta(DestinoArte.Tipo.ITEM, "trigo"), "res://assets/items",
		"item não se separa por subpasta")
	assert_false(DestinoArte.precisa_de_slug(DestinoArte.Tipo.ITEM))

func test_cultura_sem_slug_cai_na_pasta_mae() -> void:
	assert_eq(DestinoArte.pasta(DestinoArte.Tipo.CULTURA, ""), "res://assets/crops",
		"sem o nome ainda dá um caminho válido — quem cobra o slug é a interface")


# --- nomes de arquivo ----------------------------------------------------

## Nome de arquivo é contrato (ARTE.md §10): minúsculo, sem acento, sublinhado e
## não hífen. Errar aqui é o motivo número um de sprite sumido, e é o que dá
## para consertar antes de gravar.
func test_slug_vira_nome_de_arquivo_valido() -> void:
	assert_eq(DestinoArte.normaliza_slug("Abóbora"), "abobora", "acento sai")
	assert_eq(DestinoArte.normaliza_slug("Pé de Feijão"), "pe_de_feijao", "espaço vira _")
	assert_eq(DestinoArte.normaliza_slug("couve-flor"), "couve_flor", "hífen vira _")
	assert_eq(DestinoArte.normaliza_slug("  trigo  "), "trigo", "sobra de espaço some")
	assert_eq(DestinoArte.normaliza_slug("trigo!!!@#"), "trigo", "pontuação some")
	assert_eq(DestinoArte.normaliza_slug("a  b"), "a_b", "não sobra sublinhado duplo")

func test_slug_vazio_continua_vazio() -> void:
	assert_eq(DestinoArte.normaliza_slug("   "), "")
	assert_eq(DestinoArte.normaliza_slug("!@#"), "")

## A convenção fechada do ARTE.md §2: estágios crescendo, depois os dois ícones.
func test_cultura_completa_sai_com_os_nomes_da_convencao() -> void:
	var nomes: PackedStringArray = DestinoArte.nomes_sugeridos(
		DestinoArte.Tipo.CULTURA, "trigo", 6)
	assert_eq(Array(nomes), [
		"trigo_estagio_0", "trigo_estagio_1", "trigo_estagio_2", "trigo_estagio_3",
		"trigo_semente", "trigo_fruto",
	], "4 estágios, semente e fruto, na ordem de leitura")

func test_nome_sugerido_ja_vem_normalizado() -> void:
	var nomes: PackedStringArray = DestinoArte.nomes_sugeridos(
		DestinoArte.Tipo.CULTURA, "Abóbora", 6)
	assert_eq(nomes[0], "abobora_estagio_0", "o acento não chega no disco")

## Cultura com mais ou menos estágios continua funcionando: os dois últimos
## recortes são sempre semente e fruto, o resto vira estágio.
func test_cultura_com_outro_numero_de_estagios() -> void:
	var nomes: PackedStringArray = DestinoArte.nomes_sugeridos(
		DestinoArte.Tipo.CULTURA, "trigo", 5)
	assert_eq(Array(nomes), [
		"trigo_estagio_0", "trigo_estagio_1", "trigo_estagio_2",
		"trigo_semente", "trigo_fruto",
	])

func test_tipo_sem_convencao_nao_chuta_nome() -> void:
	assert_eq(DestinoArte.nomes_sugeridos(DestinoArte.Tipo.ITEM, "enxada", 4).size(), 0,
		"item não tem nome previsível — quem nomeia é o artista")
	assert_eq(DestinoArte.nomes_sugeridos(DestinoArte.Tipo.CULTURA, "", 6).size(), 0,
		"sem o nome da cultura não há o que sugerir")


# --- avisos --------------------------------------------------------------

## Cultura com número errado de sprites quebra o `.tres` depois, longe daqui.
## Vale gritar antes de gravar.
func test_avisa_quando_a_cultura_tem_sprite_a_mais_ou_a_menos() -> void:
	assert_eq(DestinoArte.aviso_de_quantidade(DestinoArte.Tipo.CULTURA, 6), "",
		"6 é o esperado e não gera aviso")
	assert_false(DestinoArte.aviso_de_quantidade(DestinoArte.Tipo.CULTURA, 5).is_empty(),
		"5 sprites numa cultura merece aviso")

func test_tipo_sem_quantidade_fixa_nunca_avisa() -> void:
	for quantos in [1, 7, 40]:
		assert_eq(DestinoArte.aviso_de_quantidade(DestinoArte.Tipo.ITEM, quantos), "",
			"folha de itens tem o tamanho que tiver")


# --- célula --------------------------------------------------------------

func test_tipos_quadrados_seguem_o_padrao_de_16() -> void:
	for tipo in [DestinoArte.Tipo.ITEM, DestinoArte.Tipo.CULTURA,
			DestinoArte.Tipo.OBJETO, DestinoArte.Tipo.TILE]:
		assert_eq(DestinoArte.celula(tipo), 16, "%s: o padrão do projeto" % DestinoArte.rotulo(tipo))

## Personagem é 16×32 e partícula varia — célula quadrada estragaria os dois, e
## por isso eles saem no tamanho justo.
func test_personagem_e_particula_nao_tem_celula_fixa() -> void:
	assert_eq(DestinoArte.celula(DestinoArte.Tipo.PERSONAGEM), 0)
	assert_eq(DestinoArte.celula(DestinoArte.Tipo.PARTICULA), 0)


# --- nomes de tipo na linha de comando -----------------------------------

func test_tipo_por_nome_aceita_como_o_artista_escreve() -> void:
	assert_eq(DestinoArte.tipo_por_nome("cultura"), DestinoArte.Tipo.CULTURA)
	assert_eq(DestinoArte.tipo_por_nome("CULTURA"), DestinoArte.Tipo.CULTURA)
	assert_eq(DestinoArte.tipo_por_nome("planta"), DestinoArte.Tipo.CULTURA)
	assert_eq(DestinoArte.tipo_por_nome("chão"), DestinoArte.Tipo.TILE)
	assert_eq(DestinoArte.tipo_por_nome("chao"), DestinoArte.Tipo.TILE)

func test_tipo_desconhecido_cai_em_livre() -> void:
	assert_eq(DestinoArte.tipo_por_nome("banana"), DestinoArte.Tipo.LIVRE,
		"o CLI é quem transforma isso em erro, com a lista dos aceitos")

func test_a_lista_de_tipos_aceitos_cobre_todos_os_reais() -> void:
	var lista: String = DestinoArte.nomes_de_tipo_aceitos()
	for tipo in DestinoArte.tipos_em_ordem():
		if tipo == DestinoArte.Tipo.LIVRE:
			continue
		var achou: bool = false
		for pedaco in lista.split(",", false):
			if DestinoArte.tipo_por_nome(pedaco) == tipo:
				achou = true
				break
		assert_true(achou, "%s: falta na mensagem de ajuda" % DestinoArte.rotulo(tipo))


# --- nomes em lote -------------------------------------------------------

## As folhas do projeto vêm em duas ordens. Adivinhar erraria metade das vezes,
## e nome errado só aparece semanas depois com o sprite trocado no jogo.
func test_lote_de_cultura_com_a_semente_primeiro() -> void:
	assert_eq(Array(DestinoArte.nomes_em_lote("abobora", 6,
		DestinoArte.Padrao.CULTURA_SEMENTE_PRIMEIRO)), [
		"abobora_semente", "abobora_estagio_0", "abobora_estagio_1",
		"abobora_estagio_2", "abobora_estagio_3", "abobora_fruto",
	])

func test_lote_de_cultura_com_a_semente_no_fim() -> void:
	assert_eq(Array(DestinoArte.nomes_em_lote("trigo", 6,
		DestinoArte.Padrao.CULTURA_SEMENTE_NO_FIM)), [
		"trigo_estagio_0", "trigo_estagio_1", "trigo_estagio_2", "trigo_estagio_3",
		"trigo_semente", "trigo_fruto",
	])

func test_lote_numerado_para_o_que_nao_e_cultura() -> void:
	assert_eq(Array(DestinoArte.nomes_em_lote("cerca", 3, DestinoArte.Padrao.NUMERADO)),
		["cerca_0", "cerca_1", "cerca_2"])

func test_lote_numerado_de_um_so_nao_ganha_sufixo() -> void:
	assert_eq(Array(DestinoArte.nomes_em_lote("regador", 1, DestinoArte.Padrao.NUMERADO)),
		["regador"], "um sprite sozinho não precisa de número")

func test_lote_normaliza_o_nome_base() -> void:
	assert_eq(DestinoArte.nomes_em_lote("Abóbora", 2,
		DestinoArte.Padrao.CULTURA_SEMENTE_PRIMEIRO)[0], "abobora_semente")

func test_lote_sem_base_ou_sem_pecas_devolve_vazio() -> void:
	assert_eq(DestinoArte.nomes_em_lote("", 4, DestinoArte.Padrao.NUMERADO).size(), 0)
	assert_eq(DestinoArte.nomes_em_lote("abobora", 0, DestinoArte.Padrao.NUMERADO).size(), 0)

## Cultura com poucos sprites não inventa estágio: sobra semente e fruto.
func test_lote_de_cultura_com_dois_sprites() -> void:
	assert_eq(Array(DestinoArte.nomes_em_lote("morango", 2,
		DestinoArte.Padrao.CULTURA_SEMENTE_PRIMEIRO)), ["morango_semente", "morango_fruto"])

## Todo nome de um lote é diferente do outro — é o ponto: 25 arquivos que se
## sobrescreveriam viram 25 arquivos de verdade.
func test_nenhum_nome_do_lote_se_repete() -> void:
	for padrao in DestinoArte.padroes_em_ordem():
		var nomes: PackedStringArray = DestinoArte.nomes_em_lote("abobora", 6, padrao)
		var vistos: Dictionary = {}
		for nome in nomes:
			vistos[nome] = true
		assert_eq(vistos.size(), nomes.size(), DestinoArte.rotulo_do_padrao(padrao))
