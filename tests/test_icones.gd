extends GutTest

## `game/icones.gd` é a ponte entre o caminho que `sim/` guarda e a textura
## que `game/` desenha.
##
## O que ela precisa garantir é o contrário do que parece: não é que o ícone
## apareça — é que a **falta** dele nunca quebre a tela. O playground tem de
## continuar jogável com meia dúzia de sprites prontos, senão ele para de servir
## para jogar mecânica enquanto a arte não chega.

const ICONE: String = "res://tests/dados/icone_de_teste.png"


func before_each() -> void:
	Icones.esquece_tudo()


func test_carrega_a_textura_do_caminho() -> void:
	var textura: Texture2D = Icones.textura(ICONE)
	assert_not_null(textura)
	assert_eq(textura.get_size(), Vector2(16, 16), "o padrão do projeto")

## Arte faltando é o estado normal do playground hoje, não um erro.
func test_caminho_vazio_ou_inexistente_devolve_nada() -> void:
	assert_null(Icones.textura(""), "campo em branco é 'arte ainda não entrou'")
	assert_null(Icones.textura("res://assets/items/nao_existe.png"),
		"caminho errado no .tres não pode derrubar a tela")

## A mochila redesenha a cada evento da sim, com 24 slots. Sem cache seriam 24
## buscas em disco por virada de dia.
func test_a_mesma_textura_volta_da_segunda_vez() -> void:
	var primeira: Texture2D = Icones.textura(ICONE)
	assert_same(primeira, Icones.textura(ICONE), "veio do cache, não do disco")

func test_o_caminho_que_nao_existe_tambem_fica_no_cache() -> void:
	# Guardar o `null` é o que evita repetir a busca a cada quadro para um item
	# sem arte — que hoje é a maioria deles.
	assert_null(Icones.textura("res://nada.png"))
	assert_null(Icones.textura("res://nada.png"))


# --- pelo catálogo -------------------------------------------------------

func test_o_icone_de_um_item_sai_do_tres_dele() -> void:
	var catalogo := ItemCatalog.new()
	catalogo.load_from_dir()
	var def: ItemDef = catalogo.get_def("trigo")
	def.sprite = ICONE

	assert_not_null(Icones.do_item(catalogo, "trigo"))
	assert_null(Icones.do_item(catalogo, "nao_existe"), "id desconhecido não estoura")
	assert_null(Icones.do_item(null, "trigo"), "sem catálogo, sem ícone")

## O item de sprite vazio não tem ícone, e o jogo segue com o placeholder.
##
## O def é montado aqui em vez de sair do catálogo de propósito: a versão antiga
## deste teste apontava para a enxada porque ela ainda não tinha arte, e quebrou
## no dia em que o `enxada.tres` ganhou o PNG. Teste de comportamento não pode
## depender de qual conteúdo ainda está faltando — senão entregar arte reprova a
## suíte.
func test_item_sem_sprite_no_tres_nao_tem_icone() -> void:
	var catalogo := ItemCatalog.new()
	var def := ItemDef.new()
	def.id = "sem_arte"
	def.nome = "Sem arte"
	catalogo.register(def)

	assert_eq(catalogo.get_def("sem_arte").sprite, "", "nasce sem sprite")
	assert_null(Icones.do_item(catalogo, "sem_arte"))


func test_o_sprite_da_cultura_sai_pelo_estagio() -> void:
	var catalogo := CropCatalog.new()
	catalogo.load_from_dir()
	var def: CropDef = catalogo.get_def("cenoura")
	def.sprites_estagios = [ICONE, ICONE, ICONE, ICONE]

	assert_not_null(Icones.do_estagio(catalogo, "cenoura", 0))
	assert_not_null(Icones.do_estagio(catalogo, "cenoura", 3))

## Cultura com menos sprites que estágios é erro de conteúdo — quem grita sobre
## isso é o teste dos `.tres`, não a tela do jogo.
func test_estagio_fora_da_lista_nao_estoura() -> void:
	var catalogo := CropCatalog.new()
	catalogo.load_from_dir()
	catalogo.get_def("cenoura").sprites_estagios = [ICONE]

	assert_null(Icones.do_estagio(catalogo, "cenoura", 3))
	assert_null(Icones.do_estagio(catalogo, "cenoura", -1))
	assert_null(Icones.do_estagio(catalogo, "nao_existe", 0))

## Arrastar o PNG do FileSystem — o fluxo que o `@export_file` habilitou — faz o
## editor gravar um `uid://`, não um `res://`. Se o carregador não aceitasse
## UID, o artista preencheria o campo certinho e o ícone não apareceria.
func test_uid_carrega_igual_ao_caminho() -> void:
	var uid: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(ICONE))
	assert_string_contains(uid, "uid://", "o editor grava nesta forma")
	assert_not_null(Icones.textura(uid), "e ela tem de carregar igual")
