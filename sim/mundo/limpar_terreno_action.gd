class_name LimparTerrenoAction
extends SimAction

## Tirar do caminho o que cobre um tile: capinar o mato, quebrar a pedra,
## derrubar a árvore, arrancar o toco.
##
## Ação pura de mundo: não tira item nem dinheiro, então passa reta pelo
## `InventorySystem`. **Limpar não dá item** — madeira e pedra só teriam para
## onde ir depois que o carpinteiro existir, e item sem destino é lixo ocupando
## slot. O que se ganha é espaço, que é o recurso que esta wave torna escasso.
##
## `item_id` é a ferramenta na mão, e é o `.tres` dela que diz o que ela
## consegue remover (`ItemDef.alvos_de_limpeza`). O sistema recusa com
## `ferramenta_errada` quando a enxada tenta quebrar pedra — a regra é de
## conteúdo, não de código.
##
## Quem monta esta ação é o `ResolvedorUso`: o jogador não tem um botão
## "limpar", ele usa a ferramenta e o contexto decide (wave 11.2).

var x: int = 0
var y: int = 0
## Id da ferramenta usada, como em `data/items/*.tres`.
var item_id: String = ""
