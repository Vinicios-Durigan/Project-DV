---
wave: 04
titulo: Caixote — depósito, compra e venda ao dormir
paralelo: nao
depende_de: [03]
---

## Objetivo

O loop econômico fecha: depositar no caixote, comprar sementes, e a venda concretizando na sequência de dormir com as linhas do resumo.

## Decisões

- Depositar: InventorySystem (primeiro na ordem) valida e consome o item, ou rejeita; ShippingSystem adiciona ao caixote.
- Retirar: ShippingSystem valida e remove, emite `ItemWithdrawnEvent`; InventorySystem reage devolvendo ao inventário (venda só concretiza ao dormir — arrependimento permitido, GAMEPLAY.md §4).
- Venda no dormir via ordem de handle: SleepAction passa por Inventory (nada) → **Shipping vende tudo** e emite `ItemsSoldEvent` com linhas (item, qtd, preço, subtotal) e total → Farm cresce → Time avança. A ordem fixa implementa a sequência do GAMEPLAY.md §3.
- Compra de semente é 100% InventorySystem + catálogo (preço vem do CropDef, definição é leitura livre): valida dinheiro, debita, adiciona semente, emite `SeedBoughtEvent`. Caixote não participa — a "aba de compra" é só UI.
- Resumo do dia não tem sistema: game/ monta a tela com ItemsSoldEvent + DayEndedEvent.

## Impacto

- Eventos novos: ItemShippedEvent, ItemWithdrawnEvent, ItemsSoldEvent, SeedBoughtEvent
- Muda formato de save: adiciona bloco `shipping` (v1).
- Arte necessária: nenhuma nesta wave.
- Toca `game/`: não. Altera `sim/items/inventory_system.gd` (compra e reações).

## Tarefas

### 4.1 — ShippingState
Cria: sim/shipping/shipping_state.gd, tests/test_shipping_state.gd
Faz: lista de itens depositados (item_id, qtd); defaults + to_dict/from_dict.

### 4.2 — ShippingSystem: depositar e retirar
Cria: sim/shipping/shipping_system.gd, tests/test_shipping_system.gd
Depende de: 4.1
Faz: ShipItemAction (pós-validação da cadeia) e WithdrawItemAction; emite ItemShippedEvent/ItemWithdrawnEvent.

### 4.3 — Venda ao dormir
Cria: tests/test_shipping_sale.gd
Altera: sim/shipping/shipping_system.gd
Depende de: 4.2
Faz: handle de SleepAction esvazia o caixote, calcula linhas e total pelo catálogo, emite ItemsSoldEvent.

### 4.4 — Compra de sementes e reações de dinheiro
Cria: tests/test_seed_purchase.gd
Altera: sim/items/inventory_system.gd
Depende de: 4.2
Faz: BuySeedAction (valida dinheiro, debita, adiciona semente, SeedBoughtEvent); react a ItemsSoldEvent somando dinheiro e emitindo MoneyChangedEvent.

### 4.5 — Teste integrado do dia completo
Cria: tests/test_dia_completo.gd
Depende de: 4.3, 4.4
Faz: cenário única sim: comprar semente → arar → plantar → regar → dormir N vezes → colher → depositar → dormir → dinheiro final bate na conta. Prova a ordem Inventory→Shipping→Farm→Time inteira.

## Em aberto

- Preço de venda no ItemDef vs CropDef (colheita usa qual?) — decidir na 4.3: fonte única é ItemDef; CropDef aponta o item colhido.
