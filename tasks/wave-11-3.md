---
wave: 11.3
titulo: Slots posicionais — arrastar e soltar na mochila
paralelo: nao
depende_de: [11.1, 11.2]
---

## Objetivo

Fazer o slot ter endereço: o item fica **onde o jogador o põe**, e arrastar é
como ele o põe lá — na mochila e na hotbar.

## Por que existe

Pedido no playtest, duas vezes. E consertando isso cai junto um bug que a wave
11.2 criou sem ninguém ver.

Hoje `slots` é uma **lista compacta**: item novo é anexado ao fim e slot que
zera é removido, com todo mundo deslizando para a esquerda. Duas consequências:

1. Não existe "pôr o morango no slot 3" — o slot 3 só existe se o 2 estiver
   cheio. Arrastar seria mentira.
2. A wave 11.2 fez a mão ser um **índice**. Gaste o último morango do slot 1 e a
   lista desliza: sua mão passa a segurar outra coisa sem você ter tocado em
   nada. É o tipo de bug que não aparece no teste e aparece no playtest, na hora
   errada.

## Decisões

- **Slot tem endereço.** `slots` passa a ter sempre `capacity` posições, e a
  posição vazia é um `Slot` sem item — não um buraco na lista. O índice deixa
  de mudar sozinho.
- **Sem bump de versão.** Save antigo tem lista compacta; lida posicionalmente,
  ela cai nas primeiras posições — que é exatamente onde os itens estavam. O
  formato não mudou de um jeito que `from_dict` não resolva.
- **Item novo procura o primeiro slot livre**, depois de tentar empilhar num
  stack do mesmo item que ainda tenha espaço. É a ordem que todo jogo do gênero
  usa, e é a que não espalha o mesmo item por três slots.
- **Mover é ação da sim** (`MoverSlotAction`), como equipar. Arrastar não mexe
  em array nenhum dentro de `game/`: ele manda a intenção e redesenha quando o
  evento volta.
- **Soltar em cima de outro item troca os dois.** Soltar em cima do mesmo item
  empilha até o `stack_max` e o resto fica onde estava. Soltar em slot vazio
  move. Três regras, todas em `sim/`.
- **A mão é o índice, não o item.** Mover o item que está na mão não faz a mão
  segui-lo: ela continua no mesmo slot, agora com outra coisa. É como toda
  hotbar do gênero se comporta, e é o que torna a tecla 1 previsível.
- **A hotbar e a mochila são os mesmos slots.** Arrastar da grade para a faixa
  de baixo é mover entre índices — não existem dois inventários, então não
  existe um segundo caminho para dar errado.

## Impacto

- Eventos novos: `SlotMovidoEvent`.
- Ações novas: `MoverSlotAction`.
- Muda formato de save: **não** — a lista compacta antiga carrega nas primeiras
  posições. Roda o `revisar-save` mesmo assim.
- Arte necessária: nenhuma.
- Toca `game/`: só `game/dev/`.
- Playground na mesma wave: tarefa 11.3.4.

## Tarefas

### 11.3.1 — O slot passa a ter endereço ✅
Muda: sim/items/inventory_state.gd, tests/test_inventory_state.gd
Faz: `slots` com `capacity` posições fixas, `Slot.vazio()`, e o `from_dict`
completando a lista curta do save antigo. `count` ignora posição vazia.

### 11.3.2 — Ganhar e perder item respeitam a posição ✅
Muda: sim/items/inventory_system.gd, tests/test_inventory_system.gd
Depende de: 11.3.1
Faz: `_add_item` empilha primeiro, senão ocupa o primeiro slot livre; stack que
zera **esvazia no lugar** em vez de sumir da lista. Mochila cheia continua
emitindo `ItemLostEvent`.

### 11.3.3 — Mover é ação ✅
Cria: sim/items/mover_slot_action.gd, sim/items/slot_movido_event.gd
Muda: sim/items/inventory_system.gd, tests/test_inventory_system.gd
Depende de: 11.3.2
Faz: mover para vazio, trocar com item diferente, empilhar com item igual
respeitando `stack_max`. Índice fora da capacidade é recusa com motivo.

### 11.3.4 — Arrastar no playground ✅
Cria: game/dev/slot_arrastavel.gd
Muda: game/dev/painel_mochila.gd, tests/test_painel_mochila.gd
Depende de: 11.3.3
Faz: `_get_drag_data`/`_can_drop_data`/`_drop_data` nos quadrados da mochila e
da hotbar, com pré-visualização. Soltar despacha `MoverSlotAction`.

## Em aberto

- Arrastar para o caixote (hoje é clique). Só se incomodar.
- Dividir stack ao arrastar com o botão direito. Idem.
