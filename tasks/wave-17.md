---
wave: 17
titulo: Ofícios — a árvore do jogador
paralelo: nao
depende_de: [14, 14.1, 15]
---

## Objetivo

Dar progressão ao personagem. O jogador acumula experiência trabalhando, sobe
níveis em dois ofícios e gasta pontos num tabuleiro de vantagens com teto —
onde escolher uma coisa é abrir mão de outra, para sempre.

## Decisões

- **XP por ação, e grind é intencional.** Quem planta mais ganha mais XP que
  quem planta menos — decisão do usuário, revertendo a proposta original de
  progressão por constância. O freio não é a regra, é o mundo: **cada ação já
  custa estamina e relógio** (waves 15 e 3), então volume nunca sai de graça.
  O grind se paga em corpo.
- **XP = custo de estamina do trabalho.** Arar dá 4 XP, regar 2, quebrar pedra
  8, derrubar árvore 12 — a mesma tabela do `SistemaCorpo`, sem uma segunda
  fonte de verdade. O que cansa mais ensina mais.
- **Dois ofícios: Lavoura e Campo.** Lavoura pratica com arar, plantar, regar e
  colher; Campo com limpar mato, pedra, toco e árvore. **A cidade fica fora da
  árvore** — relação já é a progressão dela, e premiar duas vezes o mesmo gesto
  inflaria a escada que a wave 12 calibrou.
- **Ponto preso no ofício que o ganhou.** Ponto de Lavoura só compra vantagem
  de Lavoura. Você fica bom no que pratica, e abrir o tabuleiro inteiro obriga
  a variar o trabalho.
- **Escolha permanente.** Vantagem comprada não volta, como a relação não zera
  e a especialização não desfaz. É o que faz o ponto pesar na hora de gastar
  (PRINCIPIOS §7). Respec pago em produção fica anotado como extensão futura —
  entra por uma ação nova, sem quebrar nada.
- **Efeito nunca toca preço de venda.** A conta que mata: 4 trigos crus valem
  100g; moídos rendem 140g líquidos. Trigo a 2× valeria 200g e o moinho morreria
  no primeiro ponto gasto — e com ele a tese do jogo. As vantagens compram
  **corpo, relógio, água e terra**.
- **Nada de sorte no efeito.** "10% de chance de nascer regada" viraria RNG em
  resultado, descartado no GAMEPLAY com motivo. A versão determinística é a
  Rega funda: os primeiros N canteiros regados do dia seguram a água — e o
  jogador controla *quais* pela ordem em que rega.
- **Efeito viaja por evento, com cópia local em quem cobra.** O mesmo padrão de
  contratos↔cidade: `VantagemEscolhidaEvent` sai do `SistemaOficios`, e o dono
  do efeito (corpo, farm) guarda a própria cópia no próprio state. Nenhum
  sistema lê state alheio.
- **O tabuleiro só oferece vantagem cujo efeito existe.** As vantagens cujos
  donos ficam de fora desta wave (regador, terreno, velocidade) entram na
  17.1 — comprar vantagem morta seria pior que não vendê-la.

## Números de partida

Chutes para calibrar jogando, como a estamina e o `DIAS_POR_CONTRATO`.

**XP por trabalho** = custo de estamina (tabela da wave 15).

**Níveis** (XP acumulado; cada nível dá 1 ponto):

| Ofício | N1 | N2 | N3 | N4 | Por que diferente |
| --- | --- | --- | --- | --- | --- |
| Lavoura | 100 | 300 | 700 | 1400 | Fonte infinita — o dia todo alimenta |
| Campo | 30 | 80 | 160 | 280 | Fonte quase finita: pedra e árvore não voltam; só o mato pinga |

**O tabuleiro** (custo em pontos · teto):

| Ofício | Vantagem | Custo | Efeito | Entra em |
| --- | --- | --- | --- | --- |
| Lavoura | Mãos leves | 1/nível (teto 2) | Plantar, depois colher, custam 0 de estamina | 17 |
| Lavoura | Rega funda | 1/nível (teto 2) | Os primeiros 4/8 canteiros regados do dia seguram a água até depois de amanhã | 17 |
| Lavoura | Colheita especializada | 2 | Escolha **uma** cultura: rende +1 por colheita. Não volta | 17 |
| Lavoura | Braço de poço | 1/nível (teto 2) | Regador +5 de carga | 17.1 |
| Campo | Costas largas | 1/nível (teto 2) | +25 de estamina máxima | 17 |
| Campo | Golpe certeiro | 2 | Árvore cai sem virar toco | 17.1 |
| Campo | Terra domada | 1 | Arado ocioso aguenta 5 dias, não 3 | 17.1 |
| Campo | Passo firme | 2 | Anda 10% mais rápido — compra relógio | 17.1 |

8 pontos ganháveis no slice contra 13 de custo total: nunca dá para ter tudo.

## Impacto

- **Eventos novos:** `ExperienciaGanhaEvent`, `OficioSubiuEvent`,
  `VantagemEscolhidaEvent`
- **Ação nova:** `EscolherVantagemAction` (recusável: ponto insuficiente,
  vantagem no teto, vantagem desconhecida)
- **Eventos escutados:** os mesmos de trabalho que o `SistemaCorpo` escuta —
  `PlotTilledEvent`, `PlotWateredEvent`, `CropPlantedEvent`,
  `CropHarvestedEvent`, `TerrenoMudouEvent` (só `motivo = limpeza`)
- **Muda formato de save:** bloco `oficios` novo, todo campo com default —
  sem migração. Os efeitos comprados entram como cópia local nos blocos de
  quem cobra (`corpo`, `farm`), também com default
- **Toca sistemas existentes:** sim, dois nesta wave — `SistemaCorpo` (Mãos
  leves, Costas largas) e `FarmSystem` (Rega funda, Colheita especializada)
  ganham `react` para `VantagemEscolhidaEvent`. Declarado de propósito
- **Arte necessária:** nenhuma nesta wave

## Tarefas

### 17.1 — EstadoOficios ✅
Cria: `sim/oficios/estado_oficios.gd`, `tests/test_estado_oficios.gd`
Faz: XP e nível por ofício, pontos disponíveis e gastos, vantagens compradas
com nível de cada uma, cultura da especialização. `to_dict`/`from_dict` no
bloco `oficios`. State burro: não sabe quanto custa vantagem nenhuma.

### 17.2 — SistemaOficios ✅
Cria: `sim/oficios/sistema_oficios.gd`, `tests/test_sistema_oficios.gd` (mais
ação e eventos da wave)
Depende de: 17.1
Faz: reage aos eventos de trabalho somando XP pela tabela de estamina; cruza
níveis e credita pontos; trata `EscolherVantagemAction` validando ponto, teto
e permanência; emite os três eventos novos. O tabuleiro (custos e tetos) mora
aqui, em constantes.

### 17.3 — O corpo aprende ✅
Altera: `sim/corpo/sistema_corpo.gd`, `tests/test_sistema_corpo.gd`
(mais `sim/corpo/estado_corpo.gd` e `tests/test_estado_corpo.gd`: a cópia local
mora no bloco `corpo`, e o bloco é o state)
Depende de: 17.2
Faz: `SistemaCorpo` reage a `VantagemEscolhidaEvent` — Mãos leves zera o custo
de plantar (nível 1) e colher (nível 2); Costas largas soma +25 à estamina
máxima por nível. A cópia local entra no bloco `corpo` do save com default
que preserva o comportamento de hoje.

### 17.4 — A lavoura aprende ✅
Altera: `sim/crops/farm_system.gd`, `tests/test_farm_system.gd`
(mais `sim/crops/farm_state.gd`: a cópia local mora no bloco `farm`)
Depende de: 17.2
Faz: `FarmSystem` reage a `VantagemEscolhidaEvent` — Rega funda faz os
primeiros N canteiros regados do dia segurarem a rega por mais um dia;
Colheita especializada soma +1 ao rendimento da cultura escolhida. Cópia
local no bloco `farm`, com default inerte.

### 17.5 — A aba Ofícios ✅
Cria: `game/dev/painel_oficios.gd`, `tests/test_painel_oficios.gd`
(mais o registro da aba em `game/dev/painel_mochila.gd`, que é quem monta o Tab)
Depende de: 17.2
Faz: aba do Tab com os dois ofícios — barra de XP até o próximo nível, pontos
disponíveis, o tabuleiro inteiro com custo e teto, botão de comprar que vira
`EscolherVantagemAction`. Vantagem comprada aparece comprada; vantagem sem
ponto aparece com o motivo. Nenhum custo calculado na tela: o painel pergunta
ao sistema e formata.

## Em aberto

- Todos os números são chute: tabela de XP, limiares de nível, custos e tetos
  do tabuleiro. A wave só fecha depois de uma estação jogada no playground
  conferindo se os 8 pontos chegam num ritmo que sustenta escolha.
- **Com as 4 vantagens desta fatia, o tabuleiro fecha.** 8 pontos ganháveis
  contra 8 de custo total: quem maximizar os dois ofícios leva tudo. A tensão
  "nunca dá para ter tudo" continua valendo *dentro* de cada ofício (a Lavoura
  rende 4 e o ramo dela custa 6), e a folga geral só volta na 17.1. Se a estação
  jogada mostrar que os dois ofícios chegam ao nível 4, os limiares sobem antes
  de a 17.1 entrar.
- **Wave 17.1 — os outros donos aprendem**: Braço de poço (InventorySystem),
  Golpe certeiro e Terra domada (SistemaTerreno), Passo firme (game/ lê do
  snapshot). O tabuleiro cresce quando os efeitos existirem.
- Respec pago em produção (ex.: reaprender custa pães) — extensão futura se a
  permanência doer demais jogando.
- **Depois desta wave a lista de mecânicas do slice congela.** A fila até o
  visual é: 15.1 (comida), 16 (dono), 17 (ofícios), 17.1 (donos restantes) —
  e então o beta visual começa.
