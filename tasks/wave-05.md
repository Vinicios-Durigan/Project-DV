---
wave: 05
titulo: Save/load — snapshot versionado
paralelo: nao
depende_de: [04]
---

## Objetivo

A sim inteira vira um JSON versionado que volta idêntico: snapshot, escrita atômica em disco e trilho de migração pronto para o futuro.

## Decisões

- `SimWorld.snapshot()` agrega os to_dict dos states + `save_version: 1`; `restore(dict)` reconstrói — roundtrip perfeito é o teste.
- Escrita em `user://saves/slot_1.json` com escrita atômica (temp + rename) — queda de energia nunca corrompe save.
- Migração é registry: `save_version` → função de upgrade, aplicadas em cadeia até a atual. v1 = identidade. A skill `revisar-save` passa a valer para qualquer mudança de state daqui em diante.
- Autosave ao dormir é responsabilidade de game/ (SimBridge chama ao ver DayEndedEvent) — fora desta wave; aqui só a API pronta.

## Impacto

- Eventos novos: nenhum (save não é fato da simulação).
- Muda formato de save: **cria o arquivo em disco** — v1 congela aqui.
- Arte necessária: nenhuma.
- Toca `game/`: não.

## Tarefas

### 5.1 — [x] Snapshot e restore no SimWorld
Cria: tests/test_snapshot.gd
Altera: sim/sim_world.gd
Faz: snapshot() agregando states registrados por chave (time, inventory, farm, shipping); restore() com defaults para chave ausente; teste de roundtrip com estado rico.

### 5.2 — [x] SaveManager
Cria: sim/save/save_manager.gd, tests/test_save_manager.gd
Depende de: 5.1
Faz: dict↔JSON↔disco com escrita atômica, slot nomeado, leitura de arquivo ausente devolve null (jogo novo).

### 5.3 — [x] Registry de migrações
Cria: sim/save/save_migrations.gd, tests/test_save_migrations.gd
Depende de: 5.2
Faz: mapa versão→função aplicado em cadeia no load; teste carrega dict v1 e um v0 sintético para provar o trilho.

## Em aberto

- Múltiplos slots e save manual — fora do slice.
- Fixture congelado do save v1 em `tests/saves/v1_exemplo.json` + teste de carga:
  só vira obrigatório quando o formato subir para v2 (a skill `revisar-save`
  exige o save da versão **anterior**; hoje não existe anterior). Anotado aqui
  para não passar batido na wave que mudar um state.
