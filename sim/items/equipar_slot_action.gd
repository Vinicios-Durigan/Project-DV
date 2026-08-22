class_name EquiparSlotAction
extends SimAction

## Põe na mão o item de um slot da mochila. É a ação da hotbar: tecla 1–8,
## clique no slot, scroll — tudo desemboca aqui.
##
## Guarda o **índice**, não o item. Guardar o item faria a mão pular sozinha
## para outro slot no dia em que um stack acabasse; com o índice, a mão fica
## onde o jogador a deixou e simplesmente esvazia — que é como toda hotbar do
## gênero se comporta.
##
## Slot vazio não é recusa: mão vazia é um estado legítimo, e é com ela que se
## colhe.

## Índice do slot, de 0 a `capacity - 1`. Fora disso é recusa.
var slot: int = 0
