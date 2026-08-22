# ARTE — Especificação para o artista

Documento único de entrega de arte. Tudo aqui já está travado no código: os
caminhos abaixo estão escritos dentro dos `.tres` em `data/`. Salvar o arquivo
com o nome certo, na pasta certa, é o que liga a arte ao jogo — **não é preciso
abrir o editor do Godot para conectar nada**.

Fonte das decisões: `docs/GAMEPLAY.md` §2 e §12. Se este documento e o GAMEPLAY
divergirem, o GAMEPLAY manda.

---

## 1. Regras que valem para tudo

| Item | Valor |
|---|---|
| Estilo | Pixel art |
| Tile do mundo | **16×16 px** |
| Personagem | **16×32 px** |
| Resolução base do jogo | **640×360** (40×22,5 tiles na tela) |
| Escala | Somente inteira — ×2 = 720p, ×3 = 1080p, ×6 = 4K |
| Formato | PNG, fundo **transparente** |
| Filtro | Nearest (sem suavização) — o jogo já está configurado |
| Paleta | Livre, mas **uma só** para o projeto inteiro |

**Proibido:** desenhar em tamanho maior "para reduzir depois". Reduzir pixel art
destrói a arte. Desenhe no tamanho final.

**Proibido:** anti-aliasing e sombra com transparência parcial nas bordas. O
filtro nearest transforma pixel semitransparente em borda suja.

---

## 2. Culturas — 24 sprites

Quatro culturas, quatro estágios cada, mais dois ícones. **16×16 por estágio**,
desenhado ancorado no chão do tile (a planta cresce de baixo para cima; o topo
do tile pode ficar vazio).

### Nomenclatura — obrigatória, sem exceção

```
assets/crops/<slug>/<slug>_estagio_0.png     recém-plantado
assets/crops/<slug>/<slug>_estagio_1.png     broto
assets/crops/<slug>/<slug>_estagio_2.png     crescendo
assets/crops/<slug>/<slug>_estagio_3.png     pronta para colher
assets/crops/<slug>/<slug>_semente.png       ícone do pacote de semente (hotbar)
assets/crops/<slug>/<slug>_fruto.png         ícone do fruto colhido (inventário)
```

Os slugs são `rabanete`, `cenoura`, `morango`, `abobora` — sem acento, minúsculo.
O índice começa em **0**, não em 1.

### As quatro culturas

| Slug | Nome | Papel | Ciclo | Semente | Venda | Observação de arte |
|---|---|---|---|---|---|---|
| `rabanete` | Rabanete | Rápida | 4 dias | 20g | 35g | A primeira que o jogador vê |
| `cenoura` | Cenoura | Média | 6 dias | 30g | 65g | — |
| `morango` | Morango | Rebrota | 8 dias | 60g | 45g | **Ver regra especial abaixo** |
| `abobora` | Abóbora | Lenta | 13 dias | 80g | 180g | A mais valiosa — tem que parecer |

### Regra especial do morango

O morango rebrota: ao ser colhido, ele **volta para o `estagio_2`** e cresce de
novo. Logo, `morango_estagio_2.png` tem duplo papel — é "crescendo" e também é
"planta madura já colhida, sem fruto". Desenhe-o como uma planta adulta e
saudável **sem fruto visível**. O `estagio_3` é a mesma planta **com** morangos.

Isso é de propósito e economiza um sprite. Não desenhe um quinto estágio.

### A leitura do "pronta" é regra de jogo, não enfeite

O `estagio_3` precisa ser reconhecível **à distância da câmera, sem tooltip**.
Ele deve ser:

- **Maior** que o `estagio_2`, com silhueta claramente diferente
- **Distinto em forma**, não só em cor — o jogo precisa funcionar para daltônicos
- Preparado para um **balanço de 2 frames** (o código anima; você só garante que
  a planta tem uma silhueta que aguenta balançar sem ficar estranha)

### Canais de informação — nunca misturar

A **terra** comunica se foi regada (clara = seca, escura = molhada).
A **planta** comunica o estágio de crescimento.

Nunca deixe a planta indicar rega, nunca deixe a terra indicar estágio. São dois
canais separados e o jogador aprende cada um uma vez só.

---

## 3. Tileset de chão — 16×16

Pasta: `assets/tiles/`

| Sprite | Quantidade | Nota |
|---|---|---|
| Grama base | 1 | — |
| Grama com detalhe | 2–3 | Variação visual, quebra a repetição |
| Terra arada **seca** | 1 | Tom claro |
| Terra arada **molhada** | 1 | Mesma terra, tom escuro — é o canal de rega |
| Transição grama ↔ terra | autotile mínimo | Cantos e bordas |
| Pedra | 1 | Bloqueia passagem |
| Toco / árvore | 1 | Bloqueia passagem |

A terra seca e a molhada precisam ser **a mesma terra** em dois tons. Se forem
texturas diferentes, o jogador lê como dois tipos de solo, não como rega.

---

## 4. Personagem — 16×32, 4 direções

Pasta: `assets/player/`, arquivos `player_<acao>.png`.

Cada arquivo é um **spritesheet em grade**, células de 16×32:

- **Linhas = direção**, nesta ordem fixa: `0 baixo, 1 cima, 2 esquerda, 3 direita`
- **Colunas = frames** da animação, na ordem de reprodução

Quatro direções desenhadas de verdade — **não** desenhe só o lado e espelhe. A
ferramenta na mão fica na mão errada quando espelhada.

| Arquivo | Grade (colunas × linhas) | Frames |
|---|---|---|
| `player_idle.png` | 1 × 4 | 4 |
| `player_andar.png` | 4 × 4 | 16 |
| `player_enxada.png` | 3 × 4 | 12 |
| `player_regador.png` | 3 × 4 | 12 |
| `player_plantar.png` | 3 × 4 | 12 |
| `player_colher.png` | 3 × 4 | 12 |

**Total: 68 frames.**

A ferramenta é desenhada **junto no frame**, não como camada separada.

O swing de ação dura ~0,3s (3 frames). O impacto — o momento em que a enxada
bate no chão — deve estar no **frame 2 de 3**, para o efeito na tela sincronizar
com a animação.

---

## 5. Objetos

Pasta: `assets/objects/`

| Sprite | Tamanho | Nota |
|---|---|---|
| Caixote fechado | 16×16 ou 16×32 | Onde o jogador deposita para vender |
| Caixote aberto | igual ao fechado | Estado ao interagir |
| Fachada da casa com porta | livre | **Sem interior** — dormir é na porta |

O slice não tem interior de casa. Não desenhe cama, mesa nem parede interna.

---

## 6. UI

Pasta: `assets/ui/`

| Item | Tamanho | Quantidade |
|---|---|---|
| Slot da hotbar | 16×16 ou 18×18 | 1 + 1 variante "selecionado" |
| Ícones de ferramenta | 16×16 | 3 (enxada, regador, mão/colher) |
| Retículo de tile — válido | 16×16 | 1 |
| Retículo de tile — inválido | 16×16 | 1, cor diferente |
| Moldura de painel | 9-slice | 1 (caixote, resumo do dia) |
| Fonte pixel | — | Pode ser fonte livre pronta |

Os ícones das 4 colheitas e dos 4 pacotes de semente **já estão na seção 2** —
são os arquivos `<slug>_fruto.png` e `<slug>_semente.png`. Não desenhe de novo.

O retículo fica **sempre visível** enquanto o jogador segura uma ferramenta, e
muda de cor quando a ação é inválida naquele tile. Escolha duas cores que se
distinguem sem depender de vermelho contra verde.

---

## 7. Partículas — 2 a 3 frames cada

Pasta: `assets/fx/`

| Efeito | Quando aparece |
|---|---|
| Poeira | Ao arar |
| Gotas de água | Ao regar |
| Glint / brilho | Cultura pronta, pulso periódico |

---

## 8. Áudio — registrado para não perder

Não é arte, mas faz parte da entrega do slice: thunk terroso (arar), pop suave
(plantar), água curta (regar), pluck + chime (colher), escala de notas para rega
em sequência, som de dormir/manhã, música ambiente de dia.

---

## 9. Ordem de entrega sugerida

A ordem segue as waves de implementação. Entregar fora de ordem não trava nada,
mas nesta ordem o jogo fica jogável mais cedo.

1. **Tileset de chão** — sem ele não existe mapa
2. **Personagem: idle + andar** — sem ele o jogador não se move
3. **Personagem: ações** — enxada, regador, plantar, colher
4. **Culturas** — as 24 imagens da seção 2
5. **Objetos e UI**
6. **Partículas e áudio**

---

## 10. Como testar sem saber programar

1. Salve os PNGs nas pastas com os nomes exatos deste documento
2. Abra um terminal na raiz do projeto
3. Rode `godot --headless --import`
4. Abra o jogo — a arte aparece sozinha

Se um sprite não aparecer, o nome ou a pasta estão errados. Confira caractere
por caractere: minúsculo, sem acento, sublinhado e não hífen.

---

## 11. Já decidido, mas ainda não é para desenhar

Estes itens **estão decididos** e vão existir. Não desenhe agora — mas saiba que
vêm, porque eles mudam como você planeja o lote das culturas.

### Trigo — a quinta cultura

A cidade precisa dela: trigo vira farinha no moinho, farinha vira pão na
padaria. Mesmo padrão da seção 2 — 4 estágios mais os dois ícones, na pasta
`assets/crops/trigo/`.

**Confirme com o dev antes de fechar o lote das quatro originais.** Se você já
está desenhando as 24, desenhar 30 de uma vez sai mais barato que voltar depois.

### Cultura gigante

Um bloco 3×3 da mesma cultura vira uma planta gigante, que vale muito mais e é a
matéria-prima dos produtos de maior valor da cidade.

O que isso pede: **uma versão gigante por cultura**, ocupando os 9 tiles
(48×48 px), desenhada como uma peça só e não como nove tiles repetidos. A leitura
tem que ser instantânea — o jogador precisa ver de longe que aquele canteiro
deu certo.

Não desenhe ainda: o sistema só chega depois do beta e o formato exato
(48×48 único ou 9 peças montáveis) ainda não foi fechado.

### Híbrido

Culturas vizinhas certas geram um híbrido raro. Cada híbrido é uma cultura nova,
com os mesmos 6 arquivos da seção 2.

Quantos e quais combinam ainda não foi decidido. Contar com **2 a 4 híbridos**
no orçamento de arte de longo prazo.

---

## 12. Pendências de design que ainda não viraram spec

Não desenhe estes itens ainda — a decisão não foi tomada:

- **Sprite de murcha** (planta morta no fim da estação). O `CropDef` ainda não
  tem campo para isso; entra numa wave futura.
- **Nomes e visual final das culturas.** Os slugs `rabanete`, `cenoura`,
  `morango` e `abobora` estão travados no código, mas o visual pode fugir do
  vegetal real se o artista tiver ideia melhor. Combine antes de desenhar.
- **Paleta do projeto.** Precisa ser definida junto antes do primeiro tileset —
  refazer paleta depois é refazer tudo.
