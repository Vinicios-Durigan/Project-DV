---
wave: 11.1
titulo: Mochila em tela cheia — o inventário no Tab
paralelo: nao
depende_de: [11]
---

## Objetivo

Trocar as listas de mochila e caixote do rail por um painel de tela cheia,
aberto e fechado com **Tab**, com a cara do design system v1.

## Decisões

- **Tab abre, Tab ou Esc fecha.** Tab é lido em `_input`, antes da navegação de
  foco do Godot — que também usa Tab e engoliria a tecla.
- **O painel é modal de verdade.** Enquanto estiver aberto o jogador não anda,
  não mira e não age. Um clique atrás do painel arando um canteiro seria bug
  difícil de reproduzir e fácil de evitar.
- **Clique move o stack inteiro** para o outro lado — da mochila para o
  caixote, ou de volta. É o mesmo par de ações que os botões do rail já
  despachavam (`ShipItemAction` / `WithdrawItemAction`); só a tela mudou.
- **A mochila mostra os slots vazios.** Capacidade é a mecânica mais fácil de
  esquecer que existe, e ela precisa ser vista antes de encher — é ela que faz
  a cota da cidade doer (wave 12).
- **Sem ícone.** Não existe arte: o slot mostra a inicial do item, o nome e a
  quantidade em mono. Mesma aposta do juice — se o painel já for legível assim,
  com ícone fica ótimo.
- As listas saem do `StatusPanel`. Duas telas para a mesma coisa é uma para
  desatualizar.

## Impacto

- Eventos novos: nenhum.
- Muda formato de save: não.
- Arte necessária: nenhuma.
- Toca `game/`: só `game/dev/`.

## Tarefas

### 11.1.1 — O painel ✅
Cria: game/dev/painel_mochila.gd
Faz: overlay de tela cheia com mochila (grade de slots, vazios inclusive),
caixote, dinheiro e capacidade. Clique transfere o stack. Tab e Esc fecham.

### 11.1.2 — Congelar o mundo ✅
Muda: game/dev/mundo_esboco.gd, game/dev/playground.gd
Faz: `congela()` no mundo — para de andar e desliga a mira; a casca liga isso à
abertura do painel.

### 11.1.3 — Vestir e limpar ✅
Muda: game/dev/tema_playground.gd, game/dev/status_panel.gd,
game/dev/playground.tscn
Faz: variações `Veu`, `Janela`, `Slot`, `SlotCheio`; as listas saem do rail.

## Em aberto

- Arrastar e soltar entre os dois lados, em vez de clique. Só se o playtest
  pedir — clique resolve e é uma fração do código.
- Mover uma unidade em vez do stack inteiro (clique com direito?). Idem.
