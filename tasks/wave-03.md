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

### 3.1 — CropDef e catálogo de culturas ✅
Cria: sim/crops/crop_def.gd, sim/crops/crop_catalog.gd, tests/test_crop_catalog.gd
Faz: Resource com id, nome, dias_por_estagio, preco_semente, preco_venda, colheitas_infinitas, bloqueia_movimento, sprite paths; catálogo carrega `data/crops/*.tres`.

### 3.2 — FarmState ✅
Cria: sim/crops/farm_state.gd, tests/test_farm_state.gd
Faz: dict de plots "x:y" → {arada, regada, crop_id, estagio, dias_no_estagio}; defaults + to_dict/from_dict.

### 3.3 — FarmSystem: as 4 ações ✅
Cria: sim/crops/farm_system.gd, tests/test_farm_system.gd
Depende de: 3.1, 3.2
Faz: TillPlotAction, PlantCropAction, WaterPlotAction, HarvestCropAction — validações de tile (arado, vazio, pronta), eventos do Impacto. Ação inválida: sem mudança, sem evento (ou ActionRejectedEvent quando a cadeia exigir).

### 3.4 — Crescimento na virada do dia ✅
Cria: tests/test_crop_growth.gd
Altera: sim/crops/farm_system.gd
Depende de: 3.3
Faz: react a DayEndedEvent — regadas avançam dias_no_estagio/estágio, reset de rega, rebrota, fim de estação mata; emite CropGrewEvent/CropDiedEvent por planta, na ordem dos plots.

### 3.5 — As 4 culturas e o ciclo completo ✅
Cria: data/crops/rabanete.tres, data/crops/cenoura.tres, data/crops/abobora.tres, data/crops/morango.tres, tests/test_ciclo_culturas.gd
Depende de: 3.4
Faz: valores da tabela do GAMEPLAY.md §5; teste integrado plantar→regar N dias→colher→rebrota do morango→lucro bate com a fórmula.

## Fora do escopo declarado (feito nesta wave)

- `sim/items/item_granted_event.gd` (novo) + `react()` em `sim/items/inventory_system.gd`:
  a decisão "InventorySystem reage adicionando" exigia dar um `react()` ao
  inventário, e o arquivo não estava declarado em nenhuma tarefa. Feito de forma
  genérica — o inventário reage a `ItemGrantedEvent`, não a colheita — para que
  pesca, presente e recompensa futuros não voltem a mexer nele.
- As ações e eventos de `sim/crops/` viraram um arquivo cada (`class_name` por
  arquivo, regra do CLAUDE.md); a tarefa 3.3 só citava `farm_system.gd`.

## Resolvido

- **Ordem dos eventos de crescimento** (congelada em `tests/test_crop_growth.gd`):
  duas passadas — primeiro todo o crescimento, depois toda a morte de fim de
  estação; dentro de cada passada, plots por linha (`y`) e depois coluna (`x`).
- **Estágios**: `dias_por_estagio` são os dias para **sair** de cada estágio;
  estágios = tamanho da lista + 1 e o ciclo é a soma. As 4 culturas têm 3
  entradas → 4 estágios, que é o que a lista de arte do GAMEPLAY §12 pede.
- **Semente**: `PlantCropAction extends RemoveItemAction`, então o inventário
  cobra a semente antes do FarmSystem olhar o tile (é a ordem fixa). Para o
  jogador não perder semente em tile inválido, `game/` pergunta antes com
  `FarmSystem.pode_plantar()` — mesma consulta que pinta o retículo.

## Em aberto

- Reset da rega na virada do dia não emite evento próprio: `game/` seca a terra
  ao ver o `DayEndedEvent`. Se a manhã-espetáculo precisar animar tile a tile,
  vira `PlotDriedEvent` numa wave futura.
- A suíte GUT não rodou nesta máquina — o binário do Godot não está no `PATH`.
