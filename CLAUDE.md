# Project-DV

Jogo de fazenda em Godot 4.7 (GDScript), estilo Stardew Valley.
Time de 2: um dev cuida de todo o código, um artista cuida de arte e conteúdo.

## Regra arquitetural central

`sim/` é lógica pura de jogo. **Nenhum tipo de engine entra ali**: nada de `Node`,
`Sprite2D`, `Node2D`, `Resource` de cena, `get_node`, `$`, `preload` de `.tscn`,
`get_tree`, sinais de nó, `_process`, `_ready`. Só tipos nativos do GDScript e
classes definidas dentro de `sim/`. `sim/` precisa rodar sem janela e sem árvore
de cena — é isso que torna os testes rápidos e determinísticos.

`game/` só apresenta. Fluxo em uma direção só:

- `game/` traduz input em **ações** e envia para `sim/`.
- `sim/` processa, muda o próprio estado e **emite eventos**.
- `game/` escuta os eventos e atualiza o que está na tela.

`game/` **nunca decide regra de jogo**. Se um nó precisa saber se a colheita
está madura, se o dinheiro dá, se o dia virou ou se o item cabe na mochila,
a resposta vem de `sim/`. Um `if` de regra dentro de `game/` é bug de
arquitetura, mesmo que funcione.

Não existe caminho de volta: `sim/` nunca importa, referencia ou conhece nada
de `game/`.

## Layout de diretórios

```
sim/          lógica pura de jogo, sem engine — o coração das regras
  time/       relógio, dias, estações, eventos de virada de dia
  crops/      crescimento, estágios, colheita, rega
  inventory/  slots, empilhamento, capacidade, transferências
  economy/    dinheiro, preços, compra e venda
game/         cenas, nós, render e input — camada de apresentação
  player/     controle do jogador, câmera, animação
  farm/       tilemap da fazenda, plantio visual, interação com o mundo
  ui/         HUD, menus, inventário na tela, diálogos
data/         recursos .tres que o artista edita direto no editor Godot
  crops/      definição de cada cultura (sprite, preço, estágios)
  items/      definição de cada item (ícone, valor, empilhável)
tests/        testes GUT headless, espelhando a estrutura de sim/
assets/       sprites, tilesets, áudio — arte bruta importada
addons/gut/   framework de testes GUT 9.7.1 (não editar à mão)
```

## Convenções

- **Tipagem estática obrigatória** em todo GDScript. Todo parâmetro e todo
  retorno anotado, inclusive `-> void`. Toda variável de membro com tipo
  explícito. Nada de `var x = ...` sem tipo em código novo.
- **Arquivos e funções**: `snake_case` (`crop_growth.gd`, `advance_day()`).
- **Classes**: `PascalCase` (`class_name CropState`).
- **Constantes**: `SCREAMING_SNAKE_CASE`.
- **Comentários e mensagens de commit**: português brasileiro.
- **Nomes de API** (classes, funções, variáveis, sinais): inglês.
- Sinais no passado: `day_advanced`, `crop_harvested`.
- Um `class_name` por arquivo, com o nome do arquivo correspondendo.

## Comandos

Requer o binário do Godot 4.7 no `PATH` como `godot`.

Rodar todos os testes headless:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Rodar um arquivo de teste específico:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_crops.gd -gexit
```

Reimportar assets sem abrir o editor (necessário depois de clonar o repo ou de
adicionar arte nova):

```bash
godot --headless --import
```

Sai com código 0 quando tudo passa. Comando verificado contra o GUT 9.7.1
instalado em `addons/gut/`.

## Commits

Conventional Commits, descrição em português brasileiro:

```
feat: adiciona crescimento de culturas por estação
fix: corrige inventário aceitando item acima da capacidade
test: cobre virada de dia com colheita pendente
refactor: extrai cálculo de preço para sim/economy
chore: atualiza GUT para 9.7.1
docs: documenta fluxo de eventos entre sim e game
```

Escopo opcional quando ajuda: `feat(crops): ...`.
