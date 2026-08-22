---
wave: 14
titulo: Terreno — o mapa fecha sozinho, e limpar é decisão
paralelo: nao
depende_de: [10, 12]
---

## Objetivo

Dar limite ao espaço da fazenda. Hoje o mapa nasce inteiro arável e nada
disputa o tile com o jogador: arar/plantar/regar/colher é uma sequência linear
onde não existe decisão que possa sair errada (PRINCIPIOS §7). O terreno é o
atrito que faltava na fazenda — entulho que trava a expansão, e mato que volta
se você preparou mais chão do que dá conta.

## Decisões

- **Spawn não é chance por tile, é propagação a partir de fontes.** "2% de
  nascer mato em cada quadrado livre" é o que transforma fazenda em manutenção:
  o jogador varre o mapa limpando ruído que apareceu sozinho. Aqui o mato só
  nasce **adjacente a mato ou a terreno selvagem** — limpar em bloco compacto se
  defende sozinho, limpar espalhado deixa você cercado. O layout da limpeza vira
  decisão de longo prazo, que é o §7.5 do GAMEPLAY entrando pela porta dos
  fundos, sem arte nova.
- **Aleatório na criação do mundo, determinístico depois.** A `semente_terreno`
  nasce no começo da partida e mora no save, como a do `EstadoContratos`. Cada
  save tem uma fazenda diferente; a mesma fazenda nunca surpreende duas vezes.
  Replay e bug report continuam confiáveis.
- **Mapa desenhado, entulho sorteado.** Fazenda inteiramente procedural nunca
  tem o canto bonito de propósito, e o artista não consegue compor o que muda a
  cada partida. O mapa é autoral; o que a semente sorteia é **onde estão as
  manchas** dentro dele. A água é a exceção: o poço tem posição fixa, desenhada.
- **Entulho permanente não respawna. Nunca.** Limpou, é seu para sempre. É isso
  que separa gate espacial de grind de coleta (PRINCIPIOS §8): a pedra que você
  quebrou não volta na semana que vem.
- **Limpar dá espaço, não dá item.** Madeira e pedra só têm para onde ir quando
  o carpinteiro existir, e item sem destino é lixo ocupando slot. O toco
  renovável — a fonte de madeira com endereço fixo, que custa espaço arável e
  devolve produção — é a wave do Bosque, depois do carpinteiro. Aqui o toco
  existe só como estado: dois golpes de machado, e não rebrota.
- **O mato cobre tile arado, nunca tile plantado.** Decidido em 2026-08-22. O
  que se perde é preparo que você não usou; arar de novo é um swing. Perder uma
  abóbora de 13 dias seria outro jogo, e romperia o §10 — punição pausa, não
  destrói.
- **A enxada capina.** Usar enxada em tile de mato limpa em vez de arar. O
  `ResolvedorUso` já decide por contexto e é o padrão da casa desde a 11.2 —
  zero slot novo, zero sprite de ferramenta nova.
- **Ferramenta declara o que consegue remover.** `ItemDef.alvos_de_limpeza`
  (`Array[String]`, default vazio) separa "o que faço em terra limpa"
  (`acao_de_uso`) de "o que consigo tirar do caminho". Enxada tira mato,
  picareta tira pedra, machado tira árvore e toco. Ferramenta nova continua
  sendo um `.tres`.
- **`SistemaTerreno` é o segundo da fila, logo depois de Locais.** Não é
  organização: `LimparTerrenoAction` precisa ser recusada **antes** de o
  Inventory cobrar qualquer coisa, mesma razão que pôs o `SistemaLocais` em
  primeiro na wave 12. A propagação da noite não depende da posição na fila —
  ela acontece em `react(DayEndedEvent)`, e a cascata já volta para sistemas
  anteriores.
- **Quem desara o tile coberto é o `FarmSystem`, reagindo ao evento.** O
  terreno não escreve em `FarmState`. Emite `TerrenoMudouEvent` e o dono do
  plot reage, exatamente como o `InventorySystem` reage ao `ItemGrantedEvent`.
- **O `SistemaTerreno` lê `FarmState`, mas nunca escreve.** Ele precisa saber se
  o tile arado tem cultura para não cobrir. Leitura pura de state alheio já tem
  precedente aberto pelo `ResolvedorUso` na 11.2; o que continua sendo só do
  dono é escrever.
- **Um evento gordo, não cinco magros.** `TerrenoMudouEvent(x, y, de, para,
  motivo)` cobre limpar, invadir, fechar e a geração inicial. Cinco eventos aqui
  seria inventar vocabulário para a mesma frase.
- **Números iniciais são balanceamento, não regra:** arado vazio fecha em
  **3 dias**, cada tile de mato tenta 1 vizinho por dia com **25%** de chance,
  **teto de 3 mudanças por dia** no mapa inteiro, entulho inicial em **~15% da
  área cultivável, em 9 manchas**. Sem teto, um save deixado correndo em ×60
  vira floresta.
- **Descartado: cavar a terra e achar item para vender.** É PRINCIPIOS §8 na
  cara — loot diário sem decisão: você vê, cava, embolsa, não dá para errar. A
  versão que sobrevive um dia é o ponto de cavar entregando **muda de árvore**
  ou insumo que só a cidade aceita, e ela fica fora do slice.
- **Descartado: forrageamento (flor, graveto pelo mapa).** Grind de coleta puro.

## Impacto

- **Eventos novos:** `TerrenoMudouEvent`.
- **Ações novas:** `LimparTerrenoAction`.
- **Sistema novo:** `SistemaTerreno`, em `sim/mundo/`, registrado no tick logo
  depois de `SistemaLocais`.
- **Muda formato de save:** sim, seção `terreno` nova. **Sem migração** — seção
  ausente significa terreno limpo, e o save do dev continua jogável. `ItemDef`
  ganha `alvos_de_limpeza` com default vazio: `.tres` antigo carrega.
- **Arquivos existentes tocados: quatro.** `sim/sim_factory.gd` (registro no
  tick + machado e picareta na entrega inicial), `sim/items/resolvedor_uso.gd`
  (limpar, e arar passa a exigir tile livre), `sim/items/item_def.gd` (o campo
  novo) e `sim/crops/farm_system.gd` (`react` ao `TerrenoMudouEvent`). Está
  acima do que o §12.7 gosta, e o motivo é honesto: a mecânica é sobre o
  **tile**, e o tile já era compartilhado entre fazenda e uso antes desta wave.
- **Arte necessária:** 5 tiles — mato (2 variações), pedra, árvore, toco. Os
  dois últimos já estavam previstos no `ARTE.md §3` como "bloqueiam passagem".
- **Playground:** a cobertura aparece **no mapa** (`mundo_esboco.gd`), não em
  painel de rail — a exigência travada na 12.1 vale aqui. O `inspetor_tile.gd`
  mostra a cobertura crua, e pular o dia tem que deixar a propagação visível,
  senão não há como calibrar os 25%.

## Tarefas

### 14.1 — EstadoTerreno
Cria: `sim/mundo/estado_terreno.gd`, `tests/test_estado_terreno.gd`
Faz: a cobertura de cada tile indexada por `"x:y"` (`livre`, `mato`, `pedra`,
`arvore`, `toco`, `agua`), a `semente_terreno` e a tabela de "limpar vira o
quê" (árvore → toco, toco → livre, pedra → livre, mato → livre, água não
limpa). Tile ausente do dicionário é `livre`, como o plot ausente é intocado.
`to_dict`/`from_dict` com default em todo campo. Sem propagação e sem RNG
rodando: só dado e consulta.

### 14.2 — SistemaTerreno
Cria: `sim/mundo/sistema_terreno.gd`, `sim/mundo/limpar_terreno_action.gd`,
`sim/mundo/terreno_mudou_event.gd`, `tests/test_sistema_terreno.gd`
Depende de: 14.1
Faz: geração inicial em manchas (9 sementes de mancha, caminhada aleatória,
~15% da área, tipo sorteado por mancha); trata `LimparTerrenoAction` recusando
por `ferramenta_errada` ou `nada_a_limpar`; reage a `DayEndedEvent` propagando
mato a partir de vizinhos e fechando arado vazio de 3 dias, respeitando o teto
diário. Emite `TerrenoMudouEvent` em toda mudança. Lê `FarmState` só para saber
se o tile tem cultura. Registra no tick em `sim/sim_factory.gd`, depois de
Locais.

### 14.3 — O tile que fecha
Cria: `tests/test_mato_cobre_arado.gd` (edita `sim/crops/farm_system.gd`)
Depende de: 14.2
Faz: `FarmSystem.react` aceita `TerrenoMudouEvent` e desara o plot quando a
cobertura deixa de ser `livre`. O teste é a decisão travada da wave: tile arado
vazio é coberto e perde o arado; tile com cultura **nunca** é coberto, nem
verde nem pronto.

### 14.4 — Limpar entra no usar
Cria: `tests/test_resolvedor_limpeza.gd` (edita `sim/items/resolvedor_uso.gd` e
`sim/items/item_def.gd`)
Depende de: 14.2
Faz: `ItemDef.alvos_de_limpeza` com default vazio; o resolvedor devolve
`LimparTerrenoAction` quando a cobertura do tile está na lista da ferramenta na
mão, e `arar` passa a exigir cobertura `livre`. Ordem das regras preservada:
cultura pronta continua tendo prioridade sobre tudo.

### 14.5 — O terreno no mapa do playground
Cria: `game/dev/paleta_terreno.gd` (edita `game/dev/mundo_esboco.gd`,
`game/dev/inspetor_tile.gd`, `sim/sim_factory.gd`)
Depende de: 14.2, 14.3
Faz: cada cobertura com sua cor no mapa do playground, piscando no
`TerrenoMudouEvent` como o canteiro pisca na cascata da manhã; o inspetor mostra
a cobertura crua do tile mirado; machado e picareta entram na entrega inicial da
`SimFactory`. Reusa os nós em vez de recriar a cada evento — o sintoma da
receita 3 §4 já custou duas pendências.

## Em aberto

- **Se a fazenda ficar chata, não vai dar para saber se foi o mato ou a
  caminhada até o poço.** A wave 14.1 (água) foi juntada a esta por decisão do
  usuário em 2026-08-22, contra a recomendação de separá-las. O mérito da junção
  é real — o poço é uma cobertura do `EstadoTerreno`, e separar obrigaria a
  reabrir esta wave. O risco de playtest fica registrado aqui.
- **Quantos tiles o jogador consegue limpar por dia.** 3 dias para o arado
  fechar só é justo se limpar for rápido o bastante para recuperar. Medir
  jogando antes de fechar o número.
- **O mato na virada da estação.** Dia 28 mata a cultura no chão e o tile fica
  arado e vazio — três dias depois ele fecha. Decidir se a virada é caso
  especial ou se perder o começo da estação nova faz parte.
- **Bloqueio de movimento.** Pedra e árvore bloqueiam passagem no `ARTE.md §3`,
  mas movimento é 100% `game/` e a sim não conhece a posição do jogador. Quem
  responde "dá para andar aqui" na wave de `game/` é uma consulta ao
  `EstadoTerreno`, não um `if` na cena — decidir o formato quando a wave chegar.
- **A wave do Bosque.** Toco renovável, madeira como item e muda de árvore
  dependem do carpinteiro existir. Sem ele, manter toco não tem sentido.
