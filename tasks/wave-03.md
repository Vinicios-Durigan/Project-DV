---
wave: 03
titulo: Culturas — arar, plantar, regar, colher, crescer
paralelo: nao
depende_de: [02]
---

## Objetivo

O coração do jogo: as 4 ações de fazenda funcionando sobre tiles, crescimento na virada do dia, rebrota e fim de estação — tudo por ação/evento, testado sem tela.

## Decisões

- Plantar valida em cadeia (wave 02): InventorySystem consome a semente ou rejeita a ação antes do FarmSystem tocar o tile.
- Colher: FarmSystem valida "pronta", emite `CropHarvestedEvent(item_id, qtd)`; InventorySystem reage adicionando.
- Cultura não regada pausa; rebrota volta ao estágio anterior ao "pronta" (`colheitas_infinitas`); fim de estação (dia 28) mata culturas no chão (`CropDiedEvent`).
- `bloqueia_movimento` no CropDef, default false — sim ignora, game/ vai ler.
- Definição de cultura via `.tres` em `data/crops/` — usar a skill `nova-cultura` para cada uma.

## Impacto

- Eventos novos: PlotTilledEvent, CropPlantedEvent, PlotWateredEvent, CropHarvestedEvent, CropGrewEvent, CropDiedEvent
- Muda formato de save: adiciona bloco `farm` (v1).
- Arte necessária: nada nesta wave (sprites entram na wave visual; CropDef guarda os paths).
- Toca `game/`: não.

## Tarefas

### 3.1 — CropDef e catálogo de culturas
Cria: sim/crops/crop_def.gd, sim/crops/crop_catalog.gd, tests/test_crop_catalog.gd
Faz: Resource com id, nome, dias_por_estagio, preco_semente, preco_venda, colheitas_infinitas, bloqueia_movimento, sprite paths; catálogo carrega `data/crops/*.tres`.

### 3.2 — FarmState
Cria: sim/crops/farm_state.gd, tests/test_farm_state.gd
Faz: dict de plots "x:y" → {arada, regada, crop_id, estagio, dias_no_estagio}; defaults + to_dict/from_dict.

### 3.3 — FarmSystem: as 4 ações
Cria: sim/crops/farm_system.gd, tests/test_farm_system.gd
Depende de: 3.1, 3.2
Faz: TillPlotAction, PlantCropAction, WaterPlotAction, HarvestCropAction — validações de tile (arado, vazio, pronta), eventos do Impacto. Ação inválida: sem mudança, sem evento (ou ActionRejectedEvent quando a cadeia exigir).

### 3.4 — Crescimento na virada do dia
Cria: tests/test_crop_growth.gd
Altera: sim/crops/farm_system.gd
Depende de: 3.3
Faz: react a DayEndedEvent — regadas avançam dias_no_estagio/estágio, reset de rega, rebrota, fim de estação mata; emite CropGrewEvent/CropDiedEvent por planta, na ordem dos plots.

### 3.5 — As 4 culturas e o ciclo completo
Cria: data/crops/rabanete.tres, data/crops/cenoura.tres, data/crops/abobora.tres, data/crops/morango.tres, tests/test_ciclo_culturas.gd
Depende de: 3.4
Faz: valores da tabela do GAMEPLAY.md §5; teste integrado plantar→regar N dias→colher→rebrota do morango→lucro bate com a fórmula.

## Em aberto

- Ordem exata dos eventos de crescimento (por plot, linha a linha) — definir no teste 3.4 e nunca mais mudar (game/ vai animar a cascata da manhã nessa ordem).
