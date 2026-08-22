---
wave: 14.1
titulo: Água — o regador acaba, e regar vira rota
paralelo: nao
depende_de: [14]
---

## Objetivo

Dar limite ao relógio da fazenda. O regador é hoje o único item do jogo sem
limite: clicar rega, para sempre, de qualquer lugar. Com carga, regar deixa de
ser tarefa e vira **rota** — qual canto rego primeiro, vale a pena atravessar
até o poço, e o regador maior do ferreiro passa a ter motivo de existir.

Terreno é espaço; água é relógio. As duas restrições nasceram na mesma discussão
e são a mesma wave por decisão do usuário — a wave 14 registra o risco de
playtest disso em "Em aberto".

## Decisões

- **O poço é uma cobertura do `EstadoTerreno`.** É o mérito de ter juntado as
  duas mecânicas: `agua` entra na mesma tabela de mato, pedra e árvore, e encher
  o regador é "usar regador em tile `agua`". Nenhum sistema novo, nenhum ponto
  de interesse inventado — e é por isso que separar as waves obrigaria a reabrir
  a 14.
- **Carga mora no slot, capacidade mora no `ItemDef`.** `Slot.carga: int`
  (default 0) é estado; `ItemDef.capacidade_carga: int` (default 0) é
  balanceamento que o artista edita. Capacidade 0 significa "item que não
  carrega nada", que descreve corretamente tudo que já existe.
- **Quem desconta a carga é o `InventorySystem`.** O slot é dele, e ele roda
  antes do Farm. Mesma família do `PlantCropAction`, que já é cobrada lá — a
  diferença é que o custo é carga, não item. Custa um `if` novo num arquivo
  existente, e é o único jeito de a recusa por falta de água sair de quem sabe
  responder por ela.
- **Regar sem água é recusa, não ausência de ação.** `WaterPlotAction` sem carga
  emite `ActionRejectedEvent` com motivo `sem_agua`. O `null` do resolvedor
  continua reservado para "não há o que fazer aqui" — tile seco não arado, por
  exemplo. Recusa tem motivo e aparece no aviso; ausência é silêncio.
- **Encher é ação, não gesto de tela.** `EncherRegadorAction` passa pela fila
  inteira como qualquer outra. O resolvedor só a devolve em tile `agua`, do
  mesmo jeito que já não devolve `TillPlotAction` em tile arado.
- **Regador com 15 cargas, poço perto da casa.** Rega ~15 tiles por viagem, o
  que é uma manhã inteira no começo do jogo. O upgrade do ferreiro sobe para 30
  — é a progressão vertical herdada da mina (PRINCIPIOS §8) com destino já
  definido. Chute calibrado; ajuste é `.tres`.
- **Descartado: encher em qualquer tile molhado.** Regar um tile e reencher nele
  mesmo mataria a rota antes de ela existir. A água tem endereço.
- **Descartado: carga como estado do jogador em vez do slot.** Com dois
  regadores na mochila — o velho e o do ferreiro — o número teria que pertencer
  a um deles. Pertence ao slot desde o primeiro dia.

## Impacto

- **Eventos novos:** `RegadorEnchidoEvent`.
- **Ações novas:** `EncherRegadorAction`.
- **Sistema novo:** nenhum.
- **Muda formato de save:** sim, `Slot` ganha `carga`. **Sem migração** — campo
  novo com default 0, e save antigo carrega com o regador vazio. O jogador
  enche no primeiro poço e nunca percebe.
- **Arquivos existentes tocados: três.** `sim/items/inventory_state.gd`
  (`Slot.carga`), `sim/items/inventory_system.gd` (desconto e recusa) e
  `sim/items/resolvedor_uso.gd` (encher, e regar exigindo carga).
  `sim/items/item_def.gd` também ganha um campo, mas já está sendo editado pela
  14.4 — o mesmo arquivo, não um a mais.
- **Arte necessária:** 3 — regador cheio, regador vazio, tile de água/poço.
- **Playground:** medidor de carga na mira de ferramentas (`mira_ferramentas.gd`)
  e no slot da mão, mais o poço visível no mapa. Regar até acabar tem que ser
  legível sem abrir painel: o número na mão é o aviso.

## Tarefas

### 14.1.1 — Carga no slot
Cria: `tests/test_carga_slot.gd` (edita `sim/items/inventory_state.gd` e
`sim/items/item_def.gd`)
Depende de: 14.4
Faz: `Slot.carga` com default 0 no `to_dict`/`from_dict`, `is_default` ainda
verdadeiro para slot vazio sem carga, e `ItemDef.capacidade_carga` com default
0. O teste carrega um save da versão anterior e prova que ele abre com carga
zerada, sem migração.

### 14.1.2 — O gasto e a recusa
Cria: `tests/test_regar_sem_agua.gd` (edita `sim/items/inventory_system.gd`)
Depende de: 14.1.1
Faz: `InventorySystem.handle` reconhece `WaterPlotAction` — desconta 1 de carga
do slot na mão, ou marca `rejeitada` e emite `ActionRejectedEvent` com motivo
`sem_agua`. Item sem `capacidade_carga` na mão não gasta nada e não recusa: quem
rega com a mão vazia já era `null` no resolvedor.

### 14.1.3 — Encher
Cria: `sim/items/encher_regador_action.gd`,
`sim/items/regador_enchido_event.gd`, `tests/test_encher_regador.gd`
Depende de: 14.1.2
Faz: a ação, o evento e o caso no `ResolvedorUso` — regador na mão + tile `agua`
devolve `EncherRegadorAction`; o `InventorySystem` enche até
`capacidade_carga` e emite `RegadorEnchidoEvent`. Encher regador já cheio é
`null`, não recusa.

### 14.1.4 — A água na tela
Cria: `tests/test_medidor_carga.gd` (edita `game/dev/mira_ferramentas.gd` e
`game/dev/painel_mochila.gd`)
Depende de: 14.1.3
Faz: a carga aparece na mira e no slot da mão, atualizada por
`RegadorEnchidoEvent` e `PlotWateredEvent`. Reusa os rótulos em vez de recriar
nós — o `painel_mochila.gd` já carrega essa pendência desde a 12.1 e esta wave
não pode aumentá-la.

## Em aberto

- **Onde exatamente fica o poço.** "Perto da casa" é intenção, não coordenada. O
  número de tiles entre poço e canteiro é o que define se a rota é decisão ou
  pedágio — medir jogando.
- **Se o regador cheio deve ocupar o slot com peso diferente.** Hoje não; se um
  dia a mochila tiver peso, carga entra na conta.
- **O upgrade do ferreiro.** Capacidade 30 está decidida como destino, mas o
  formato do upgrade (item novo, ou o mesmo item com campo alterado) é a wave
  do ferreiro. Se for o mesmo item mudando de capacidade, `ItemDef` deixa de ser
  puramente estático — decidir lá, não aqui.
- **Chuva.** O dia chuvoso que rega tudo é a resposta óbvia do gênero para o
  tédio da rega, e ele existe no horizonte de clima. Se entrar, precisa custar
  algo — chuva grátis desmancha a rota que esta wave acabou de criar.
