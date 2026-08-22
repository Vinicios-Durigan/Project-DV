---
wave: 10
titulo: Esboço do mundo — locais, viagem e mira
paralelo: nao
depende_de: [07, 08]
---

## Objetivo

O jogador vira um quadrado que anda: fazenda e cidade são lugares de verdade,
ir de um ao outro custa o tempo real da caminhada, e **só se age onde se está**.

## Decisões

- **Posição em pixel é `game/`; o local é `sim/`.** A sim nunca vê coordenada —
  ela sabe apenas em que local (`FAZENDA`, `CIDADE`) cada jogador está. Quem
  percebe a travessia da fronteira é `game/`, que despacha `ViajarAction`.
- **Viagem não tem número mágico.** O custo de ir à cidade é o tempo que o
  relógio anda enquanto o jogador caminha até lá (1 min de jogo = 0,75s reais,
  GAMEPLAY §3). A distância do mapa é a ferramenta de balanceamento — cidade
  longe é cidade cara.
- **Só age onde está** (decisão de presença, 2026-08-21): regar na cidade é
  recusado com motivo. O `SistemaLocais` registra **antes** de todos os outros
  e carimba `rejeitada` + `ActionRejectedEvent` na ação fora de lugar; os
  sistemas seguintes só olham a flag — padrão que já existe desde a wave 02.
- **O gate mora centralizado no `SistemaLocais`** (mapa ação → local exigido).
  É a solução de esboço: nenhum arquivo existente muda. Se o mapa crescer
  demais, revisita-se na wave da cidade.
- **Velocidade 4,5 tiles/s** (GAMEPLAY §1), tile de 16px — o esboço usa a
  velocidade real para o playtest de distância valer.
- **Regra de jogo nunca desabilita botão nem tecla**: a ação sempre vai à sim,
  e a recusa volta como evento com motivo (design system aprovado, seção de
  feedback).
- **Mouse manda na mira, com espaço mantido** (pedido no playtest, previsto em
  GAMEPLAY §13). Cursor sobre o mapa define o alvo; fora dele o facing
  reassume. O espaço fica porque é ele que sustenta a promessa de gamepad e
  co-op.
- **Alcance de 1 tile, julgado em `game/`.** Sem limite, dá para arar a fazenda
  inteira clicando de longe e andar deixa de custar tempo — o que mataria a
  mecânica desta wave. É a única regra que `game/` julga, e só podia ser lá:
  GAMEPLAY §8 tira a posição do jogador da sim, então a sim não tem como
  medir distância. Valor a calibrar jogando.
- **Esboço quer dizer esboço**: retângulos coloridos, sem colisão com
  obstáculo, sem câmera, sem animação além do necessário. Juice é wave 11.
- Nomes novos em português (CLAUDE.md, "Tudo em português").

## Impacto

- Eventos novos: `JogadorViajouEvent` (player_id, de, para). Sem campo de
  minuto: a hora é carimbada pelo EventLogger/feed, como em todo evento.
- Rejeições novas: ação de fazenda fora da fazenda, via `ActionRejectedEvent`
  com motivo legível.
- Muda formato de save: bloco novo `locais`, default `FAZENDA` para todo
  jogador — sem migração, versão continua 1.
- Arte necessária: nenhuma.
- Toca `game/`: só `game/dev/`. O `farm_grid` continua existindo como
  implementação de referência do padrão 2; o mundo de esboço passa a ser o
  painel central.

## Tarefas

### 10.1 — EstadoLocais ✅
Cria: sim/mundo/estado_locais.gd, tests/test_estado_locais.gd
Faz: local atual por `player_id`, com default `FAZENDA`, `to_dict`/`from_dict`
e defaults que preservam save antigo.

### 10.2 — SistemaLocais ✅
Cria: sim/mundo/sistema_locais.gd, sim/mundo/viajar_action.gd, sim/mundo/jogador_viajou_event.gd, tests/test_sistema_locais.gd
Muda: sim/sim_factory.gd (registro do sistema e do state), tests/test_sim_factory.gd (a ordem e as chaves do save são asserts lá)
Depende de: 10.1
Faz: processa `ViajarAction` (muda local, emite `JogadorViajouEvent`) e gateia
as ações de fazenda pelo mapa ação → local, carimbando rejeição com motivo.
Registrado **antes do Inventory** no tick central: `PlantCropAction` estende
`RemoveItemAction`, e sem o carimbo vir primeiro o inventário debitaria a
semente de uma ação que vai ser recusada.

### 10.3 — Mundo de esboço ✅
Cria: game/dev/mundo_esboco.gd
Muda: game/dev/playground.tscn (o mundo entra no lugar do FarmGrid na cena; o
arquivo do grid fica como implementação de referência do padrão 2)
Depende de: 10.2
Faz: quadrado do jogador (creme, 16×32 em escala) andando com WASD a 4,5
tiles/s, dois terrenos (fazenda e cidade) com faixa de passagem, fronteira
despacha `ViajarAction`. Cores da paleta aprovada, chapadas.

### 10.4 — Mira e ferramentas ✅
Cria: game/dev/mira_ferramentas.gd
Depende de: 10.3
Faz: retículo no tile alvo — mouse quando o cursor está sobre o mapa, facing
quando não (GAMEPLAY §1 e §13) —, ferramenta nas teclas 1–4, clique esquerdo ou
espaço despacha a ação. Alcance de 1 tile julgado aqui. Canteiros desenhados
pelos dois canais: solo claro/escuro = rega, quadrado verde que cresce =
estágio.

### 10.5 — Inspetor do tile ✅
Cria: game/dev/inspetor_tile.gd
Depende de: 10.4
Faz: painel com o estado cru do tile mirado, lido do `snapshot()` — cultura,
estágio, regada, pronta. Zero API nova (padrão da wave 08).

## Em aberto

- Terceiro local (`CASA`) — hoje dormir é ação de qualquer lugar; quando a casa
  virar lugar, dormir pode exigir estar nela. Decidir na wave da cara.
- Tamanho do mapa de esboço — começar com fazenda e cidade separadas por ~15
  tiles de caminho e ajustar jogando com o medidor do dia (wave 11).
- Viagem em velocidade ×60 — o quadrado atravessa o mapa em segundos reais;
  ver se o gate por local segura ou se precisa de regra extra.
- **Alcance de 1 tile** — calibrar jogando. Curto demais irrita ao regar em
  fileira; longo demais devolve o problema de arar de longe.
