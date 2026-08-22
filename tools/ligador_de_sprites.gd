class_name LigadorDeSprites
extends RefCounted

## Onde cada `.tres` deveria procurar o PNG dele, segundo a convenção do
## `docs/ARTE.md`.
##
## Recortar a folha é metade do trabalho: os arquivos aparecem em `assets/`, mas
## o jogo continua mostrando texto até alguém abrir cada `.tres` e apontar o
## caminho. São 14 itens e 5 culturas — 44 caminhos digitados à mão, cada um
## deles uma chance de errar uma letra e não descobrir até rodar.
##
## Como a convenção é fechada, o caminho é **derivável do id**. Esta classe só
## faz essa conta; quem olha o disco e grava o `.tres` é
## `tools/ligar_sprites.gd`, e é por isso que a parte que erra — a montagem dos
## nomes — cabe num teste.

const PASTA_ITENS: String = "res://assets/items"
const PASTA_CULTURAS: String = "res://assets/crops"


## `enxada` → `res://assets/items/enxada.png`.
static func caminho_do_item(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	return PASTA_ITENS.path_join(item_id + ".png")


## Os caminhos de uma cultura, na ordem em que o `CropDef` os espera.
##
## `quantos_estagios` vem do próprio def (`dias_por_estagio.size() + 1`), e não
## de um número fixo aqui: cultura com três estágios e cultura com cinco existem
## no mesmo jogo, e chutar quatro produziria um caminho a mais apontando para
## nada.
static func caminhos_da_cultura(slug: String, quantos_estagios: int) -> Dictionary:
	if slug.is_empty():
		return {"estagios": PackedStringArray(), "semente": "", "fruto": ""}

	var pasta: String = PASTA_CULTURAS.path_join(slug)
	var estagios: PackedStringArray = PackedStringArray()
	for i in maxi(0, quantos_estagios):
		estagios.append(pasta.path_join("%s%s%d.png" % [slug, "_estagio_", i]))

	return {
		"estagios": estagios,
		"semente": pasta.path_join(slug + "_semente.png"),
		"fruto": pasta.path_join(slug + "_fruto.png"),
	}
