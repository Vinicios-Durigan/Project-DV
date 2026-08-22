class_name PecaRecortada
extends RefCounted

## Um sprite achado na folha, com tudo o que decide para onde ele vai: o
## pedaço da imagem, o nome do arquivo e o tipo de arte.
##
## Existe porque **uma folha não tem um destino só**. A folha real do projeto
## traz os quatro estágios da cenoura, os do rabanete, o pão, o regador e a
## enxada na mesma imagem — e cada um mora numa pasta diferente. Um seletor de
## tipo para a folha inteira obrigaria a recortar a mesma imagem cinco vezes.
##
## Aqui o tipo é por peça. O seletor da janela vira só o **padrão** aplicado a
## todas na hora que a folha abre.

var area: Rect2i = Rect2i()
var nome: String = ""
var tipo: DestinoArte.Tipo = DestinoArte.Tipo.ITEM
## O sprite já acabado, exatamente como vai para o disco.
var imagem: Image = null
## Fica junto da imagem porque textura criada dentro do `_draw` é liberada
## antes de a placa desenhar, e o sprite sai branco na tela.
var textura: ImageTexture = null


static func nova(onde: Rect2i, como_se_chama: String, de_que_tipo: DestinoArte.Tipo) -> PecaRecortada:
	var peca: PecaRecortada = PecaRecortada.new()
	peca.area = onde
	peca.nome = como_se_chama
	peca.tipo = de_que_tipo
	return peca


func define_imagem(pronta: Image) -> void:
	imagem = pronta
	textura = ImageTexture.create_from_image(pronta)


## Cultura mora em subpasta com o nome dela, e esse nome está no próprio
## arquivo: `cenoura_estagio_0` mora em `assets/crops/cenoura/`.
##
## Ler o slug do nome é o que evita pedir a mesma informação duas vezes — o
## artista já digitou "cenoura" ao nomear a peça. `slug_padrao` cobre o caso de
## ele ter marcado Cultura antes de nomear.
func pasta(slug_padrao: String = "") -> String:
	if not DestinoArte.precisa_de_slug(tipo):
		return DestinoArte.pasta(tipo)

	var slug: String = DestinoArte.slug_do_nome(nome)
	return DestinoArte.pasta(tipo, slug if not slug.is_empty() else slug_padrao)


func arquivo(slug_padrao: String = "") -> String:
	var destino: String = pasta(slug_padrao)
	return "" if destino.is_empty() else destino.path_join(nome + ".png")


## Fora do padrão de tamanho do projeto — o que o resumo precisa contar.
func passou_da_celula(celula: int) -> bool:
	if celula <= 0 or imagem == null:
		return false
	return imagem.get_width() > celula or imagem.get_height() > celula
