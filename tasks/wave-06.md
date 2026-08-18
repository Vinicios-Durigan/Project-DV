---
wave: 06
titulo: Dev tools — parte sim (gravação e log)
paralelo: sim
depende_de: [05]
---

## Objetivo

Toda sessão deixa rastro: ações gravadas e eventos logados em arquivo — o bug report determinístico do GAMEPLAY.md §11, pronto antes do jogo ter tela.

## Decisões

- **DevSystem não existe**: cheats são ações formais já existentes (AddItemAction, AddMoneyAction, WaterPlotAction em lote) despachadas pelo console visual (wave futura de game/). Menos código, zero caminho paralelo.
- Gravação serializa ações por reflection (get_property_list) — nenhum to_dict manual em cada ação.
- Log de eventos em JSONL, um arquivo por sessão em `user://logs/`, com hora de jogo.
- Replay player fica pra depois; o formato gravado já nasce reproduzível (ordem + payload completo).
- `paralelo: sim` — as duas tarefas não se tocam e criam arquivos disjuntos.

## Impacto

- Eventos novos: nenhum.
- Muda formato de save: não.
- Arte necessária: nenhuma.
- Toca `game/`: não. Console F1, controle de velocidade e inspetor de tile entram na wave visual de dev.

## Tarefas

### 6.1 — ActionRecorder
Cria: sim/dev/action_recorder.gd, tests/test_action_recorder.gd
Faz: registra cada ação despachada (tipo + campos via reflection + dia/minuto de jogo) numa lista exportável para JSONL.

### 6.2 — EventLogger
Cria: sim/dev/event_logger.gd, tests/test_event_logger.gd
Faz: serializa cada SimEvent emitido (tipo + campos + hora de jogo) para JSONL em `user://logs/`; desligável em release.

## Em aberto

- Replay player (ler JSONL e reproduzir na sim) — wave futura, o formato já suporta.
