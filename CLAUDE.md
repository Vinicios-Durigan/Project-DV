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

### A ordem do projeto — decidida em 2026-08-21

**Primeiro todas as mecânicas, jogadas e aprovadas no playground. Só depois o
jogo visual na Godot.**

Não se alterna entre uma wave de regra e uma de tela. O jogo inteiro é jogado
por botão, do começo ao fim, antes de a primeira cena de verdade existir.

O motivo: descobrir que uma mecânica não é divertida custa uma tarde no
playground e custa semanas depois que a arte foi desenhada em cima dela. Arte
feita para mecânica que vai mudar é arte jogada fora.

Consequência prática: nenhuma wave de `game/` (mapa, personagem, ferramentas,
HUD) é planejada enquanto houver mecânica de `sim/` na fila. Se aparecer pressão
para "ver algo na tela", a resposta é o playground — ele já mostra o jogo
inteiro funcionando.

Isso **não** libera escopo infinito: a lista de mecânicas do slice é fechada e
está no manual. Mecânica que não está na lista entra depois do beta visual, não
antes.

## A cena é nossa, a arte é dele

Cena de jogo nasce **por mão de dev**: hierarquia de nós, colisores, área de
interação, âncora, script. O artista nunca precisa criar cena, saber o que é
`Area2D`, nem lembrar de arrastar mais uma instância quando um conteúdo novo
entrar.

O que ele faz é preencher `.tres`. Sprite é um **campo de caminho** no `.tres`
(`ItemDef.sprite`, `CropDef.sprites_estagios`, `DefEstabelecimento.sprite`) —
`sim/` não conhece `Texture2D`, e quem transforma caminho em textura é
`game/icones.gd`, com cache.

Três consequências que valem para toda família de conteúdo:

- **Uma cena-molde por família, não uma cena por conteúdo.** Moinho, padaria e
  ferreiro são a mesma `estabelecimento.tscn`, carimbada com id e sprite
  diferentes. Conteúdo é id, não classe.
- **Quem carimba é código.** Um spawner lê o catálogo (`SistemaCidade.ids()`,
  `CropCatalog`, …) e instancia o molde uma vez por item encontrado. `.tres`
  novo aparece no jogo sozinho, sem editar cena e sem editar código.
- **O molde nasce sem arte.** Textura fixa dentro do `.tscn` vira mentira
  quando o segundo conteúdo daquela família chega. Arte faltando devolve `null`
  e o nó nasce sem desenho: a mecânica continua jogável antes de o primeiro
  sprite existir — a mesma promessa do playground.

Layout é `game/`, nunca conteúdo: **onde** um prédio fica sai de uma conta pela
ordem da lista (`Cidade.posicao_de`), não de uma coordenada digitada no `.tres`.
O artista não pensa em pixel para cadastrar conteúdo.

A referência do padrão é `game/cidade/` — `estabelecimento.tscn` é o molde e
`cidade.gd` é o spawner.

## Documentação é visual

O time tem duas pessoas e uma delas não lê código. Documentação só em `.md` não
é entrega completa.

Existem **duas páginas vivas**, e só duas. Cada uma tem um endereço fixo, e
nenhuma das duas ganha uma segunda versão.

**1. O Manual do Project-DV** —
`https://claude.ai/code/artifact/f66c7542-73f4-4c14-ba37-e0d4bde73302`

A porta de entrada: **como o projeto funciona**. Arquitetura, o que já está
pronto, o que falta para o beta, como rodar, o pacote do artista e o que dá para
mexer sem programar.

**2. Mecânicas do Project-DV** —
`https://claude.ai/code/artifact/3ac2de99-21b8-478c-bc51-14b4bc605180`

A referência de gameplay: **o que o jogo é**. Cada sistema com seus números
reais — culturas, terreno, itens, cota, relação, contratos —, o ciclo do dia
inteiro, o que está planejado e o que foi descartado com motivo. Escrita para
quem não abre o código.

Regras:

- **Toda wave fechada atualiza as duas páginas** antes de a wave ser dada por
  encerrada. Wave que muda arquitetura, decisão travada, ordem do laço ou
  necessidade de arte aparece no **manual**; wave que cria, muda ou rebalanceia
  mecânica aparece nas **mecânicas** — com o número real, o selo de `no jogo` ou
  `planejado` e a decisão que a sustenta. Página que mente sobre o balanceamento
  é pior que página nenhuma.
- **Duas páginas, dois endereços fixos.** Republicar sempre no mesmo endereço,
  nunca criar uma terceira — os links são distribuídos e têm que continuar
  valendo.
- As duas se linkam uma à outra. O link do manual para as mecânicas fica no
  topo e no rodapé.
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
  cidade/     os prédios da cidade: a cena-molde e o spawner que a carimba
  player/     controle do jogador, câmera, animação
  farm/       tilemap da fazenda, plantio visual, interação com o mundo
  ui/         HUD, menus, inventário na tela, diálogos
data/         recursos .tres que o artista edita direto no editor Godot
  cidade/     definição de cada estabelecimento (sprite, receita, cota)
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
