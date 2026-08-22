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

## Como uma mecânica nasce

`docs/PRINCIPIOS.md` é lei de design e **vale para toda mecânica futura** —
pecuária, pescaria, artesanato, festivais. Leia antes de propor ou planejar
qualquer sistema novo.

O resumo, para não errar de cara:

- A tese: o jogador começa **dependente da cidade**; autossuficiência é prêmio
  de fim de jogo, comprada com dependência.
- **Transformação mora na cidade, nunca na fazenda.** Sem forja, bancada ou
  oficina em casa — entrega, paga, espera, busca.
- Todo estabelecimento tem a mesma escada: **caixote → contrato → dono**. O
  caixote nunca morre.
- **Cota** (sua, sobe com amizade) e **capacidade** (do prédio, só muda
  comprando) são números diferentes. Cota batendo na capacidade é o que
  destrava a compra.
- **Melhorar custa a produção de outro estabelecimento**, nunca só dinheiro.
- **Relação sobe por constância**, não por volume nem dinheiro. Não zera.
- **Mecânica sem decisão que pode dar errado é morna.** O atrito padrão é
  limite.
- **Nada de grind de coleta.** A mina foi cortada e não volta.
- **Toda mecânica compete pelo relógio.** Não custa tempo, não é decisão.

Mecânica proposta que viola um desses ou muda, ou muda o princípio — mas não
passa calada.

## Playground primeiro

Toda mecânica ou regra de negócio nova (pescaria, craft, skills, troca de cena,
respawn, o que for) nasce em `sim/` e ganha seus botões no playground
(`game/dev/`) **na mesma wave**. O objetivo é o jogo completo jogável por
botões; o jogo visual (sprites, animações, mapa) só implementa o que já foi
jogado e aprovado no playground. Mecânica sem painel no playground é wave
incompleta.

## Documentação é visual

O time tem duas pessoas e uma delas não lê código. Documentação só em `.md` não
é entrega completa.

Existe **uma página viva** — o Manual do Project-DV, publicado como artefato em
`https://claude.ai/code/artifact/f66c7542-73f4-4c14-ba37-e0d4bde73302` — e ela é
a porta de entrada do projeto: o que o jogo é, como a arquitetura funciona, o
que já está pronto, o que falta para o beta, como rodar e o que dá para mexer
sem programar.

Regras:

- **Toda wave fechada atualiza o manual** antes de a wave ser dada por
  encerrada. Wave que muda arquitetura, decisão travada, ordem do laço ou
  necessidade de arte tem que aparecer lá.
- **Uma página só.** Republicar sempre no mesmo endereço, nunca criar uma
  segunda — o link é distribuído e tem que continuar valendo.
- Os `.md` em `docs/` continuam sendo a fonte de verdade escrita
  (`GAMEPLAY.md` para design, `ARTE.md` para a especificação de arte). O manual
  é a leitura, não a fonte — se divergirem, o `.md` manda e o manual é corrigido.

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
- **Arquivos e funções**: `snake_case` (`crescimento_cultura.gd`, `avanca_dia()`).
- **Classes**: `PascalCase` (`class_name EstadoCultura`).
- **Constantes**: `SCREAMING_SNAKE_CASE`.
- **Comentários e mensagens de commit**: português brasileiro.
- Um `class_name` por arquivo, com o nome do arquivo correspondendo.

### Tudo em português

**Todo nome que nós escolhemos é em português**: classes, arquivos, funções,
variáveis, sinais, constantes, chaves de dicionário e chaves do save. Sem
mistura. `colher()`, não `harvest()`. `EstadoFazenda`, não `FarmState`.

Fica em inglês só o que a engine obriga e nós não escolhemos: `_ready`,
`_process`, `extends`, `class_name`, `Resource`, `Node`, `Vector2i`,
`to_dict`/`from_dict` e afins. A regra prática: se o nome foi decisão nossa, é
português.

Sinais no passado: `dia_virou`, `cultura_colhida`.

**Não renomeamos o que já existe.** O código das waves 01–08 nasceu com nomes em
inglês (`SimWorld`, `CropDef`, `FarmSystem`, `advance`, `snapshot`) e continua
assim — rename retroativo é risco sem retorno. A regra vale para código novo.
Ao mexer num arquivo antigo, nome novo entra em português; o que já está lá não
se traduz de carona.

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
