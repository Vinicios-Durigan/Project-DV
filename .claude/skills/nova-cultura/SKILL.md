---
name: nova-cultura
description: Procedimento completo para adicionar uma cultura nova ao jogo — cria o .tres em data/crops/, preenche os campos, registra no catálogo, escreve o teste de ciclo de crescimento em tests/ e gera o checklist de sprites para mandar ao artista. Use quando pedirem para adicionar, criar ou implementar uma cultura, planta, semente ou colheita nova.
when_to_use: Dispare em pedidos como "adiciona a cultura tomate", "quero uma semente de abóbora", "cria a planta X", "nova colheita". Não dispare para ajustar valores de uma cultura já existente, para mudar a fórmula de crescimento em sim/ (isso é novo-sistema-sim) ou para desenhar sprite.
---

# Adicionar uma cultura nova

Cinco entregas, na ordem. A tarefa só termina quando as cinco existirem.

## 0. Levantar os dados antes de escrever

Pergunte ou confirme, em uma pergunta só:

- **Nome** e slug (`tomate`, `abobora` — sem acento, snake_case)
- **Estágios de crescimento** e ticks por estágio
- **Preço de compra da semente** e **preço de venda do fruto**
- **Rende quantas unidades** por colheita
- **Rebrota?** (colhe várias vezes ou morre na colheita)
- **Estação** em que cresce

Se o usuário não souber algum, proponha um valor coerente com as culturas já em `data/crops/` e siga — não trave a tarefa.

## 1. Ler uma cultura existente primeiro

```
ls data/crops/
```

Abra o `.tres` mais parecido e o script do recurso (`sim/crops/crop_data.gd` ou equivalente). **Copie os nomes de campo existentes.** Nunca invente um campo novo sem antes checar se já existe um com outro nome. Se `data/crops/` estiver vazio, você está criando a primeira — defina o recurso base seguindo `.claude/rules/data.md` (só dados, `@export` com hints, nomes autoexplicativos, todo campo com default válido).

## 2. Criar `data/crops/<slug>.tres`

Preencha **todos** os campos, inclusive os que têm default. Um `.tres` meio preenchido vira bug silencioso.

O `.tres` é lido por um artista no inspector: se algum campo novo precisou ser criado, ele nasce com `@export_range` / `@export_enum` e nome que se explica sozinho.

## 3. Registrar no catálogo

O jogo não descobre culturas sozinho — o catálogo é a única fonte de verdade.

```
grep -rn "catalogo\|catalog\|crops.*Array" data/ sim/ --include=*.gd --include=*.tres
```

Adicione a nova entrada ao catálogo encontrado. Confirme que a ordem/índice não é usada como identidade em save (se for, **acrescente no fim**, nunca no meio — reordenar quebra save; veja `/revisar-save`).

## 4. Teste de ciclo de crescimento em `tests/`

Obrigatório na mesma tarefa, conforme `.claude/rules/sim.md`. Crie `tests/crops/test_<slug>.gd` cobrindo:

- planta no tick 0 → estágio inicial correto
- avança exatamente os ticks de cada estágio → estágio esperado em cada fronteira
- um tick antes de madurar → **não** colhível
- no tick de maturação → colhível, rende a quantidade certa
- rebrota: colhe duas vezes e confere o estado; sem rebrota: some após a colheita
- determinismo: mesma seed + mesmos ticks → mesmo resultado

```gdscript
extends GutTest

func test_amadurece_no_tick_exato() -> void:
    var sim := SimWorld.new(12345)  # seed explícita
    var plot_id := sim.plant(preload("res://data/crops/tomate.tres"))
    sim.advance(TOMATE_TICKS_TOTAL - 1)
    assert_false(sim.is_harvestable(plot_id), "não pode madurar cedo")
    sim.advance(1)
    assert_true(sim.is_harvestable(plot_id))
```

Rode a suíte antes de dar a tarefa por encerrada.

## 5. Checklist de sprites para o artista

Gere o bloco abaixo preenchido e entregue como texto pronto para copiar. Confirme o tamanho do tile no projeto antes (`grep -n "cell_size\|tile_size" project.godot` ou meça um PNG existente em `assets/`); use 32×32 só se não achar nada.

> **Sprites — <Nome da cultura>**
>
> Pasta: `assets/crops/<slug>/`
> Tamanho: **<N>×<N> px**, PNG, fundo transparente
> Pivô: base central (a planta cresce para cima a partir do pé)
>
> | # | Arquivo | O que mostra |
> |---|---|---|
> | 0 | `<slug>_estagio_0.png` | recém-plantado / broto |
> | 1 | `<slug>_estagio_1.png` | crescendo |
> | … | `<slug>_estagio_N.png` | maduro, pronto para colher |
> | — | `<slug>_semente.png` | ícone da semente no inventário (<N>×<N>) |
> | — | `<slug>_fruto.png` | ícone do fruto no inventário (<N>×<N>) |
>
> Total: **<N+1> sprites de estágio + 2 ícones**
> O último estágio é o único que o jogador vê como "pode colher" — precisa ser visualmente distinto do anterior.

Conte os estágios a partir do `.tres` que você acabou de criar, não de memória.

**Não crie, mova nem edite nada em `assets/`** — é território do artista e o hook de PreToolUse bloqueia a escrita. Sua entrega é o checklist, não o arquivo.

## Fechamento

Reporte: caminho do `.tres`, onde registrou no catálogo, caminho do teste, resultado da suíte e o checklist de sprites. Se algum valor foi assumido por você em vez de informado, diga qual.
