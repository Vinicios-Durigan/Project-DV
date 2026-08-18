---
name: dev
description: Executa uma wave de tarefas do arquivo tasks/wave-NN.md. Investiga o código existente com subagentes em paralelo, depois escreve de forma sequencial com teste antes do código. Roda uma wave e para. Use quando o usuário mandar desenvolver, implementar ou executar uma wave já planejada.
---

# dev

Executa **uma** wave. Termina no fim dela e para. Não emenda na próxima.

Uso: `/dev 03`. Sem número, leia `tasks/INDEX.md` e pergunte qual wave.

## Contexto: leia só isto

- `tasks/wave-NN.md` da wave pedida
- `tasks/INDEX.md`
- `CLAUDE.md` da raiz

**Não leia outras waves. Não varra o repositório.** O `CLAUDE.md` de subpasta
carrega sozinho quando você tocar nos arquivos.

## Passo 1 — Investigação (paralela, só leitura)

Antes de escrever qualquer linha, dispare subagentes **em paralelo** para
investigar o que já existe. Um subagente por área tocada pela wave.

Cada subagente recebe uma pergunta fechada e devolve no máximo 15 linhas:

- "Quais funções públicas `sim/time/` expõe e quais eventos emite?"
- "Como o estado atual é serializado no save?"
- "Existe algo em `sim/` que já resolve X?"

Subagentes desta fase **só leem**. Nenhum escreve arquivo. Isso é o que torna o
paralelismo seguro.

Se a wave toca uma área só, não use subagente — leia direto.

## Passo 2 — Skill de domínio

Verifique `.claude/skills/` do projeto. Se existir skill que cubra o tipo de
trabalho da wave (conteúdo novo de jogo, sistema novo, mudança de save), use-a
antes de começar. Não reimplemente o procedimento na mão.

## Passo 3 — Escrita (sequencial, sempre)

Uma tarefa por vez, na ordem do arquivo. Para cada tarefa:

1. Escreva o teste primeiro. Rode e veja falhar.
2. Implemente o mínimo para passar.
3. Rode os testes. O hook faz isso sozinho após a edição.
4. Marque a tarefa como feita em `tasks/wave-NN.md`.

**Escrita nunca é paralela**, mesmo com `paralelo: sim` no frontmatter. Aquele
campo autoriza a investigação paralela do passo 1, não a escrita.

Não toque em nenhum arquivo que não esteja declarado em `Cria:` na tarefa.

## Passo 4 — Fechamento

- Atualize `sim/EVENTOS.md` se a wave criou ou mudou eventos.
- Atualize `tasks/INDEX.md` marcando a wave como concluída.
- Diga em 3 linhas o que foi feito e o que ficou pendente.
- **Pare.** Não comece a próxima wave.

## Quando parar no meio

Interrompa e pergunte, em vez de improvisar, se:

- A tarefa está ambígua ou maior do que o arquivo declarava.
- Um teste falha por motivo estrutural, não por bug simples.
- Você precisaria tocar num arquivo fora do escopo declarado.
- A wave depende de decisão de design que não está no `wave-NN.md`.

Trabalho não previsto que aparecer no caminho: anote como tarefa nova numa
wave futura. Não faça junto.

## Nunca

- Escrever regra de jogo dentro de `game/`.
- Usar tipo de engine dentro de `sim/`.
- Editar `assets/` — território do artista.
- Encadear waves sem o usuário pedir.