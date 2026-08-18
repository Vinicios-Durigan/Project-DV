---
name: revisar
description: Audita o diff atual antes do commit. Verifica aderência às regras de arquitetura, cobertura de teste e consistência do save, e sugere a mensagem de commit. Só reporta, nunca edita arquivos. Use antes de commitar, ao fechar uma wave, ou quando o usuário pedir revisão do que foi feito.
---

# revisar

Auditoria do diff. **Esta skill não edita nenhum arquivo.** Só reporta.

Se encontrar um problema, descreva e aponte o arquivo e a linha. Não conserte.
Revisor que conserta esconde o padrão que está falhando.

## Passo 1 — O diff

```
git diff
git diff --staged
git status
```

Revise apenas o que mudou. Não audite o repositório inteiro.

## Passo 2 — Checagens

**Fronteira arquitetural**
- Algum arquivo em `sim/` referencia tipo de engine (`Node`, `Sprite2D`,
  `get_node`, `$`, `preload` de cena, `SceneTree`)?
- Algum arquivo em `game/` contém regra de jogo — cálculo de crescimento,
  preço, progressão, condição de vitória?
- `sim/` usa `randi()` sem seed ou tempo real do sistema? Quebra determinismo.

**Tipagem e convenção**
- Toda função nova tem tipo nos parâmetros e no retorno?
- Nomes de arquivo e função em snake_case, classes em PascalCase?
- Comentários em português brasileiro?

**Teste**
- Todo código novo em `sim/` tem teste correspondente?
- Algum teste precisa instanciar cena para rodar? Se sim, lógica vazou para `game/`.
- Os testes passam?

**Save**
- O diff mudou o formato do estado? Se sim, use a skill de domínio de revisão
  de save do projeto, se existir.
- Campo novo tem valor default? Versão do save foi incrementada?

**Documentação viva**
- Evento novo ou alterado foi refletido em `sim/EVENTOS.md`?
- A wave foi marcada em `tasks/INDEX.md`?

## Passo 3 — Relatório

Liste em ordem de gravidade, curto:

```
BLOQUEIA — quebra a arquitetura ou o determinismo
CORRIGIR — falta teste, tipo ou documentação
SUGESTÃO  — melhoria opcional
```

Se não houver nada em BLOQUEIA nem CORRIGIR, diga que está limpo em uma linha.
Não invente problema para parecer útil.

## Passo 4 — Commit

Sugira a mensagem em Conventional Commits, em português:

```
feat(sim): adiciona sistema de crescimento de culturas
fix(game): corrige animação de rega disparando duas vezes
test(sim): cobre virada de estação no TimeService
chore: atualiza EVENTOS.md
refactor(sim): extrai cálculo de estágio para função pura
```

Se o diff misturar assuntos, sugira quebrar em mais de um commit e diga quais
arquivos vão em cada um.