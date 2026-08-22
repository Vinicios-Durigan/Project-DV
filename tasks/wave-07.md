---
wave: 07
titulo: Ponte — a sim ganha tempo real e disco
paralelo: nao
depende_de: [06]
---

## Objetivo

A sim roda em tempo real dentro da Godot, com preço único de venda, autosave ao dormir — um dia de jogo passa de verdade, visível no log JSONL, antes de existir um pixel.

## Decisões

- **Preço só no ItemDef**: `CropDef.preco_venda` morre; o caixote vende itens, não culturas. Peixe e minério futuros entram pelo mesmo caminho.
- **Montagem do mundo é regra de jogo**: a ordem Inventory → Shipping → Farm → Time mora numa fábrica em `sim/`, não na bridge. `game/` não decide ordem de sistema.
- **`time_scale` (×1/×10/×60) nasce na bridge**: o dev tools vai pedir; enfiar depois mexeria no laço de tick que todos dependem.
- **Sem autoload**: bridge é nó de `main.tscn`, desce por `setup(bridge)` — regra do game/CLAUDE.md.
- 1 min de jogo = 0.75s real (GAMEPLAY §3).

## Impacto

- Eventos novos: nenhum.
- Muda formato de save: não (definição, não estado).
- Arte necessária: nenhuma.
- Toca `game/`: sim — primeiros arquivos de game/ (bridge e gateway de save).

## Tarefas

### 7.1 — Fonte única de preço ✅
Cria: data/items/*.tres (8: 4 colheitas + 4 sementes), tests/test_item_defs.gd
Muda: sim/crops/crop_def.gd (remove preco_venda), data/crops/*.tres
Faz: todo item vendável tem ItemDef com preço; teste prova que toda cultura tem semente e colheita registradas com preço > 0.

### 7.2 — SimFactory ✅
Cria: sim/sim_factory.gd, tests/test_sim_factory.gd
Faz: monta o SimWorld completo — catálogos de data/, 4 sistemas na ordem fixa, states registrados no save. Pura, headless.

### 7.3 — SimBridge ✅
Cria: game/sim_bridge.gd, game/main.tscn
Depende de: 7.2
Faz: acumula delta, advance() a cada 0.75s reais com time_scale, reemite SimEvent como sinal, expõe dispatch(action). Pluga ActionRecorder e EventLogger.

### 7.4 — SaveGateway ✅
Cria: game/save_gateway.gd
Depende de: 7.3
Faz: carrega slot no boot (ausente = jogo novo), autosave ao ouvir DayEndedEvent.

## Em aberto

- Resumo do dia na tela — wave do playground mostra as linhas do ItemsSoldEvent.
