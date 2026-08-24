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

### A escala na tela é sempre inteira — inclusive na UI

A regra da tabela acima ("somente inteira") vale para a câmera **e para todo
lugar onde um sprite aparece**, incluindo o quadrado do inventário e o da
hotbar.

O motivo é fácil de confundir com "borrado". Nearest não borra: ele repete
pixel. O problema é que num aumento de 3,25× ele repete **desigual** — algumas
colunas do sprite saem com 3 pixels de largura e outras com 4. Resultado: o
contorno fica mordido, a linha de 1px fica ora fina ora grossa, e a arte parece
malfeita estando perfeita no arquivo.

Foi exatamente o que aconteceu em 2026-08-22: o slot da mochila dava 52px de
espaço a um ícone de 16px (3,25×) e o da hotbar dava 36px (2,25×). A arte estava
correta — 16×16, 16 cores, zero pixel semitransparente. Quem deformava era a
tela.

Hoje `game/dev/painel_mochila.gd` arredonda a escala para baixo sozinho (52
vira 48 = 3×, 36 vira 32 = 2×) e dois testes prendem a regra. **Quem for
desenhar tela nova precisa fazer o mesmo:** reserve espaço para o ícone e
arredonde para o múltiplo inteiro, em vez de esticar o sprite até preencher.

Consequência prática para quem desenha: um ícone só é julgado com honestidade
ampliado em ×2, ×3 ou ×4. Se você comparar o seu sprite com o de outro jogo numa
escala quebrada, está comparando com um handicap que não existe no jogo.

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

### Ligar o PNG à cultura ou ao item, no editor

Abra o `.tres` em `data/crops/` ou `data/items/` e olhe o grupo **Sprites**.
Cada campo de caminho é um seletor de arquivo: **arraste o PNG direto do painel
FileSystem** para dentro dele, ou clique na pasta e escolha. Não digite o
caminho à mão — uma letra errada não dá erro nenhum, o sprite simplesmente não
aparece quando o jogo roda.

Nos estágios da cultura são quatro caixas num array, uma por estágio, na ordem
`estagio_0` até `estagio_3`.

Se um sprite não aparecer, o nome ou a pasta estão errados. Confira caractere
por caractere: minúsculo, sem acento, sublinhado e não hífen.

---

## 10.1 O Fatiador — de uma imagem só para os arquivos do jogo

O projeto espera **um PNG por sprite**, com o nome exato deste documento. Se a
arte veio numa folha só, ou veio grande demais, não precisa recortar na mão.

Abra um terminal na raiz do projeto e rode:

```
tools\fatiar.bat
```

Abre uma janela. Não precisa instalar nada e não precisa saber programar — é a
Godot que faz o trabalho.

### As três colunas

**Esquerda — como cortar.** Abrir a imagem, remover o fundo, achar os desenhos,
acabamento. Mexer aqui muda quais sprites existem. O resumo e o botão de gravar
ficam fixos embaixo, sempre visíveis.

**Meio — a folha.** Cada desenho achado sai marcado em verde, com um número.

- **roda do mouse** dá zoom
- **arrastar** move a folha
- **clique** escolhe um sprite (fica laranja, e a linha dele acende na lista)
- **Ajustar** reenquadra a folha inteira

**Direita — a lista.** Uma linha por sprite: miniatura do resultado, o nome do
arquivo e **o tipo daquele sprite**.

### Uma folha, várias pastas

Este é o ponto. A folha de verdade tem os quatro estágios da cenoura, os do
rabanete, o pão, o regador e a enxada — tudo junto. Cada um mora numa pasta
diferente, e você **não** precisa recortar a mesma imagem cinco vezes.

O tipo é escolhido **sprite por sprite**, na lista da direita:

| Tipo | Vai para |
| --- | --- |
| Item | `assets/items/` |
| Cultura | `assets/crops/<nome>/` |
| Objeto do mundo | `assets/objects/` |
| Chão | `assets/tiles/` |
| UI | `assets/ui/` |
| Personagem | `assets/player/` |
| Partícula | `assets/fx/` |

O seletor da coluna esquerda é só o **padrão**, aplicado a todos quando a folha
abre. "Aplicar a todos da lista" reaplica quando você quiser recomeçar.

Em Cultura, a subpasta sai do **próprio nome**: chame o sprite de
`cenoura_estagio_0` e ele vai para `assets/crops/cenoura/`. Não há um segundo
campo para preencher.

### Nomear vários de uma vez

Nomear 25 sprites um a um dói, e digitar o mesmo nome em todos — o atalho
natural — produz 25 arquivos que se sobrescrevem. Por isso a ferramenta recusa
nomes repetidos na mesma pasta.

O jeito certo é o lote, que funciona igual ao "Juntar marcados":

1. Marque os quadradinhos dos sprites daquela cultura (ou **Marcar todos**)
2. Digite o **nome base** — `abobora`
3. Escolha a **ordem** que a folha usa
4. **Nomear marcados**

Saem `abobora_semente`, `abobora_estagio_0` até `_3` e `abobora_fruto`, na ordem
de leitura. O que não está marcado não é tocado — o pão e o regador da mesma
folha ficam com o nome que você deu.

A ordem importa e a ferramenta **não adivinha**, porque as folhas vêm das duas
maneiras. Olhe os números na imagem antes de escolher:

| Ordem | Quando usar |
| --- | --- |
| Cultura — semente, estágios, fruto | O pacote de semente é o primeiro desenho da folha |
| Cultura — estágios, semente, fruto | Os estágios vêm primeiro e os dois ícones no fim |
| Numerado — nome_0, nome_1, … | Não é cultura: quadros de partícula, peças de cerca |


O resumo embaixo mostra o total por pasta antes de gravar:

```
4 sprites
2 → res://assets/crops/cenoura
1 → res://assets/items
1 → res://assets/objects
todos saem 16×16
```

Depois de gravar, rode `godot --headless --import`, como na seção 10.

### Se a imagem veio grande, ou foi gerada por IA

A imagem tem 512 ou 1024 px, bordas suaves e centenas de tons. Reduzir isso para
16×16 e pronto não dá pixel art — dá uma mancha borrada com franja cinza em
volta.

Ligue **"Tratar como arte gerada"** (seção 6). Ele faz quatro coisas de uma vez,
que só funcionam juntas:

| Etapa | Por quê |
| --- | --- |
| Reduz até caber na célula | Sem cortar o desenho e sem achatar a proporção |
| Reduz suavizando | Pular pixel numa redução grande transforma o desenho em ruído |
| Corta o alfa | Pixel art não tem transparência pela metade — é o que tira a franja |
| Corta a paleta em 16 cores | **É isto que faz parecer pixel art.** Não é só o tamanho |

Cada uma continua disponível solta, logo abaixo do interruptor, para afinar.

### Se a contagem de sprites sair errada

| Sintoma | Conserto |
| --- | --- |
| Um desenho virou dois recortes | Aumente "Juntar pedaços a até" |
| Dois desenhos vizinhos viraram um só | Diminua "Juntar pedaços a até" |
| Apareceu recorte de sujeira | Aumente "Ignorar menor que" |
| Sobrou moldura de fundo em volta | Aumente a tolerância |
| Não achou nada | Escolha "Esta cor" e clique na cor do seu fundo |
| Sobrou fundo **dentro** do desenho | Ligue "Apagar a cor na imagem toda" |

Mexer nesses ajustes **não apaga** os nomes e tipos já escolhidos.

Dois desenhos encostados na folha são um sprite só para a ferramenta — nesse
caso separe os dois na imagem de origem por uns 3 px de fundo e abra de novo.

### Quando dois recortes são o mesmo item

Acontece: um grão partido em dois pedaços, uma ferramenta cujo cabo se afasta da
lâmina. A ferramenta separa por vizinhança e não tem como adivinhar — e subir
"Juntar pedaços a até" até colar aqueles dois cola também os vizinhos.

Nesse caso a decisão é sua, na lista da direita:

1. Marque o quadradinho dos dois (ou mais)
2. **Juntar marcados**

Eles viram um sprite só, na área que cobre todos. O vão entre os pedaços é
transparente e some no recorte. O sprite novo fica com o nome e o tipo do
primeiro — o de cima e à esquerda.

**Remover** descarta os marcados, para sujeira que virou recorte. **Refazer a
lista do zero** desfaz junções e remoções sem precisar reabrir o arquivo.

> Junções, nomes e tipos se perdem se você mexer nos ajustes de corte (seção 4).
> Acerte o corte primeiro, depois trabalhe a lista.

Ao lado de cada nome aparece o tamanho final — `16×16` em cinza quando está no
padrão, em laranja quando passou dele.

### O que trava a gravação

O botão fica desligado, com o motivo no resumo, quando:

- algum sprite está **sem nome**
- dois sprites têm **o mesmo nome na mesma pasta** — viraria um arquivo só, em
  silêncio (o mesmo nome em pastas diferentes é permitido)
- um sprite marcado como Cultura **não tem nome de cultura** — iria para
  `assets/crops/` solto, fora da subpasta que o jogo procura

Arquivo que já existe não é substituído sem perguntar.

### Pelo terminal, se preferir

Tudo o que a janela faz também roda por linha de comando:

```
tools\fatiar.bat --entrada=C:\caminho\itens.png --tipo=item --listar
tools\fatiar.bat --entrada=C:\caminho\trigo.png --tipo=cultura --slug=trigo
tools\fatiar.bat --entrada=C:\caminho\gerado.png --tipo=item --de-ia
```

`--listar` mostra o que achou sem gravar; `--contato=arquivo.png` grava uma
folha de conferência numerada. `tools\fatiar.bat --ajuda` lista o resto.

Pelo terminal o tipo vale para a folha inteira — folha misturada é caso para a
janela.

---

## 11. Já decidido, mas ainda não é para desenhar

Estes itens **estão decididos** e vão existir. Não desenhe agora — mas saiba que
vêm, porque eles mudam como você planeja o lote das culturas.

### Trigo — a quinta cultura (já existe no código, desde a wave 12)

A cidade precisa dela: trigo vira farinha no moinho, farinha vira pão na
padaria. Mesmo padrão da seção 2 — 4 estágios mais os dois ícones, na pasta
`assets/crops/trigo/`:

```
assets/crops/trigo/trigo_estagio_0.png   16×16
assets/crops/trigo/trigo_estagio_1.png   16×16
assets/crops/trigo/trigo_estagio_2.png   16×16
assets/crops/trigo/trigo_estagio_3.png   16×16   (pronta)
assets/crops/trigo/trigo_semente.png     16×16   (ícone do pacote)
assets/crops/trigo/trigo_fruto.png       16×16   (ícone na hotbar)
```

**Confirme com o dev antes de fechar o lote das quatro originais.** Se você já
está desenhando as 24, desenhar 30 de uma vez sai mais barato que voltar depois.

### Farinha e pão — dois ícones de item, sem cultura

Eles não crescem em canteiro: a cidade os fabrica. Precisam só do **ícone de
mochila**, no mesmo padrão dos frutos:

```
assets/items/farinha.png   16×16
assets/items/pao.png       16×16
```

Leitura instantânea importa aqui mais que nas culturas: pão é o item mais caro
do jogo até agora (260g contra 180g da abóbora), e o jogador tem que reconhecer
o que ele está carregando sem ler o nome.

### Moinho e padaria — os dois prédios da cidade

O campo de sprite **já existe**: `data/cidade/moinho.tres` e `padaria.tres`
trazem um campo `sprite` no inspector, com o mesmo funcionamento do ícone de
item — salvar o PNG na pasta e apontar o caminho liga a arte ao jogo, sem abrir
cena nenhuma. A cena do prédio (colisor, área de interação, âncora do pé) já
está montada e é a mesma para os dois.

| Sprite | Pasta | Campo do `.tres` |
|---|---|---|
| Moinho | `assets/objects/` | `sprite` de `moinho.tres` |
| Padaria | `assets/objects/` | `sprite` de `padaria.tres` |

Tamanho livre, mas múltiplo de 16 e **em pé**: o código ancora o prédio pelo pé,
então o (0,0) do desenho é o chão onde o jogador encosta. Largura maior que
64px começa a atrapalhar a distância entre um prédio e o vizinho.

O que já está travado e não vai mudar:

- são **dois** estabelecimentos no slice, moinho e padaria;
- cada um é um **ponto de interação** no mapa da cidade, não um cenário de
  fundo — o jogador chega, entrega, e volta depois para buscar;
- eles precisam mostrar, de longe, que **têm coisa pronta esperando**.

Sobre esse aviso: a cena hoje o trata como **ícone flutuante** — um sprite
separado, acima do prédio, que acende quando a encomenda fica pronta e apaga
quando o jogador busca. É um segundo PNG, não uma variação do prédio. Se a
proposta de arte for outra (fumaça saindo da chaminé, luz na janela), ela muda a
cena e precisa ser combinada antes de desenhar — traga a proposta.

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

### Cobertura do terreno — 5 tiles (wave 14, decidido em 2026-08-22)

A fazenda vai parar de nascer inteirinha limpa. Cada tile passa a ter uma
**cobertura**, e o jogador abre o terreno ao longo dos dias — pedra com
picareta, árvore com machado (vira toco), toco com o segundo golpe, mato com a
enxada.

Pasta: `assets/tiles/`

| Sprite | Quantidade | Nota |
|---|---|---|
| Mato | 2 | Duas variações — é a cobertura que mais aparece, e ela se espalha |
| Pedra | 1 | Já previsto na seção 3. Bloqueia passagem |
| Árvore | 1 | Ocupa 1 tile. Bloqueia passagem |
| Toco | 1 | O que sobra da árvore cortada. Bloqueia passagem |

**Regra de leitura, e ela é de jogo, não de estilo:** mato tem que parecer
*removível em um golpe* e pedra/árvore têm que parecer *trabalho de dias*. O
jogador decide onde plantar olhando o mapa de longe — se as quatro coberturas
tiverem o mesmo peso visual, a decisão vira tentativa e erro.

O toco precisa ler como "isso já foi uma árvore", senão o jogador não entende
por que o machado ainda pede um golpe ali.

### Água e regador — 3 sprites (wave 14.1)

O regador vai ter **carga** (15 tiles) e enche num poço de posição fixa.

| Sprite | Onde | Nota |
|---|---|---|
| Poço / água | `assets/tiles/` | O tile onde se enche. Fica perto da casa |
| Regador cheio | `assets/items/` | Ícone 16×16 na hotbar |
| Regador vazio | `assets/items/` | Mesmo regador, estado vazio — a leitura é a carga |

Cheio e vazio precisam ser **o mesmo regador** em dois estados, pela mesma razão
que a terra seca e a molhada são a mesma terra (seção 3): dois desenhos
diferentes leem como dois itens, não como um item que acabou.

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
