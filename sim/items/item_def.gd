class_name ItemDef
extends Resource

## Definição de um item — o que o artista edita no inspector, em `data/items/*.tres`.
##
## Conteúdo é id + catálogo: nenhum sistema conhece item concreto. Ferramenta,
## no sim, é só item de stack 1.
##
## Campo novo aqui sempre nasce com default que preserva o comportamento antigo:
## `.tres` existente continua válido sem edição.

const STACK_MAX_PADRAO: int = 999

@export var id: String = ""
@export var nome: String = ""

@export_group("Economia")
## Quanto o caixote paga por unidade. 0 = item que não se vende.
@export_range(0, 9999, 1) var preco_venda: int = 0

@export_group("Inventário")
## Quantas unidades cabem num slot. 1 para ferramenta.
@export_range(1, 999, 1) var stack_max: int = STACK_MAX_PADRAO
