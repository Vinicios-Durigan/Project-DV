---
wave: 02
titulo: Inventário e catálogo de itens
paralelo: nao
depende_de: [01]
---

## Objetivo

Itens existem como id + catálogo, e cada jogador tem inventário com stack, capacity e dinheiro — com o mecanismo de reação a eventos que o resto da sim vai usar.

## Decisões

- SimWorld ganha **redistribuição de eventos**: evento emitido entra numa fila e é oferecido a todos os sistemas via `react(event)` antes de sair; reações geram eventos que voltam à fila (processa até esvaziar, ordem fixa — determinístico). É o "reage a evento" do sim/CLAUDE.md, formalizado.
- **Validação em cadeia**: ação ganha campo `rejeitada: bool`; sistema que detecta impossibilidade (sem semente, sem dinheiro) marca e emite `ActionRejectedEvent`; sistemas seguintes ignoram ação rejeitada. Ordem de handle vira: **Inventory → Shipping → Farm → Time**.
- Ferramenta, no sim, é só item (stack 1). ToolDef visual é assunto de game/, wave futura.
- Item = `item_id: String` + qtd, stack máx 999. Inventário cheio ao ganhar item → item perdido + `ItemLostEvent` (drop no chão fica pro futuro).
- Dinheiro mora no InventoryState, por `player_id`. Início: 500g, capacity 24.

## Impacto

- Eventos novos: ActionRejectedEvent, ItemAddedEvent, ItemRemovedEvent, ItemLostEvent, MoneyChangedEvent
- Muda formato de save: adiciona bloco `inventory` (ainda v1 — save file só nasce na wave 05).
- Arte necessária: nenhuma.
- Toca `game/`: não. Altera contrato de `sim/core/sim_system.gd` e `sim/sim_world.gd` (wave 01).

## Tarefas

### 2.1 — react() no contrato de sistema ✅
Cria: tests/test_sim_system_react.gd
Altera: sim/core/sim_system.gd
Faz: adiciona `react(event) -> Array[SimEvent]` default `[]` e campo `rejeitada` na SimAction (sim/core/sim_action.gd, 1 linha).

### 2.2 — Fila de eventos no SimWorld ✅
Cria: tests/test_sim_world_react.gd
Altera: sim/sim_world.gd
Depende de: 2.1
Faz: eventos emitidos em handle/tick entram em fila; cada um é oferecido a todos via react na ordem fixa; reações voltam à fila; saída preserva ordem de acontecimento.

### 2.3 — ItemDef e catálogo ✅
Cria: sim/items/item_def.gd, sim/items/item_catalog.gd, tests/test_item_catalog.gd
Faz: `ItemDef` (Resource: id, nome, preco_venda, stack_max) e catálogo que carrega `data/items/*.tres` com lookup por id.

### 2.4 — InventoryState ✅
Cria: sim/items/inventory_state.gd, tests/test_inventory_state.gd
Faz: slots (item_id, qtd), capacity, dinheiro, por player_id; defaults + to_dict/from_dict.

### 2.5 — InventorySystem ✅
Cria: sim/items/inventory_system.gd, tests/test_inventory_system.gd
Depende de: 2.2, 2.3, 2.4
Faz: handle de AddItemAction/RemoveItemAction/AddMoneyAction (formais — dev e sistemas internos usam); stack, capacity, item perdido; emite os eventos do Impacto.

## Em aberto

- Drop de item no chão quando inventário cheio — futuro; por ora ItemLostEvent.
