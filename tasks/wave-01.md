---
wave: 01
titulo: Núcleo da sim — SimWorld e TimeSystem
paralelo: nao
depende_de: []
---

## Objetivo

O esqueleto da simulação rodando com o primeiro sistema real: tempo com dia útil, dormir e colapso — tudo testado, sem nada visual.

## Decisões

- Ações e eventos são dados puros sem método, um `class_name` por arquivo (sim/CLAUDE.md).
- `DayEndedEvent` já nasce com `cause: SLEPT | COLLAPSED` — evento gordo, consumidor futuro (GAMEPLAY.md §3).
- Todo state tem `to_dict()/from_dict()` com defaults desde o nascimento — base do save v1, sem SaveSystem ainda.
- Relógio interno anda em minutos (tick = 1 min de jogo); o passo de 10 min é só HUD, fora desta wave.
- Ordem fixa de sistemas fica declarada no SimWorld, mas com um sistema só ela ainda não é observável.

## Impacto

- Eventos novos: `MinuteTickedEvent`, `DayEndedEvent(cause)`
- Muda formato de save: cria o formato (v1). Sem migração — não existe save anterior.
- Arte necessária: nenhuma.
- Toca `game/`: não. Wave 100% `sim/` + `tests/`.

## Tarefas

### 1.1 — Bases de ação e evento ✅
Cria: sim/core/sim_action.gd, sim/core/sim_event.gd, tests/test_sim_core.gd
Faz: classes base. `SimAction` com `player_id: int = 0`; `SimEvent` vazio de lógica. Dados puros, sem método.

### 1.2 — Contrato de sistema ✅
Cria: sim/core/sim_system.gd, tests/test_sim_system.gd
Depende de: 1.1
Faz: base `SimSystem` com `tick() -> Array[SimEvent]` e `handle(action) -> Array[SimEvent]`, ambos devolvendo `[]` por default.

### 1.3 — SimWorld ✅
Cria: sim/sim_world.gd, tests/test_sim_world.gd
Depende de: 1.2
Faz: registro de sistemas em ordem fixa, `advance(ticks)` concatenando eventos na sequência, `handle(action)` oferecido a todos. Teste usa sistemas fake para provar ordem e concatenação.

### 1.4 — Dados do tempo ✅
Cria: sim/time/time_state.gd, sim/time/sleep_action.gd, sim/time/day_ended_event.gd, sim/time/minute_ticked_event.gd, tests/test_time_state.gd
Depende de: 1.1
Faz: `TimeState` (dia, minuto, estação, defaults + to_dict/from_dict) e os dados de ação/evento do tempo. `DayEndedEvent` com `cause` e `dia_encerrado`/`dia_novo`.

### 1.5 — TimeSystem ✅
Cria: sim/time/time_system.gd, tests/test_time_system.gd
Depende de: 1.2, 1.4
Faz: tick avança 1 min e emite `MinuteTickedEvent`; dia útil 06:00→02:00; `SleepAction` → `DayEndedEvent(SLEPT)` e acorda 06:00 do dia seguinte; às 02:00 sem dormir → `DayEndedEvent(COLLAPSED)`; dia 28 → volta ao dia 1 (flag de fim de estação no evento).

## Em aberto

- Ordem final Shipping→Farm→Time só se materializa quando os sistemas das próximas waves existirem.
- `estacao` fica no state desde já, mas com valor fixo "primavera" no slice.
