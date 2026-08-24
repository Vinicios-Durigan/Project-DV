---
wave: 15
titulo: Estamina — o corpo cobra o trabalho, o relógio cobra a rota
paralelo: nao
depende_de: [3, 14, 14.1]
---

## Objetivo

Dar limite ao corpo do jogador. Hoje o dia só tem um limitador — o relógio — e
trabalhar é gratuito: arar cem tiles custa o mesmo que arar um, desde que caiba
nos 15 minutos reais do dia útil. A estamina põe um segundo preço no trabalho e
transforma "quanto ainda dá para fazer hoje" numa aposta que pode sair errada
(PRINCIPIOS §7).

## O risco que define a wave

O dia útil são **15 minutos reais**. Se a estamina acabar antes do relógio, ela
não soma um limitador — ela **substitui** o relógio, e o relógio vira
decoração. O PRINCIPIOS §9 ("toda mecânica compete pelo relógio") deixaria de
valer para tudo que já foi construído: o terreno da wave 14, a rota da água da
14.1 e a cota da cidade da 12 foram todos calibrados contra o relógio como
limite único.

O alvo de calibragem é: **um dia cheio de trabalho termina com a barra
raspando.** Quem trabalha normal chega em casa às 02:00 cansado, não desmaiado
às 20:00. Desmaio é o preço de ter apertado, nunca o fim padrão do dia.

Se na prática sobrar muita estamina, o teto cai. Se a barra acabar no meio da
tarde, o teto sobe. Os números abaixo são chute para calibrar jogando, como o
`DIAS_POR_CONTRATO` da wave 13 foi.

## Decisões

- **A estamina reage ao trabalho feito; ela não valida ação.** A ordem do tick
  não comporta um validador de estamina: ele teria que vir antes do
  `InventorySystem` (que cobra semente e carga do regador) e depois do
  `SistemaTerreno` (que recusa limpeza impossível), e não existe posição que
  satisfaça as duas. Reagindo ao evento, o corpo só desconta o que **aconteceu
  de verdade** — ação recusada não cansa ninguém.
- **Não existe "cansado demais para agir".** Ao chegar a zero o jogador
  **desmaia**. Recusa é para impossibilidade (item errado, fora do lugar), não
  para consequência: apertar o botão e nada acontecer, no meio do canteiro, é o
  pior momento de jogo que essa mecânica poderia produzir.
- **Desmaio acorda com metade.** O custo é tempo de trabalho, que é a moeda do
  jogo, e se paga sozinho — quem desmaia hoje rende menos amanhã e tende a
  desmaiar de novo, até aprender a parar. Sem perda de item, sem taxa de
  resgate: taxa pune o jogador quebrado com mais força que o rico, e o quebrado
  é justamente quem mais precisa apertar.
- **Dormir sempre enche.** A estamina do dia seguinte não depende de como se
  foi dormir. Uma variável a menos para calibrar, e mantém a decisão dentro do
  dia em vez de na hora de deitar — descanso proporcional empurraria o jogador
  a dormir cedo todo dia, desperdiçando o relógio que estamos tentando
  preservar.
- **O custo é por tipo de trabalho, não por ferramenta.** O sistema reage a
  `PlotTilledEvent`, e o evento não diz qual ferramenta foi usada; descobrir
  exigiria ler o inventário, que é state alheio. O trade-off aceito:
  **ferramenta melhor não cansa menos, ainda**. Quando o ferreiro existir e a
  progressão de ferramenta entrar, o evento ganha o campo e o custo migra para
  lá — pagar essa complexidade hoje seria por uma mecânica que não existe.
- **Andar não cansa.** O relógio cobra o deslocamento, o corpo cobra o
  trabalho, e nenhum dos dois cobra duas vezes pela mesma coisa. Um dia de só
  ir à cidade, entregar e voltar não gasta estamina — e está certo, porque esse
  dia já custa o relógio inteiro. Sem isso, a rota da água da 14.1 passaria a
  ter dois preços somados.
- **O medidor mora na barra de status, sempre visível.** Estamina que só
  aparece dentro de uma aba não pressiona ninguém — a barra tem que estar no
  canto do olho quando o jogador decide se rega mais um canteiro.
- **Comida fica para a 15.1.** Calibrar quanto uma maçã restaura antes de
  sentir quanto um dia custa é chutar duas vezes.

## Números de partida

Estamina cheia: **200**.

| Trabalho | Custo |
| --- | --- |
| Arar | 4 |
| Regar | 2 |
| Plantar | 1 |
| Colher | 1 |
| Limpar mato | 4 |
| Limpar pedra | 8 |
| Limpar toco | 10 |
| Limpar árvore | 12 |

Um dia de 20 tiles arados, plantados e regados gasta ~180 — a barra raspa no
fim do dia, que é o alvo.

## Impacto

- **Eventos novos:** `EstaminaGastaEvent`, `DesmaiouEvent`
- **Eventos escutados:** `PlotTilledEvent`, `PlotWateredEvent`, `CropPlantedEvent`,
  `CropHarvestedEvent`, `TerrenoMudouEvent` (só limpeza do jogador, pelo
  `motivo`), `DayEndedEvent` (o `cause` já distingue `SLEPT` de `COLLAPSED`)
- **Muda formato de save:** bloco `corpo` novo, todo campo com default —
  **sem migração**, do mesmo jeito que os blocos `cidade` e `terreno` entraram
- **Toca sistema existente:** sim, um. O `TimeSystem` ganha um `react` para
  `DesmaiouEvent`. É o padrão documentado de comunicação entre sistemas, mas é
  edição de arquivo existente e está declarada aqui de propósito
- **Arte necessária:** nenhuma nesta wave

## Tarefas

### 15.1 — EstadoCorpo ✅
Cria: `sim/corpo/estado_corpo.gd`, `tests/test_estado_corpo.gd`
Faz: estamina atual e máxima, gasto com piso em zero, restauro cheio e pela
metade, `to_dict`/`from_dict` com o bloco `corpo`. Sem regra de quanto custa
cada trabalho — o state é burro, como o `EstadoCidade`.

### 15.2 — SistemaCorpo ✅
Cria: `sim/corpo/sistema_corpo.gd`, `tests/test_sistema_corpo.gd`
Depende de: 15.1
Faz: reage aos eventos de trabalho descontando a tabela de custos; emite
`EstaminaGastaEvent` a cada desconto e `DesmaiouEvent` ao chegar a zero; reage
a `DayEndedEvent` restaurando cheio no `SLEPT` e metade no `COLLAPSED`.
Registrado no tick central — a posição não importa para reações, mas ele entra
depois do Farm para ler eventos de trabalho já emitidos no mesmo tick.

### 15.3 — O desmaio vira fim de dia ✅
Cria: —
Altera: `sim/time/time_system.gd`, `tests/test_time_system.gd`
Depende de: 15.2
Faz: `TimeSystem` reage a `DesmaiouEvent` emitindo `DayEndedEvent` com
`cause = COLLAPSED` — o mesmo caminho das 02:00, que já existe e que o
`EVENTOS.md` registra como "fadiga futura ainda não escuta".

### 15.4 — O medidor na barra de status ✅
Cria: `game/dev/medidor_estamina.gd`, `tests/test_medidor_estamina.gd`
Depende de: 15.2
Faz: a barra de estamina ao lado do relógio e do dinheiro, sempre visível.
Muda de cor perto do fim — descobrir que vai desmaiar é a informação mais cara
desta tela. Sai do snapshot, como manda o padrão 3.

### 15.5 — A aba Corpo ✅
Cria: `game/dev/painel_corpo.gd`, `tests/test_painel_corpo.gd`
Depende de: 15.2
Faz: quarta aba do Tab — o custo de cada trabalho lido do sistema, o gasto do
dia acumulado, quantas ações de cada tipo ainda cabem antes do desmaio. Nenhum
custo calculado aqui: o painel pergunta e formata.

## Em aberto

- O teto de 200 e a tabela de custos são chute. A wave só fecha depois de um
  dia jogado ponta a ponta no playground medindo se a barra raspa junto com o
  relógio — se ela acabar antes, o relógio virou decoração e o número está
  errado.
- Colher com a mão custa 1 e arar custa 4, mas nada distingue colher uma
  cenoura de colher uma abóbora. Se a diferença importar, o custo passa a sair
  do `CropDef` — decisão adiada para depois de jogar.
