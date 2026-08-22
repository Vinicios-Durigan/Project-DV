# PRINCÍPIOS — como uma mecânica nasce neste jogo

Decidido em 2026-08-21. Vale para **toda** mecânica futura: pecuária, pescaria,
mineração de terceiros, artesanato, festivais, o que vier.

`GAMEPLAY.md` diz o que o slice é. Este documento diz **como pensar** qualquer
coisa nova. Se uma mecânica proposta viola um princípio daqui, ou a mecânica
muda ou o princípio muda — mas não passa calada.

---

## 1. A tese do jogo

> O jogador começa dependente da cidade. A autossuficiência é o **prêmio de fim
> de jogo**, e ela é comprada com dependência.

No gênero, o jogador termina numa ilha-fábrica que não precisa de ninguém. Aqui
ele chega lá, mas só atravessando a cidade inteira — e o último estabelecimento
custa a produção de todos os outros.

O jogo tem fim: dominar a cadeia. Isso é o inverso do gênero e é o que vende.

---

## 2. A transformação mora na cidade, nunca em casa

**Não existe forja, bancada, alambique ou oficina na fazenda.**

Matéria-prima vira produto num estabelecimento de terceiro: você entrega, paga
taxa, espera, e **vai buscar**.

Isso é o que substitui o craft caseiro do gênero. Também é o que mantém a cidade
relevante do começo ao fim.

**Consequência para mecânica nova:** se a proposta inclui "o jogador constrói X
na fazenda para produzir Y", ela está errada. O X é de alguém na cidade.

---

## 3. A escada de três degraus

Todo estabelecimento tem a mesma progressão. Cada um sobe no seu ritmo, e o
jogador escolhe qual subir.

| Degrau | Como o jogador vende / usa | Lucro |
|---|---|---|
| **Caixote** | joga lá, some de manhã | baixo |
| **Contrato** | amizade destrava entrega direta | médio |
| **Dono** | produz e vende com valor agregado | alto |

**O caixote nunca morre.** Ele continua existindo depois do contrato e depois da
compra, como a opção "não quero pensar hoje". Todo jogo de fazenda precisa de um
dia preguiçoso.

---

## 4. Cota e capacidade são números diferentes

- **Cota** — quanto daquele estabelecimento é seu. Sobe com **amizade**.
- **Capacidade** — quanto o prédio aguenta no total. Só muda **comprando e
  melhorando**.

A amizade empurra a cota até ela bater na capacidade. O dono não tem mais o que
te dar — e é isso que destrava a compra.

A compra não é um botão que aparece quando você tem dinheiro. Ela é a
consequência de ter esgotado a boa vontade de alguém.

---

## 5. Melhorar custa a produção dos outros

Ampliar um estabelecimento **nunca** custa só dinheiro. Custa a saída de outro
estabelecimento que você ainda não possui.

Ampliar o moinho pede viga de ferro. Viga de ferro sai do ferreiro. Você não é
dono do ferreiro.

Dinheiro sozinho como custo transforma progressão em número. O insumo cruzado é
o que faz a tese do princípio 1 se sustentar até o fim.

**Segundo custo obrigatório: parada.** Estabelecimento em obra não produz. O
jogador estoca antes ou aceita perder constância — e não consegue melhorar tudo
ao mesmo tempo.

---

## 6. Relação sobe por constância

Entregou hoje, sobe um ponto. Duas entregas no mesmo dia contam uma.

**Faltou, não sobe — mas não perde.** Mesma filosofia da planta não regada, que
pausa em vez de morrer. Punir ausência num jogo sem automação é castigo duplo.

Descartado: relação por volume (uma colheita gigante compraria amizade) e por
dinheiro gasto (transforma amizade em compra e mata a ideia de cidade viva).

---

## 7. Mecânica sem decisão que pode dar errado é mecânica morna

Se o jogador entrega, espera e recebe sem nunca poder errar, não há jogo — há
uma esteira.

**O atrito padrão é limite.** Capacidade, cota, espaço de mochila, prazo,
relógio. O limite é o que transforma "entregar" em "quando e quanto entregar".

Antes de aprovar qualquer mecânica, responda: *qual decisão dessa mecânica pode
sair errada?* Sem resposta, ela volta para a prancheta.

---

## 8. Nada de grind de coleta

**A mina foi cortada em 2026-08-21, e não volta.** Vasculhar caverna procurando
minério é o oposto do prazer que este jogo oferece — que é planejar, compor e
otimizar.

Matéria-prima entra por **produção** (fazenda, e futuramente pecuária e
pescaria) ou por **compra**. Nunca por vasculhar.

As quatro funções que a mina cumpria no gênero foram realocadas:

| Função da mina | Onde mora agora |
|---|---|
| Progressão vertical | Ferreiro melhora sua ferramenta |
| Variância | Demanda e encomenda dos estabelecimentos |
| Verbo diferente | Operar produção, decidir receita, entregar |
| Concorrência pelo dia | Ir à cidade custa tempo do relógio |

---

## 9. Toda mecânica compete pelo relógio

O dia útil tem 15 minutos reais e isso é o limitador do jogo. Mecânica que não
custa tempo não é decisão — é botão.

Item beneficiado fica no estabelecimento **até o jogador buscar**. Buscar custa
o dia. É de propósito.

---

## 10. Punição pausa, não destrói

Planta não regada pausa, não morre. Relação sem entrega não sobe, não cai.
Encomenda esquecida espera, não estraga.

O jogo é sobre compor, não sobre não vacilar.

---

## 11. Regras herdadas que continuam valendo

Estas vêm de `CLAUDE.md` e `GAMEPLAY.md` e não se rediscutem aqui:

- **Playground primeiro** — mecânica nova ganha botões na mesma wave.
- **Conteúdo é id + catálogo** — estabelecimento novo é `.tres`, não código.
- **Evento gordo, sistema magro** — o dado que `game/` vai precisar viaja no
  evento.
- **`sim/` decide, `game/` apresenta** — nenhum `if` de regra em `game/`.
- **Save versionado, campo novo com default.**

---

## 12. Prova de fogo para mecânica nova

Antes de escrever a wave, a mecânica proposta tem que passar em todas:

1. A transformação acontece na cidade, não na fazenda?
2. Ela tem os três degraus, ou justifica por que não tem?
3. Qual decisão dela pode dar errado?
4. Ela custa tempo do relógio?
5. Melhorar exige insumo de terceiro, ou só dinheiro?
6. Dá para jogá-la inteira por botão no playground?
7. Quantos arquivos existentes ela obriga a tocar? Mais de um é cheiro de que o
   design falhou.
