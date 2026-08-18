# Eventos da simulação

Mantido pelas skills `/dev` e `/revisar` — não edite à mão.

| Evento | Quem emite | Quem escuta |
| --- | --- | --- |
| `MinuteTickedEvent` | `TimeSystem` (tick) | ninguém ainda — HUD do relógio na wave de `game/` |
| `DayEndedEvent` | `TimeSystem` (`SleepAction` → `SLEPT`; 02:00 → `COLLAPSED`) | ninguém ainda — resumo do dia, autosave e fadiga futura |
| `ActionRejectedEvent` | quem detecta a impossibilidade (hoje `InventorySystem`) | `game/` — feedback de "não dá"; sistemas seguintes só olham a flag `rejeitada` |
| `ItemAddedEvent` | `InventorySystem` (`AddItemAction`) | ninguém ainda — hotbar e popup de item na wave de `game/` |
| `ItemRemovedEvent` | `InventorySystem` (`RemoveItemAction`) | ninguém ainda — hotbar na wave de `game/` |
| `ItemLostEvent` | `InventorySystem` (mochila cheia) | ninguém ainda — aviso na tela; drop no chão é futuro |
| `MoneyChangedEvent` | `InventorySystem` (`AddMoneyAction`) | ninguém ainda — HUD de dinheiro na wave de `game/` |
