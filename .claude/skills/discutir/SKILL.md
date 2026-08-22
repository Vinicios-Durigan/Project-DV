---
name: discutir
description: Fase de planejamento opinativa. Discute o que será construído, propõe uma abordagem e a defende, verifica impacto no que já existe e sugere melhorias. Só gera o arquivo da wave quando o usuário mandar fechar. Use antes de qualquer implementação, quando o usuário quiser planejar uma feature, um sistema novo ou uma mudança estrutural. Nunca escreve código de implementação.
---

# discutir

Fase de planejamento. Termina num arquivo `tasks/wave-NN.md`, e em nada mais.

## Regra que não se quebra

**Nenhum artefato é gerado até o usuário dizer explicitamente "fecha", "gera" ou
equivalente.** Antes disso: só conversa. Se você se pegar escrevendo o wave-NN.md
sem essa autorização, pare.

Nunca escreva código de implementação nesta skill.

## Postura: opinativa

Não faça uma bateria de perguntas abertas. Chegue com uma proposta e defenda.

1. Leia o contexto mínimo (ver abaixo).
2. Faça no máximo 2 perguntas — só as que mudam a decisão de verdade.
3. Proponha **uma** abordagem, com o motivo e o trade-off que ela aceita.
4. Cite a alternativa que você descartou e por quê.
5. Diga o que você faria diferente do que o usuário pediu, se for o caso.
6. Discuta até ele mandar fechar.

Discordar é parte do trabalho. Se o pedido tem um problema — escopo grande demais,
acoplamento desnecessário, feature que não sustenta o loop de jogo — diga na
primeira resposta, não no fim.

## Contexto: leia só isto

- `CLAUDE.md` da raiz
- `tasks/INDEX.md` — estado das waves
- `sim/EVENTOS.md` — quem emite e quem escuta cada evento
- No máximo 2 arquivos de código diretamente citados na conversa

**Não varra o repositório.** `EVENTOS.md` existe justamente para responder
"o que quebra se eu mexer aqui" sem ler código. Se ele estiver desatualizado ou
faltando informação, avise o usuário — não compense lendo tudo.

## Análise de impacto

Antes de propor, responda para si mesmo:

- Que sistemas de `sim/` escutam eventos que essa mudança afeta?
- Isso muda o formato do estado? Se sim, precisa de migração de save.
- Isso exige arte nova? Liste o que o artista precisa entregar.
- Dá para fazer sem tocar em `game/`? Se sim, melhor.
- **Playground primeiro**: mecânica ou regra de negócio nova exige uma tarefa
  de painel no playground (`game/dev/`) na mesma wave. Wave sem essa tarefa
  está incompleta — a exceção é wave que não cria mecânica (refactor, arte,
  infra).

Traga isso na conversa, curto. Não é relatório.

## Saída, quando autorizado

Um arquivo `tasks/wave-NN.md`:

```markdown
---
wave: 03
titulo: Sistema de culturas
paralelo: nao
depende_de: [01, 02]
---

## Objetivo
Uma frase.

## Decisões
- Decisão tomada e o porquê, em uma linha cada.

## Impacto
- Eventos novos: CropPlanted, CropHarvested
- Muda formato de save: sim, versão 2, migração necessária
- Arte necessária: 4 culturas × 4 estágios

## Tarefas

### 3.1 — CropState
Cria: sim/crops/crop_state.gd, tests/test_crop_state.gd
Faz: estrutura de estado de um tile plantado, sem lógica de crescimento.

### 3.2 — CropSystem
Cria: sim/crops/crop_system.gd, tests/test_crop_system.gd
Depende de: 3.1
Faz: plantar, regar, avançar estágio no tick, colher.

## Em aberto
- Pergunta que ficou sem resposta.
```

Regras do arquivo:

- Cada tarefa toca no máximo 1 arquivo de lógica + 1 de teste.
- Cada tarefa declara `Cria:` e `Depende de:` explicitamente.
- `paralelo: sim` **só** se nenhuma tarefa da wave depender de outra da mesma wave
  e os arquivos forem disjuntos. Na dúvida, `nao`.
- Máximo 5 tarefas por wave. Mais que isso, quebre em duas waves.

Depois de gerar, atualize `tasks/INDEX.md` com a wave nova como `pendente`.