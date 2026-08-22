---
wave: 15.1
titulo: Comida — o pão deixa de ser mercadoria e vira socorro
paralelo: nao
depende_de: [12, 15]
---

## Objetivo

Dar ao jogador uma saída quando ele erra a conta do próprio corpo. A estamina
da wave 15 só desce, e nada a repõe antes de dormir: comer é o que transforma
"vou desmaiar" numa decisão em vez de num aviso.

## A leitura que define a wave

**Comida não é combustível. É resgate.**

A wave 15 travou um alvo de calibragem: *um dia cheio de trabalho termina com a
barra raspando*. Se esse alvo for atingido, a estamina acaba **junto** com o
relógio — e comida como extensor de dia não teria para onde ir. O jogador
recuperaria 100 de estamina às 20:00 e não teria relógio sobrando para gastar.
O item viraria decoração, que é exatamente o destino que a wave 15 tentou
evitar para a própria estamina.

Então o momento da comida é outro: você come quando **apertou demais**. A barra
em 12, o mapa inteiro pela frente, e a escolha entre queimar um pão de 260g ou
perder metade do dia de amanhã.

A conta é apertada de propósito. Desmaiar custa 100 de estamina no dia
seguinte; um pão restaura 100 e evita o desmaio — ele paga exatamente o
prejuízo, e nada além. Às vezes vale, às vezes é melhor desmaiar mesmo. Isso é
o §7 em uma linha.

## Decisões

- **Come-se em qualquer lugar.** A comida não custa relógio diretamente porque
  quem já cobrou o tempo foi a cadeia que a produziu: 4h no moinho, 8h na
  padaria, duas viagens e cota presa nos dois. Cobrar rota de novo seria o
  terceiro preço do mesmo pão, e transformaria o resgate em algo que chega
  tarde demais para salvar.
- **A saciedade é o freio.** Cada refeição do dia vale menos que a anterior:
  **100%, 50%, 25%, 10%** do valor do item. Zera ao dormir. Sem isso a
  estratégia ótima é mochila cheia de pão e o corpo deixa de existir — e o
  atrito padrão do projeto é limite (§7).
- **A saciedade cria a decisão de *quando*.** Comer cedo desperdiça a refeição
  cheia; comer tarde arrisca não chegar lá. O item é o mesmo, o valor não.
- **Cultura crua alimenta pouco.** Cenoura restaura 25, pão restaura 100. O
  jogador sobrevive sozinho no começo, mal e porcamente, e a cidade é o upgrade
  — a mesma curva de dependência do resto do jogo. Fechar a porta no dia 3,
  quando ainda não há relação com a padaria, seria punir a única fase em que
  ele não tem escolha.
- **Comer com a barra cheia é recusado.** `ComerAction` estende
  `RemoveItemAction`, então o `InventorySystem` cobra o item **antes** de o
  corpo olhar qualquer coisa — a mesma armadilha de `EntregarAction` e
  `PlantCropAction`. Por isso existe `pode_comer()`, e é a resposta dela que
  `game/` consulta antes de despachar (receita 2, §4). Sem isso, um clique
  errado queima 260g em silêncio, e item sumindo sem aviso é o pior tipo de bug.
- **Com a saciedade no fundo, comer não é recusado.** Restaura pouco, mas a
  decisão é do jogador. A tela mostra o valor **efetivo** antes do clique.
- **Desmaiado não come.** Chegou a zero, o dia acabou. Comida é o que evita o
  desmaio, nunca o que o desfaz.
- **O `SistemaCorpo` passa a tratar uma ação.** O cabeçalho dele diz hoje que
  ele não trata nenhuma, e que isso é decisão. O motivo original continua
  valendo — ele segue sem validar trabalho —, mas a frase deixa de ser
  verdadeira e é reescrita nesta wave. Mudança de contrato declarada, não
  silenciosa.

## Números de partida

Chutes para calibrar jogando, como a estamina e o `DIAS_POR_CONTRATO`.

| Comida | Restaura | Vende por | Leitura |
| --- | --- | --- | --- |
| Pão | 100 | 260g | Metade da barra. A apólice de seguro do jogo |
| Abóbora | 55 | 180g | Cara e sazonal |
| Cenoura | 25 | 65g | O bico de emergência |
| Morango | 20 | 45g | — |
| Rabanete | 15 | 35g | Quase nada, mas é o que existe no dia 3 |
| Trigo, farinha | 0 | — | Não se come cru |

**Saciedade:** 1ª refeição do dia 100% · 2ª 50% · 3ª 25% · 4ª em diante 10%.

## Impacto

- **Ação nova:** `ComerAction`, estendendo `RemoveItemAction` — o inventário
  cobra o item e recusa por `item_insuficiente`, o mesmo truque de
  `EntregarAction`
- **Evento novo:** `ComeuEvent`, levando `item_id`, `de`, `para`, `restaurou` e
  `refeicao` — a tela desenha a barra e conta a saciedade sem abrir state nenhum
- **Consulta nova:** `SistemaCorpo.pode_comer(player_id, item_id)`, no espírito
  de `pode_entregar()` e `pode_plantar()`
- **`ItemDef` ganha `restaura_estamina`**, default 0 = não é comida. Comida
  nova é `.tres` novo, zero código — a mesma promessa de cultura e item
- **Muda formato de save:** campo `refeicoes_hoje` no bloco `corpo`, que já
  existe, com default 0 — **sem migração**
- **Toca sistema existente:** um, o `SistemaCorpo`, que ganha `handle()` e tem
  o cabeçalho reescrito
- **Arte necessária:** nenhuma

## Tarefas

### 15.1.1 — A comida vira conteúdo
Altera: `sim/items/item_def.gd`, `tests/test_item_defs.gd`
Cria: nada de código — os valores entram nos `.tres` de `data/items/`
Faz: campo `restaura_estamina` com default 0 e um `alimenta()` que responde se
o item é comida. Preenche os cinco `.tres` da tabela acima. O teste prende que
`.tres` sem o campo continua inerte e que ferramenta nunca alimenta.

### 15.1.2 — O corpo aprende a receber
Altera: `sim/corpo/estado_corpo.gd`, `tests/test_estado_corpo.gd`
Depende de: —
Faz: `refeicoes_hoje` no state, `restaura(player_id, quanto)` com teto na
estamina máxima, e a contagem zerando na virada do dia. Hoje só existem
`enche` e `enche_metade`. State burro: ele não sabe o que é saciedade, só
guarda quantas refeições houve.

### 15.1.3 — Comer
Cria: `sim/corpo/comer_action.gd`, `sim/corpo/comeu_event.gd`
Altera: `sim/corpo/sistema_corpo.gd`, `tests/test_sistema_corpo.gd`
Depende de: 15.1.1, 15.1.2
Faz: a tabela de saciedade e o `handle()` que trata `ComerAction` — aplica o
fator da refeição, restaura, emite `ComeuEvent`. Recusa com `estamina_cheia` e
com `nao_e_comida`; expõe `pode_comer()` para `game/` perguntar antes. Reage a
`DayEndedEvent` zerando a contagem de refeições, junto do restauro que já
existe. Reescreve o cabeçalho: o corpo trata ação agora.

### 15.1.4 — A mesa na aba Corpo
Altera: `game/dev/painel_corpo.gd`, `tests/test_painel_corpo.gd`
Depende de: 15.1.3
Faz: a lista das comidas que estão na mochila, cada uma com **quanto restaura
agora** — já com a saciedade do dia aplicada, não o número cru do `.tres` — e o
botão de comer. Mostra qual refeição do dia vem a seguir e o fator dela. Nenhum
cálculo mora aqui: o painel pergunta ao sistema e formata.

## Em aberto

- Todos os números são chute. O que só a mesa resolve é **se o pão a 100 vale
  mais comido que vendido**: se ninguém nunca comer o pão, ou ele restaura
  mais, ou desmaiar precisa doer mais que meio dia. A wave só fecha depois de
  uma semana jogada com a barra apertando.
- A saciedade zera ao dormir, inclusive no colapso. Se desmaiar e ainda assim
  amanhecer com a mesa limpa parecer generoso demais, o `cause = COLLAPSED`
  está no evento e dá para diferenciar sem tocar em mais nada.
- Comida cozida de verdade (receita, panela) não entra: transformação mora na
  cidade (§2), então prato pronto seria mais um estabelecimento, não uma
  bancada em casa. Fica para quando a cidade crescer.
