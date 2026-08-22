class_name CropDef
extends Resource

## Definição de uma cultura — o que o artista edita no inspector, em
## `data/crops/*.tres`.
##
## Conteúdo é id + catálogo: nenhum sistema conhece cultura concreta. Adicionar
## cultura é criar `.tres`, zero código novo.
##
## `dias_por_estagio` diz quantos dias **regados** a planta fica em cada estágio
## antes de sair dele. O último estágio é o "pronta" e não sai sozinho — sai na
## colheita. Logo:
##
## - estágios = `dias_por_estagio.size() + 1` (0, 1, ..., pronta)
## - ciclo em dias = soma da lista
##
## Ex.: `[1, 1, 2]` = 4 estágios (semente, broto, crescendo, pronta) e 4 dias
## até a colheita.
##
## Campo novo aqui sempre nasce com default que preserva o comportamento antigo:
## `.tres` existente continua válido sem edição.

const RENDE_PADRAO: int = 1

@export var id: String = ""
@export var nome: String = ""

@export_group("Crescimento")
## Dias regados para sair de cada estágio. O último estágio (pronta) não entra
## na lista — a soma é o ciclo completo da cultura.
@export var dias_por_estagio: Array[int] = []
## Colhe para sempre: ao colher volta ao estágio anterior ao pronta, em vez de
## sumir do tile.
@export var colheitas_infinitas: bool = false
@export_range(1, 99, 1) var rende_por_colheita: int = RENDE_PADRAO

@export_group("Economia")
## Quanto custa comprar uma semente. O preço de **venda** não mora aqui: o
## caixote vende itens, e quem sabe quanto um item vale é o `ItemDef` dele.
@export_range(0, 9999, 1) var preco_semente: int = 0

@export_group("Itens")
## Id do item de semente. Vazio cai na convenção `semente_<id>`.
@export var item_semente: String = ""
## Id do item colhido. Vazio cai na convenção `<id>`.
@export var item_colheita: String = ""

@export_group("Mundo")
## A planta bloqueia a passagem do jogador. `sim/` ignora — quem lê é `game/`.
@export var bloqueia_movimento: bool = false

@export_group("Sprites")
## Um caminho por estágio, do recém-plantado ao pronta (tamanho esperado:
## `dias_por_estagio.size() + 1`). A arte entra na wave visual.
@export var sprites_estagios: Array[String] = []
## Ícone do pacote de semente na hotbar.
@export var sprite_semente: String = ""
## Ícone do fruto na hotbar.
@export var sprite_fruto: String = ""


## Quantos estágios a cultura tem, contando o pronta.
func total_estagios() -> int:
	return dias_por_estagio.size() + 1

## O estágio em que a cultura pode ser colhida.
func estagio_pronta() -> int:
	return dias_por_estagio.size()

## Para onde a cultura volta ao ser colhida quando rebrota: um estágio antes
## do pronta.
func estagio_rebrota() -> int:
	return maxi(estagio_pronta() - 1, 0)

## Dias regados para sair do estágio. O pronta (e qualquer índice inválido)
## devolve 0 — não sai sozinho.
func dias_do_estagio(estagio: int) -> int:
	if estagio < 0 or estagio >= dias_por_estagio.size():
		return 0
	return dias_por_estagio[estagio]

## Ciclo completo em dias regados, do plantio até ficar pronta.
func dias_ate_pronta() -> int:
	var total := 0
	for dias in dias_por_estagio:
		total += dias
	return total

## Id do item de semente, já resolvido pela convenção.
func item_semente_id() -> String:
	return item_semente if not item_semente.is_empty() else "semente_%s" % id

## Id do item colhido, já resolvido pela convenção.
func item_colheita_id() -> String:
	return item_colheita if not item_colheita.is_empty() else id
