---
wave: 12.1
titulo: A cidade ganha lugar — prédios no mapa e aba no Tab
paralelo: nao
depende_de: [12]
---

## Objetivo

A wave 12 entregou a mecânica da cidade e um painel no rail. Painel no rail não
é tela: o jogador não vê *onde* o moinho fica, não sente que ir até lá custa o
dia, e só descobre que a farinha ficou pronta se abrir uma coluna de debug.

Esta wave dá lugar e tempo à cidade — sem tocar em uma linha de `sim/` além de
duas consultas novas.

## Decisões

- **Regra nova do projeto, travada em 2026-08-22:** mecânica só está pronta com
  **tela própria**, **ponto de ativação no mundo** e **contagem regressiva
  visível**. Painel no rail é ferramenta de debug, não entrega.
- **A cidade é uma aba do Tab, não um painel novo.** A mochila já é a tela
  cheia do jogo e já é modal; uma segunda tela modal disputaria a mesma tecla e
  o mesmo espaço. Aba resolve, e de quebra põe a cota ao lado da capacidade da
  mochila — os dois números que brigam entre si.
- **Os prédios saem da sim, as posições saem daqui.** `SistemaCidade.ids()` diz
  quais existem; onde cada um fica no mapa é apresentação pura e é decidido no
  `mundo_esboco`. Estabelecimento novo aparece no mapa sozinho, sem editar
  `game/`.
- **O prédio mostra o tempo sem ninguém abrir nada.** Um selo sobre o retângulo:
  `4h`, `2h13`, `PRONTA` ou nada. É a contagem regressiva que a regra pede, e é
  o que faz o jogador olhar para a cidade de longe e decidir a rota do dia.
- **`E` ativa o prédio onde o jogador está.** `SPACE` já é usar, `WASD` anda,
  `1–8` é hotbar, `Tab` é mochila. `E` estava livre e é a tecla de "interagir"
  que o gênero inteiro usa.
- **Ativar abre a aba, não entrega nada.** Entregar e retirar continuam sendo
  botões — a decisão de *quanto* e *quando* é o miolo da mecânica e não cabe
  numa tecla. O prédio é a porta; a aba é o balcão.

## Impacto

- **Eventos novos:** nenhum.
- **Muda evento existente:** nenhum.
- **Muda formato de save:** nada. A aba e os prédios são apresentação.
- **Consultas novas em `sim/`:** `SistemaCidade.tem_pronto()` e
  `SistemaCidade.minutos_para_a_proxima()`. As duas são leitura pura, no mesmo
  espírito de `pode_plantar` — existem para o cálculo do tempo restante não ser
  refeito em dois nós de `game/`.
- **Arte necessária:** nenhuma nesta wave. Os dois prédios já estão no
  `docs/ARTE.md` §11 como pendência com o requisito de "avisar de longe que tem
  coisa pronta" — que é exatamente o que o selo faz em retângulo.
- **Toca `game/`:** `mundo_esboco.gd`, `painel_mochila.gd`, `painel_cidade.gd`,
  `playground.gd`, `playground.tscn`.

## Tarefas

### 12.1.1 — Os prédios no mapa ✅
Cria: tests/test_predios_cidade.gd
Edita: sim/cidade/sistema_cidade.gd, game/dev/mundo_esboco.gd, game/dev/painel_cidade.gd
Faz: as duas consultas de tempo em `SistemaCidade`; `texto_do_tempo` vira
estática no `PainelCidade` para os dois nós formatarem igual; o `mundo_esboco`
desenha um retângulo por estabelecimento dentro do terreno da cidade, com nome e
selo de tempo, e emite `predio_ativado` quando o jogador aperta `E` em cima de
um.

### 12.1.2 — A cidade como aba do Tab ✅
Cria: tests/test_aba_cidade.gd
Edita: game/dev/painel_mochila.gd, game/dev/painel_cidade.gd, game/dev/playground.gd, game/dev/playground.tscn
Faz: o modal do Tab ganha duas abas — MOCHILA e CIDADE. O `PainelCidade` sai do
rail e passa a ser montado dentro do modal. `abre_cidade(id)` abre o modal já na
aba certa, com o estabelecimento destacado; a casca liga o `predio_ativado` do
mundo a ele.

## Em aberto

- **O `PainelMochila` remonta a mochila inteira a cada evento da sim** —
  inclusive no `MinuteTickedEvent`, que sai 60 vezes por segundo em ×60. São
  ~32 botões destruídos e recriados por minuto de jogo, e é exatamente o
  sintoma que a receita 3 §4 avisa ("a tela pisca ou trava em ×60"). Achado ao
  medir órfãos de nó nesta wave; o conserto é o mesmo do `painel_cidade`, que
  reusa os rótulos em vez de recriar. **Não foi feito aqui de propósito:** o
  arquivo é da wave 11.2 e estava sendo editado por outra sessão no momento.
- **Proximidade dentro da cidade.** Hoje a sim conhece dois locais (fazenda e
  cidade) e o `E` só confere a posição em pixel, que é de `game/`. Se um dia a
  distância *dentro* da cidade precisar valer regra — o ferreiro no fim da rua
  custando mais relógio que o moinho na entrada — o local vira sub-local em
  `sim/mundo/`, e aí a checagem sai de `game/`.
- **O selo do prédio não distingue de quem é a encomenda.** Com co-op, dois
  jogadores veriam o mesmo selo. O `EstadoCidade` não é indexado por jogador
  (como o caixote não é) — decidir junto com a wave de co-op.
