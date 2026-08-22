---
wave: 09
titulo: Pedido do dia
paralelo: nao
depende_de: [07, 08]
---

## Objetivo

O caixote acorda com uma encomenda — "hoje cenoura paga 2×" — e a decisão diária deixa de ser "plante sempre o mais caro".

## Decisões

- **Um pedido por dia, cultura sorteada, multiplicador fixo 2×** sobre o preço de venda da colheita. Variedade de formato (metas de quantidade) fica pra depois.
- **Sorteio determinístico**: semente do RNG mora no state e entra no save. Mesmo save, mesma sequência de pedidos — replay e bug report continuam confiáveis.
- **Shipping não lê o state do pedido**: reage a `DailyOrderPostedEvent` e guarda item+multiplicador no próprio state. Regra de comunicação da wave 02.
- **Dia 1 não tem pedido**; o primeiro chega na manhã do dia 2, junto com a cascata da virada. Evita caso especial de boot.
- Ordem de registro: Inventory → Shipping → Farm → Time → **DailyOrder** (só reage a evento; posição no fim, documentada).

## Impacto

- Eventos novos: `DailyOrderPostedEvent` (item_id, multiplicador, dia).
- Muda evento existente: `ItemsSoldEvent.Linha` ganha `multiplicador` (default 1) — evento gordo pro resumo do dia mostrar o bônus.
- Muda formato de save: bloco novo `daily_order` + campos novos no `shipping`, todos com default — sem migração, versão continua 1.
- Arte necessária: nenhuma.
- Toca `game/`: só o painel do playground.

## Tarefas

### 9.1 — DailyOrderState
Cria: sim/orders/daily_order_state.gd, tests/test_daily_order_state.gd
Faz: pedido atual (item_id, multiplicador, dia) + semente do RNG, com to_dict/from_dict e defaults.

### 9.2 — DailyOrderSystem
Cria: sim/orders/daily_order_system.gd, sim/orders/daily_order_posted_event.gd, tests/test_daily_order_system.gd
Depende de: 9.1
Faz: reage a DayEndedEvent, sorteia cultura do catálogo com o RNG do state e emite DailyOrderPostedEvent.

### 9.3 — Bônus na venda
Muda: sim/shipping/shipping_system.gd, sim/shipping/shipping_state.gd, sim/shipping/items_sold_event.gd
Cria: tests/test_daily_order_sale.gd
Depende de: 9.2
Faz: shipping reage ao pedido, guarda no próprio state e aplica o multiplicador na linha certa do _sell_all.

### 9.4 — Painel do pedido no playground
Cria: game/dev/order_panel.gd
Depende de: 9.3
Faz: mostra o pedido do dia ("cenoura 2× hoje") escutando DailyOrderPostedEvent; usa o padrão 3 (escutar avisos).

## Em aberto

- Pedido no dia 1 via SimFactory (sortear no boot) — decidir quando o playground mostrar a lacuna.
- Metas de quantidade ("10 rabanetes até sexta") — formato futuro.
