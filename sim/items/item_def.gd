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

## O que este item faz quando é **usado** no tile mirado.
##
## É o campo que transforma um item em ferramenta, e é por causa dele que o
## `ToolDef` previsto no GAMEPLAY §10 deixou de existir: ferramenta já precisa
## ser `ItemDef` para ocupar um slot da mochila (§4), e um resource paralelo só
## duplicaria id, nome e ícone para acrescentar esta linha.
##
## O valor é um **id de ação**, não uma classe: `sim/items/resolvedor_uso.gd`
## é quem traduz o id na `SimAction` concreta. O `.tres` fica legível para o
## artista e nenhum dado conhece tipo de código.
##
## Ferramenta nova = um `.tres` novo + um caso no resolvedor. O código de input
## não muda — é a promessa do `game/CLAUDE.md`.
const ACAO_NENHUMA: String = ""
const ACAO_ARAR: String = "arar"
const ACAO_REGAR: String = "regar"

## Todo id de ação que o resolvedor conhece. Serve de documentação no editor e
## de guarda no teste: `.tres` com ação inventada não passa despercebido.
const ACOES_CONHECIDAS: Array[String] = [ACAO_NENHUMA, ACAO_ARAR, ACAO_REGAR]

@export var id: String = ""
@export var nome: String = ""

@export_group("Economia")
## Quanto o caixote paga por unidade. 0 = item que não se vende.
@export_range(0, 9999, 1) var preco_venda: int = 0

@export_group("Inventário")
## Quantas unidades cabem num slot. 1 para ferramenta.
@export_range(1, 999, 1) var stack_max: int = STACK_MAX_PADRAO

@export_group("Uso")
## Vazio = item comum, que não faz nada ao ser usado. Ver `ACOES_CONHECIDAS`.
@export var acao_de_uso: String = ACAO_NENHUMA

@export_group("Sprites")
## Ícone do item na mochila e na hotbar — 16×16, convenção
## `res://assets/items/<id>.png` (docs/ARTE.md).
##
## É um **caminho**, não um `Texture2D`: `sim/` é lógica pura e não conhece
## tipo de engine. Quem carrega a textura é `game/`. Mesma decisão do
## `CropDef.sprites_estagios`.
##
## Vazio = arte ainda não entrou. `game/` mostra o placeholder e o jogo roda —
## foi assim que ferramenta chegou até aqui sem ícone.
##
## `@export_file` é só um hint de editor: o valor continua `String` e `sim/`
## continua sem conhecer `Texture2D`. O que ele muda é o inspector, que passa a
## aceitar o PNG **arrastado do FileSystem** em vez de exigir o caminho
## digitado à mão — errar uma letra aqui é o jeito mais comum de o sprite não
## aparecer no jogo.
@export_file("*.png") var sprite: String = ""
