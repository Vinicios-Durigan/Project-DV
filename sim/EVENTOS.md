# Eventos da simulação

Mantido pelas skills `/dev` e `/revisar` — não edite à mão.

| Evento | Quem emite | Quem escuta |
| --- | --- | --- |
| `MinuteTickedEvent` | `TimeSystem` (tick) | ninguém ainda — HUD do relógio na wave de `game/` |
| `DayEndedEvent` | `TimeSystem` (`SleepAction` → `SLEPT`; 02:00 → `COLLAPSED`) | ninguém ainda — resumo do dia, autosave e fadiga futura |
| `ActionRejectedEvent` | quem detecta a impossibilidade (`InventorySystem`, `ShippingSystem`, `FarmSystem`) | `game/` — feedback de "não dá"; sistemas seguintes só olham a flag `rejeitada` |
| `ItemAddedEvent` | `InventorySystem` (`AddItemAction`) | ninguém ainda — hotbar e popup de item na wave de `game/` |
| `ItemRemovedEvent` | `InventorySystem` (`RemoveItemAction`) | ninguém ainda — hotbar na wave de `game/` |
| `ItemLostEvent` | `InventorySystem` (mochila cheia) | ninguém ainda — aviso na tela; drop no chão é futuro |
| `MoneyChangedEvent` | `InventorySystem` (`AddMoneyAction`) | ninguém ainda — HUD de dinheiro na wave de `game/` |
| `ItemGrantedEvent` | qualquer mecânica que conceda item (hoje `FarmSystem`) | `InventorySystem` — reage adicionando à mochila |
| `PlotTilledEvent` | `FarmSystem` (`TillPlotAction`) | ninguém ainda — troca do tile para terra arada na wave de `game/` |
| `CropPlantedEvent` | `FarmSystem` (`PlantCropAction`) | ninguém ainda — sprite do estágio 0 na wave de `game/` |
| `PlotWateredEvent` | `FarmSystem` (`WaterPlotAction`) | ninguém ainda — variante molhada do tile e o ritmo de rega |
| `CropHarvestedEvent` | `FarmSystem` (`HarvestCropAction`) | `InventorySystem` (é um `ItemGrantedEvent`); `game/` anima o arco até o jogador |
| `CropGrewEvent` | `FarmSystem` (reage a `DayEndedEvent`) | ninguém ainda — é a cascata da manhã-espetáculo, na ordem dos plots |
| `CropDiedEvent` | `FarmSystem` (fim de estação, dia 28) | ninguém ainda — sprite de murcha na wave de `game/` |
| `ItemShippedEvent` | `ShippingSystem` (`ShipItemAction`, já cobrada pelo inventário) | ninguém ainda — painel do caixote na wave de `game/` |
| `ItemWithdrawnEvent` | `ShippingSystem` (`WithdrawItemAction`) | `InventorySystem` (é um `ItemGrantedEvent`) — o item volta para a mochila |
| `ItemsSoldEvent` | `ShippingSystem` (`SleepAction`, passo 1 da sequência de dormir) | `InventorySystem` — soma o dinheiro; `game/` monta o resumo do dia com estas linhas + `DayEndedEvent` |
| `SeedBoughtEvent` | `InventorySystem` (`BuySeedAction`) | ninguém ainda — aba de compra do painel na wave de `game/`; o `MoneyChangedEvent` e o `ItemAddedEvent` vêm logo atrás |
