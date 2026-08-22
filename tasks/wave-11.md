---
wave: 11
titulo: A cara do playground — tema, layout e juice
paralelo: nao
depende_de: [10]
---

## Objetivo

Aplicar o design system aprovado (Fazenda de Botões v1, 2026-08-21) ao
playground inteiro: tema, layout, feedback e o medidor do dia.

## Decisões

- **A fonte de verdade visual é o design system aprovado** (artefato "Fazenda
  de Botões", v1). Cores, tipos, medidas e estados vêm de lá — esta wave não
  redecide nada, só implementa.
- **Nenhum nó pinta cor na mão.** Toda cor sai de `paleta.gd`; trocar o tema
  inteiro é editar um arquivo.
- **Cada cor tem um dono**: ouro só dinheiro, céu só tempo, alerta só recusa,
  verde ação/fazenda, terra cidade. Canais do jogo intocáveis: solo fala de
  rega, planta fala de estágio.
- **Toda recusa diz o porquê**, em toast que some sozinho. "Não deu" não
  existe.
- **Número é sempre mono** (JetBrains Mono): relógio, dinheiro, cota,
  coordenada — não dança quando muda.
- **Juice em retângulo**: tremida curta ao arar, jogador achata 2 frames no
  swing, canteiro pisca ao receber ação, quadradinho voa em arco na colheita,
  pronta pulsa. Tudo `Tween`, nada de sprite. Se com retângulo já for gostoso,
  com arte será ótimo; se for morno, a arte não salvaria.
- **Medidor do dia**: o playground cronometra como os 15 minutos foram gastos
  (andando / na fazenda / na cidade / parado) e mostra no resumo ao dormir. É
  o instrumento que calibra a distância da cidade — dado, não achismo.
- Fontes Familjen Grotesk e JetBrains Mono (ambas OFL) entram em
  `assets/ui/fontes/`. Sem internet no momento da wave, usar a fonte padrão e
  deixar o tema pronto para recebê-las — pendência anotada, não bloqueio.
- Layout do mock aprovado: barra de status fixa no topo, rail esquerdo
  (locais, ferramentas, truques), mundo no centro, inspetor à direita, diário
  colapsável embaixo.

## Impacto

- Eventos novos: nenhum. O medidor cronometra em `game/` — tempo de parede da
  sessão não é regra de jogo e não entra em `sim/`.
- Muda formato de save: não.
- Arte necessária: nenhuma (as duas fontes OFL não são arte do artista).
- Toca `game/`: só `game/dev/`.

## Tarefas

### 11.1 — Paleta ✅
Cria: game/dev/paleta.gd
Faz: todas as cores do design system como constantes `Color` com os nomes
aprovados, mais as medidas (raio 4, borda 1, grade de 4px, tamanhos de fonte).

### 11.2 — Tema ✅
Cria: game/dev/tema_playground.tres
Depende de: 11.1
Faz: `Theme` com `StyleBoxFlat` por estado (normal, hover, pressed, disabled,
focus) para botão, painel e pílula, tudo referenciando a paleta. Aplicado na
raiz da janela do playground — os painéis herdam.

### 11.3 — Layout ✅
Muda: game/dev/playground.tscn, game/dev/playground.gd
Depende de: 11.2
Faz: rearranja para o mock aprovado — barra de status, rail esquerdo, mundo ao
centro, inspetor à direita, diário embaixo colapsável. Os painéis existentes
são realocados, não reescritos.

### 11.4 — Feedback e juice ✅
Cria: game/dev/aviso_recusa.gd
Depende de: 11.3
Faz: toast de recusa com motivo (escuta `ActionRejectedEvent`) e o juice em
retângulo no mundo de esboço: tremida, achatada, pisca, arco, pulso da pronta.
Respeita a regra dos ≤2 frames de resposta (GAMEPLAY §6).

### 11.5 — Medidor do dia ✅
Cria: game/dev/medidor_dia.gd
Depende de: 11.3
Faz: cronometra a sessão por categoria (andando, na fazenda, na cidade,
parado), zera na virada do dia e mostra o resumo ao dormir junto do resumo de
vendas.

## Em aberto

- ~~Baixar os `.ttf` OFL das duas fontes~~ — feito na wave. As seis faces
  (Familjen Grotesk Regular/SemiBold/Bold, JetBrains Mono
  Regular/Medium/Bold) e as duas licenças OFL estão em `assets/ui/fontes/`,
  carregadas pelo `tema_playground.gd`. Sem os arquivos o tema cai na fonte
  padrão e nada quebra.
- ~~O diário colapsável começa aberto ou fechado?~~ — começa **aberto**
  (`Playground.DIARIO_COMECA_ABERTO`): enquanto não existe sprite, ele é o jogo
  acontecendo. Reverter é trocar um `bool`.
- Tremida de tela: começou em 3px com decaimento 14 (`MundoEsboco`). Calibrar
  jogando.
- Alcance da mira (`MiraFerramentas.ALCANCE = 1`) continua sem calibração —
  herdado da wave 10.
- A distância da cidade (15 tiles de caminho) agora tem instrumento: jogue um
  dia e leia a fatia "andando" no medidor. É a decisão que a wave 10 deixou
  pendente.

## O que saiu diferente do planejado

- **`tema_playground.tres` não guarda cor.** Um `.tres` de tema salvo pelo
  editor grava cópias das cores dentro de cada `StyleBoxFlat`, e a decisão
  "trocar o tema é editar um arquivo" morreria na primeira troca. O `.tres`
  existe e é o que a cena carrega, mas só aponta para `tema_playground.gd`, que
  monta tudo a partir da `paleta.gd` no `_init`. Um arquivo a mais que o
  planejado, pela decisão do plano.
- **Três arquivos fora do `Cria:` foram tocados**, todos por consequência
  direta do layout: `status_panel.gd` (relógio, dinheiro e velocidade subiram
  para a barra de status), `mira_ferramentas.gd` (ganhou
  `escolhe_ferramenta` + sinal, para o rail e a tecla usarem o mesmo caminho; o
  rótulo de ferramenta saiu do mundo) e `inspetor_tile.gd` ("você está" virou
  grupo do rail; o painel passou a achar o mundo subindo a árvore em vez de por
  caminho de nó). `event_feed.gd` e `mundo_esboco.gd` também mudaram, para
  cumprir "nenhum nó pinta cor na mão".
