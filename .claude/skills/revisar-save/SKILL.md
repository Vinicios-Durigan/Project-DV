---
name: revisar-save
description: Checklist de compatibilidade de save para rodar antes de commitar mudança de estado — confere se todo campo novo tem default, se a versão do save foi incrementada, se existe teste carregando um save da versão anterior e se nenhum campo foi removido ou renomeado sem migração. Use antes de commitar qualquer mudança em estado persistido de sim/, ou quando perguntarem se uma mudança quebra o save do jogador.
when_to_use: Dispare em "vou commitar essa mudança de estado", "isso quebra o save?", "mudei o SimState", "adicionei campo no estado", "preciso de migração?". Não dispare para mudanças que não tocam estado persistido (visual, UI, balanceamento em .tres) nem para bug de save já em produção (isso é debug).
---

# Revisar compatibilidade de save

Rode **antes do commit**. Um save quebrado chega ao jogador como progresso perdido — não tem hotfix que devolva.

## Passo 0 — o que mudou de fato

```
git diff --stat sim/
git diff sim/ | grep -E "^[-+].*var |^[-+].*@export|^[-+]class_name"
```

Se nenhuma linha de campo de estado apareceu, **pare aqui**: não há risco de save. Diga isso e encerre.

## 1. Todo campo novo tem default válido

Cada `var` acrescentada a uma classe de estado precisa de valor inicial que faça sentido para um save antigo, onde o campo simplesmente não existe.

```gdscript
var fertilidade: float = 1.0     # save antigo carrega e assume solo normal
var fertilidade: float           # ERRADO: vira 0.0, terra morta retroativa
```

O default não é "qualquer valor que compile" — é **o valor que descreve corretamente o mundo antes desse campo existir**. Justifique cada um.

## 2. Versão do save incrementada

```
grep -rn "SAVE_VERSION\|save_version" sim/ --include=*.gd
```

Subiu na mesma mudança? Se não, incremente. Uma versão por mudança de formato, nunca duas mudanças na mesma versão — a migração deixa de ser reproduzível.

Se a constante não existe ainda, crie-a agora: sem número de versão não há migração possível depois.

## 3. Teste carregando save da versão anterior

Fixtures ficam em `tests/saves/`. A mudança precisa incluir:

- o save da versão anterior congelado como fixture (`tests/saves/v<N-1>_exemplo.json` ou `.tres`)
- um teste que carrega esse fixture na versão nova e afirma o estado resultante

```gdscript
func test_carrega_save_da_versao_anterior() -> void:
    var state := SaveLoader.load_file("res://tests/saves/v3_fazenda.json")
    assert_eq(state.version, SaveLoader.SAVE_VERSION, "deve migrar para a versão atual")
    assert_eq(state.fertilidade, 1.0, "campo novo assume o default de solo normal")
    assert_eq(state.moedas, 240, "dado antigo preservado")
```

Fixture antigo **nunca** se regenera para passar no teste. Se ele parou de carregar, o bug é na migração, não no fixture. Fixtures são histórico — só se acrescenta.

## 4. Nenhum campo removido ou renomeado sem migração

```
git diff sim/ | grep -E "^-.*var "
```

Toda linha que aparecer aqui é remoção ou renomeação. Para cada uma:

- **Renomeado** → migração lê o nome antigo e escreve no novo
- **Removido de verdade** → migração ignora o campo explicitamente, com comentário dizendo em que versão morreu
- **Tipo alterado** (`int` → `float`, escalar → array) → conta como remoção + adição, exige conversão explícita

Renomear campo sem migração é a falha mais comum e a mais silenciosa: carrega sem erro e o valor volta ao default.

## 5. Enums e índices

Valor de enum e índice de array salvos como número são frágeis. Confirme que nenhum valor existente mudou de posição — só acrescente no fim. Reordenar transforma "trigo" em "abóbora" no save do jogador.

## Veredito

Feche com um dos dois, sem meio-termo:

- **Compatível** — liste os itens 1 a 5 conferidos e siga para o commit.
- **Quebra o save** — liste exatamente o que falta (default ausente, versão não incrementada, migração inexistente, fixture faltando) e **não commite** antes de resolver.

Se a suíte GUT não rodou nesta mudança, rode antes de dar o veredito.
