---
wave: 08
titulo: Playground — Fazenda de Botões
paralelo: nao
depende_de: [07]
---

## Objetivo

Jogar a sim inteira com botões — grid clicável, tempo, truques, diário de eventos — e cada painel é a implementação de referência de um padrão de ligação, com receita em docs/receitas/.

## Decisões

- **Playground é regra de projeto** (CLAUDE.md): toda mecânica nova ganha seus botões aqui na mesma wave em que nasce em sim/. O jogo visual só implementa o que já foi jogado aqui.
- **Painéis mostram o snapshot()**, nunca state vivo: zero API nova, e o inspetor de save sai de graça.
- **Zero if de regra**: clique vira ação, evento vira texto. Cheats são ações formais existentes.
- **Cada script ensina 1 padrão**, comentado em português: "copie daqui".
- Vira `game/dev/` — não entra no jogo final.

## Impacto

- Eventos novos: nenhum.
- Muda formato de save: não.
- Arte necessária: nenhuma (Control/Button padrão).
- Come metade da wave de dev tools visual: log ao vivo, tempo, cheats e inspetor saem daqui.

## Tarefas

### 8.1 — Casca do playground ✅
Cria: game/dev/playground.tscn, game/dev/playground.gd
Faz: layout dos painéis, recebe a bridge por setup(), padrão 1 (receber o fio) como referência.

### 8.2 — Grid da fazenda + ferramentas ✅
Cria: game/dev/farm_grid.gd
Depende de: 8.1
Faz: 8×6 de botões-canteiro, ferramenta selecionada, clique despacha Till/Plant/Water/Harvest. Referência do padrão 2 (mandar ordens).

### 8.3 — Diário de avisos ✅
Cria: game/dev/event_feed.gd
Depende de: 8.1
Faz: todo SimEvent como linha legível com hora de jogo + nome real. Referência do padrão 3 (escutar avisos).

### 8.4 — Situação, tempo e truques ✅
Cria: game/dev/status_panel.gd
Depende de: 8.1
Faz: dia/hora/dinheiro/mochila/caixote via snapshot(); +10min/+1h/dormir/time_scale; cheats como ações formais; salvar/carregar.

### 8.5 — Receitas ✅
Cria: docs/receitas/ (3 arquivos: receber-o-fio.md, mandar-ordens.md, escutar-avisos.md)
Depende de: 8.2, 8.3
Faz: passo a passo em português simples de cada padrão, apontando o arquivo de referência.

## Em aberto

- Overlay de grid e atalho F1 — só quando existir jogo visual.
