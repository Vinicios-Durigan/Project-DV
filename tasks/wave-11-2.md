---
wave: 11.2
titulo: Item na mão — uma ação só, e a hotbar decide
paralelo: nao
depende_de: [11, 11.1]
---

## Objetivo

Trocar as quatro ferramentas inventadas no playground pelo modelo que o
`GAMEPLAY §4` já mandava: o item na mão decide o que a ação faz, e a hotbar
decide o item na mão.

## Por que existe

Comprar semente e não conseguir escolher o que plantar foi encontrado jogando.
A causa não é falta de tela: é que a wave 10 cravou `_cultura = ids[0]` e um
enum de quatro ferramentas nas teclas 1–4 — um atalho que contradiz o §4
("hotbar 8 slots, teclas 1–8; ferramentas e sementes ocupam slots") e o §10
("`ToolDef`: ação que despacha"). Esta wave não decide nada novo; ela paga o
atalho.

## Decisões

- **Uma ação só: `UsarAction(x, y)`.** O que ela faz depende do que está na
  mão, e **quem resolve é `sim/`**. `game/` pergunta "qual ação vale aqui?" e
  despacha o que voltar — sem um `if` de regra.
- **A pergunta, e não a expansão.** O resolvedor devolve a ação concreta
  (`TillPlotAction`, `PlantCropAction`…) para `game/` despachar, em vez de a
  sim expandir `UsarAction` por dentro. É o que preserva a ordem do tick
  (Locais → Inventory → Shipping → Farm → Time): `PlantCropAction` estende
  `RemoveItemAction`, e uma ação nascida dentro do `FarmSystem` já teria
  passado do `InventorySystem` — a semente sairia de graça.
- **Cultura pronta tem prioridade.** Tile com cultura madura + usar = colher,
  seja o que for que esteja na mão. Combina com o §6 ("colher: sem swing") e
  tira um passo do laço mais repetido do jogo. Colher sem querer nunca é ruim.
- **Ferramenta é item** (§4). `ItemDef` ganha `acao_de_uso`; enxada e regador
  entram na mochila inicial e ocupam slot. Ocupar slot é o custo, e ele é
  bem-vindo: capacidade é o que vai fazer a cota da cidade doer.
- **O `ToolDef` do §10 morre.** Um resource paralelo duplicaria id, nome e
  ícone para acrescentar um campo — e ferramenta já precisa ser `ItemDef` para
  caber num slot. Divergência do documento, anotada de propósito: o §10 é
  corrigido junto com esta wave.
- **`slot_na_mao` mora no save**, com default. Campo ausente cai no default
  (regra do `from_dict`), então **não há migração** — mas o `revisar-save`
  roda antes do commit.
- **A hotbar é a mochila**, primeiros 8 slots, teclas 1–8 (§4). As teclas 1–4
  de ferramenta somem: era a segunda gramática de input, e é ela que causou o
  problema.
- **O mouse manda: ele é a mira e o clique é o usar.** O caminho do teclado
  (facing + espaço) **continua vivo** — não custa nada, já existe e já tem
  teste, e é a única coisa que segura a promessa de gamepad e co-op do §1.
- **Fora do mapa, o retículo some** em vez de pular para o tile à frente do
  personagem. Esse pulo é o que faz a mira parecer ter vontade própria.
- **Alcance continua 1** — os 8 tiles ao redor mais o de baixo dos pés — e
  continua morando em `game/`, porque a sim não tem a posição do jogador (§8).

## Impacto

- Eventos novos: `SlotEquipadoEvent`.
- Ações novas: `EquiparSlotAction`. `UsarAction` **não** é ação da sim — é a
  pergunta que `game/` faz ao resolvedor.
- Muda formato de save: **sim**, campo `slot_na_mao` no inventário do jogador.
  Com default, sem migração e sem bump de versão.
- Arte necessária: nenhuma nesta wave. Para a wave visual, o §12 já previa 3
  ícones de ferramenta e nós usamos 2 — confirmar com o artista qual é a
  terceira antes de ele fechar o lote.
- Toca `game/`: só `game/dev/`.
- Playground na mesma wave: tarefa 11.2.5.

## Tarefas

### 11.2.1 — Ferramenta é item ✅
Cria: data/items/enxada.tres, data/items/regador.tres
Muda: sim/items/item_def.gd, sim/sim_factory.gd, tests/test_item_defs.gd
Faz: `ItemDef.acao_de_uso: String` com default vazio (item comum não faz nada
ao ser usado), os dois `.tres` de ferramenta com `stack_max = 1`, e a entrega
inicial passa a incluir as duas.

### 11.2.2 — O slot na mão ✅
Muda: sim/items/inventory_state.gd, tests/test_inventory_state.gd
Depende de: 11.2.1
Faz: `slot_na_mao: int = 0` no `PlayerInventory`, dentro do `to_dict`/
`from_dict` com default. Inclui o teste que carrega um save sem o campo.

### 11.2.3 — Equipar é ação ✅
Muda: sim/items/inventory_system.gd, tests/test_inventory_system.gd
Cria: sim/items/equipar_slot_action.gd, sim/items/slot_equipado_event.gd
Depende de: 11.2.2
Faz: `EquiparSlotAction` muda o slot na mão e emite `SlotEquipadoEvent` com o
item que ficou na mão. Slot fora da faixa é recusa com motivo, como qualquer
outra.

### 11.2.4 — A regra do usar ✅
Cria: sim/items/resolvedor_uso.gd, tests/test_resolvedor_uso.gd
Depende de: 11.2.3
Faz: `acao_para(player_id, x, y) -> SimAction`. Ordem: cultura pronta → colher;
senão, `acao_de_uso` do item na mão; semente na mão → plantar **aquela**
cultura; nada aplicável → `null`. `SimFactory` o expõe, como faz com os
catálogos.

### 11.2.5 — Hotbar e mouse no playground ✅
Muda: game/dev/painel_mochila.gd, game/dev/mira_ferramentas.gd
Depende de: 11.2.4
Faz: os 8 primeiros slots viram hotbar (teclas 1–8 e clique), sempre visível
numa faixa mesmo com o painel fechado; o retículo passa a mostrar o nome do
item na mão; o clique despacha o que o resolvedor devolver; o retículo some
quando o cursor sai do mapa. O enum de quatro ferramentas sai.

## Em aberto

- Scroll do mouse para trocar de slot — o §4 prevê. Entra quando incomodar.
- Shift-clique para mover 1 em vez do stack inteiro, no painel do Tab.
- Qual é a terceira ferramenta do §12. Hoje só existem enxada e regador.
- O que a mão vazia faz num tile arado e vazio: hoje, nada. Se um dia isso
  precisar de resposta ("cavar de volta"?), é regra nova, não ajuste.
