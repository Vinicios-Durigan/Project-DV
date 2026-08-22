---
wave: 10
titulo: Cidade — beneficiamento e cota
paralelo: nao
depende_de: [07, 08]
---

## Objetivo

A cidade transforma o que a fazenda não consegue transformar em casa: o jogador
entrega matéria-prima, paga taxa, espera e **vai buscar** o produto beneficiado.

Primeira wave sob `docs/PRINCIPIOS.md` e primeira sob a regra de nomes em
português.

## Decisões

- **Um degrau só, o do beneficiamento.** Comprar estabelecimento é wave 11;
  automação com funcionário é wave 12. O degrau do beneficiamento sozinho já
  prova a tese: interdependência, custo de tempo e valor agregado.
- **Dois estabelecimentos, não um.** Moinho (trigo → farinha) e padaria
  (farinha → pão). A padaria come a saída do moinho — é a cadeia que prova a
  dependência; um estabelecimento sozinho seria só uma máquina de troca.
- **Prazo por estabelecimento, em minutos de jogo**, num relógio monotônico
  (`dia × 1440 + minuto`). Uma unidade só resolve "4 horas" e "3 dias" sem caso
  especial para a noite: dormir adianta o relógio e a encomenda avança junto.
- **Cota e capacidade são campos separados** desde já, mesmo que só a cota se
  mexa nesta wave. Capacidade é o teto do prédio e só muda na wave 12 —
  registrar agora evita migração depois.
- **Relação sobe por constância**: uma entrega credita um dia; duas entregas no
  mesmo dia contam uma. Faltar não zera (PRINCIPIOS §6).
- **O item beneficiado fica no estabelecimento até a retirada.** Mesmo formato
  do `ShippingState` do caixote — a retirada é um `ItemGrantedEvent`, igual ao
  `ItemWithdrawnEvent`. Buscar custa o dia, e é de propósito (PRINCIPIOS §9).
- **Cota é o atrito** (PRINCIPIOS §7): o moinho não engole a colheita inteira,
  então a decisão vira *quando e quanto* entregar — e a constância acontece
  sozinha, sem o jogo pedir.
- **O caixote continua vendendo tudo**, sem mudança. Ele é a opção preguiçosa e
  não morre (PRINCIPIOS §3).
- Ordem de registro no tick: Inventory → Shipping → Farm → **Cidade** → Time. A
  cidade entra depois do Farm (a colheita da manhã já está na mochila quando a
  cidade conclui encomendas) e antes do Time.

## Impacto

- **Eventos novos:** `EntregaAceitaEvent` (estabelecimento, item, qtd, taxa,
  minuto de conclusão), `BeneficiamentoProntoEvent` (estabelecimento, item,
  qtd), `RetiradaFeitaEvent` (é um `ItemGrantedEvent`), `RelacaoSubiuEvent`
  (estabelecimento, dias, cota nova).
- **Muda evento existente:** nenhum.
- **Muda formato de save:** bloco novo `cidade`, todos os campos com default —
  sem migração, versão continua 1.
- **Escuta:** o relógio, para concluir encomenda cujo minuto chegou. Sem
  dependência de `DayEndedEvent` — encomenda de 4 horas conclui no meio do dia.
- **Arte necessária:** nenhuma nesta wave. Trigo, farinha e pão entram no
  `docs/ARTE.md` como pendência de arte para a wave visual.
- **Toca `game/`:** só o painel do playground.
- **Conteúdo novo:** cultura trigo + itens farinha e pão. Sem código novo — usa
  `CropDef` e `ItemDef` existentes.

## Tarefas

### 10.1 — A cadeia de itens
Cria: data/crops/trigo.tres, data/items/trigo.tres, data/items/semente_trigo.tres, data/items/farinha.tres, data/items/pao.tres, tests/test_cadeia_trigo.gd
Faz: a cultura e os três itens que a cidade vai transformar, registrados nos
catálogos existentes. Zero código novo. Balanceamento pela fórmula-mestre do
GAMEPLAY §5: pão vale mais que farinha, que vale mais que trigo, com folga para
a taxa de beneficiamento.

### 10.2 — DefEstabelecimento
Cria: sim/cidade/def_estabelecimento.gd, data/cidade/moinho.tres, data/cidade/padaria.tres, tests/test_def_estabelecimento.gd
Depende de: 10.1
Faz: recurso que o artista/designer edita — id, nome, item de entrada, item de
saída, quantos entram por quantos saem, prazo em minutos de jogo, taxa por
unidade, cota inicial, capacidade total, limiares de relação por degrau. Todo
campo com default que preserva comportamento.

### 10.3 — EstadoCidade
Cria: sim/cidade/estado_cidade.gd, tests/test_estado_cidade.gd
Depende de: 10.2
Faz: por estabelecimento — dias com entrega, último dia creditado, cota atual,
encomendas em andamento (item, qtd, minuto de conclusão) e prontas para
retirada. `to_dict`/`from_dict` com default em tudo.

### 10.4 — SistemaCidade
Cria: sim/cidade/sistema_cidade.gd, sim/cidade/entregar_action.gd, sim/cidade/retirar_action.gd, tests/test_sistema_cidade.gd
Depende de: 10.3
Faz: entregar (valida cota, cobra taxa, agenda conclusão pelo relógio
monotônico, credita constância uma vez por dia), concluir no tick quando o
minuto chega, retirar (devolve como `ItemGrantedEvent`). Rejeição por cota
estourada ou dinheiro insuficiente sai como `ActionRejectedEvent`.

### 10.5 — Painel da cidade no playground
Cria: game/dev/painel_cidade.gd
Depende de: 10.4
Faz: por estabelecimento — relação, cota usada/total, fila de encomendas com
tempo restante, botões de entregar e retirar. Usa o padrão 2 (mandar ordens) e
o padrão 3 (escutar avisos) de `docs/receitas/`.

## Em aberto

- **Quantos estabelecimentos o jogo terá no total.** Dois provam a cadeia; o
  número final decide o tamanho da cidade e o custo de arte. Decidir antes da
  wave 11.
- **O ferreiro** — melhora de ferramenta é a função de progressão herdada da
  mina (PRINCIPIOS §8). Ele entra como estabelecimento, mas a saída dele não é
  item de inventário e sim upgrade de ferramenta. Formato a decidir.
- **Capacidade compartilhada com a cidade.** Se o moinho serve a vila inteira, a
  cota do jogador é uma fatia de algo em uso. Isso é fonte de renda passiva
  quando ele virar dono — decidir na wave 11.
- **Trigo é a quinta cultura.** Confirmar com o artista antes de ele fechar a
  paleta e o lote das quatro originais.

## Herdado da wave 09, para a wave do contrato

A wave 09 ("Pedido do dia") foi absorvida e removida em 2026-08-21: encomenda de
um dono que te conhece e cobra é a mesma mecânica, só que melhor. O degrau 2 da
escada (contrato) é a 09 reescrita com dono. Estas decisões dela continuam
valendo e **não podem se perder**:

- **Sorteio determinístico.** A semente do RNG mora no state e entra no save.
  Mesmo save, mesma sequência de encomendas — replay e bug report continuam
  confiáveis. O que muda é quem sorteia: o estabelecimento sorteia o que quer
  hoje, em vez de o caixote sortear uma cultura da sorte.
- **O sistema que pede não lê o state de quem vende.** Reage ao evento e guarda
  o que precisa no próprio state. Regra de comunicação da wave 02.
- **Dia 1 não tem encomenda.** A primeira chega na manhã do dia 2, junto com a
  cascata da virada — evita caso especial de boot.
- **`ItemsSoldEvent.Linha` ganha `multiplicador`** (default 1), para o resumo do
  dia mostrar o bônus do contrato. Evento gordo, sistema magro.
- **Descartado com a 09:** bônus solto no caixote sem dono por trás. Recusar uma
  encomenda tem que custar relação com alguém, senão não é decisão.
