# Eventos da simulação

Mantido pelas skills `/dev` e `/revisar` — não edite à mão.

| Evento | Quem emite | Quem escuta |
| --- | --- | --- |
| `MinuteTickedEvent` | `TimeSystem` (tick) | `game/dev/playground.gd` — o relógio da barra de status; HUD do jogo na wave de `game/` |
| `DayEndedEvent` | `TimeSystem` (`SleepAction` → `SLEPT`; 02:00 → `COLLAPSED`) | `FarmSystem` — a cascata da manhã; `SaveGateway` — autosave (GAMEPLAY §3, passo 4); `game/dev/medidor_dia.gd` — fecha o resumo do dia e zera o cronômetro; fadiga futura ainda não escuta |
| `ActionRejectedEvent` | quem detecta a impossibilidade (`SistemaLocais`, `InventorySystem`, `ShippingSystem`, `FarmSystem`, `SistemaCidade`) | `game/dev/aviso_recusa.gd` — o toast com o motivo em português; sistemas seguintes só olham a flag `rejeitada` |
| `ItemAddedEvent` | `InventorySystem` (`AddItemAction`) | `game/dev/painel_mochila.gd` — a hotbar e a grade da mochila; popup de item na wave de `game/` |
| `SlotMovidoEvent` | `InventorySystem` (`MoverSlotAction`) | `game/dev/painel_mochila.gd` — redesenha os dois quadrados que mudaram |
| `SlotEquipadoEvent` | `InventorySystem` (`EquiparSlotAction`) | `game/dev/mira_ferramentas.gd` — troca o rótulo do retículo; `game/dev/painel_mochila.gd` — destaca o slot da mão |
| `ItemRemovedEvent` | `InventorySystem` (`RemoveItemAction`) | ninguém ainda — hotbar na wave de `game/` |
| `ItemLostEvent` | `InventorySystem` (mochila cheia) | ninguém ainda — aviso na tela; drop no chão é futuro |
| `MoneyChangedEvent` | `InventorySystem` (`AddMoneyAction`) | `game/dev/playground.gd` — o dinheiro da barra de status; HUD do jogo na wave de `game/` |
| `ItemGrantedEvent` | qualquer mecânica que conceda item (`FarmSystem`, `ShippingSystem`, `SistemaCidade`) | `InventorySystem` — reage adicionando à mochila |
| `PlotTilledEvent` | `FarmSystem` (`TillPlotAction`) | `game/dev/mundo_esboco.gd` — tremida da tela, swing e piscada do canteiro; troca do tile na wave de `game/` |
| `CropPlantedEvent` | `FarmSystem` (`PlantCropAction`) | `game/dev/mundo_esboco.gd` — swing e piscada; sprite do estágio 0 na wave de `game/` |
| `PlotWateredEvent` | `FarmSystem` (`WaterPlotAction`) | `game/dev/mundo_esboco.gd` — swing, piscada e o solo escurecendo; ritmo de rega ainda é futuro |
| `CropHarvestedEvent` | `FarmSystem` (`HarvestCropAction`) | `InventorySystem` (é um `ItemGrantedEvent`); `game/` anima o arco até o jogador |
| `CropGrewEvent` | `FarmSystem` (reage a `DayEndedEvent`) | `game/dev/mundo_esboco.gd` — a cascata da manhã-espetáculo pisca canteiro a canteiro, na ordem dos plots (e sem swing: quem trabalhou foi a noite) |
| `CropDiedEvent` | `FarmSystem` (fim de estação, dia 28) | ninguém ainda — sprite de murcha na wave de `game/` |
| `ItemShippedEvent` | `ShippingSystem` (`ShipItemAction`, já cobrada pelo inventário) | ninguém ainda — painel do caixote na wave de `game/` |
| `ItemWithdrawnEvent` | `ShippingSystem` (`WithdrawItemAction`) | `InventorySystem` (é um `ItemGrantedEvent`) — o item volta para a mochila |
| `ItemsSoldEvent` | `ShippingSystem` (`SleepAction`, passo 1 da sequência de dormir) | `InventorySystem` — soma o dinheiro; `game/dev/medidor_dia.gd` — monta o resumo do dia com estas linhas + `DayEndedEvent` |
| `SeedBoughtEvent` | `InventorySystem` (`BuySeedAction`) | ninguém ainda — aba de compra do painel na wave de `game/`; o `MoneyChangedEvent` e o `ItemAddedEvent` vêm logo atrás |
| `JogadorViajouEvent` | `SistemaLocais` (`ViajarAction`, despachada quando o jogador cruza a fronteira de um terreno) | `game/dev/mundo_esboco.gd` e `game/dev/inspetor_tile.gd` — mostram onde o jogador está **segundo a sim**; quando discordar da tela, quem errou é `game/` |
| `EntregaAceitaEvent` | `SistemaCidade` (`EntregarAction`, já cobrada pelo inventário) | `game/dev/painel_cidade.gd` — põe a encomenda na fila com o tempo restante |
| `BeneficiamentoProntoEvent` | `SistemaCidade` (reage ao relógio, quando o minuto de conclusão chega) | `game/dev/painel_cidade.gd` — a linha da fila vira "pronta". Não tem `player_id`: ninguém agiu, foi o tempo |
| `RetiradaFeitaEvent` | `SistemaCidade` (`RetirarAction`, com a taxa já cobrada pelo inventário) | `InventorySystem` (é um `ItemGrantedEvent`) — o produto entra na mochila |
| `RelacaoSubiuEvent` | `SistemaCidade` (primeira entrega do dia num estabelecimento) | `game/dev/painel_cidade.gd` — atualiza "relação N dias · cota X/Y" |

## Como o evento chega em `game/`

Desde a wave 07 todo evento da tabela sai da sim pelo mesmo cano: o `SimBridge`
(nó raiz de `game/main.tscn`) reemite cada um como o sinal `sim_event`, na ordem
em que aconteceram. Quem quiser escutar recebe a bridge por `setup(bridge)` e
filtra por tipo — "ninguém ainda" nesta tabela quer dizer "nenhum nó filtra este
tipo", não que o evento não chegue.

O playground (`game/dev/playground.tscn`, wave 08) é a exceção da coluna "quem
escuta": o diário de avisos mostra **todo** evento da tabela, com o nome real da
classe e todos os campos, por reflection. Evento novo aparece lá sem ninguém
mexer no painel — se ele não aparece, não está saindo da sim.

Desde a wave 11 o diário também **colore por dono**: fazenda no verde, tempo no
céu, cidade na terra, recusa no alerta, dinheiro no ouro. Evento sem dono na
tabela do `event_feed.gd` aparece igual, na tinta — nenhuma linha some por falta
de cor.

## A ordem dos sistemas é regra de jogo

Desde a wave 12 o tick central roda **Locais → Inventory → Shipping → Farm →
Cidade → Time**. O `SistemaLocais` é o primeiro por um motivo concreto, não por
organização: `PlantCropAction` estende `RemoveItemAction`, então a semente sai
da mochila ao passar pelo `InventorySystem`. Se o carimbo de "fora do lugar"
chegasse depois, plantar na cidade cobraria a semente de uma ação recusada.

A `SistemaCidade` entra depois do Farm — a colheita da manhã já está na mochila
quando ela age — e antes do Time, que é quem fecha o dia.

Quem detecta a impossibilidade marca `action.rejeitada = true` e emite
`ActionRejectedEvent`; os sistemas seguintes começam com `if action.rejeitada:
return []`. Ninguém desfaz nada — é por isso que a ordem importa.

## A transação da cidade cabe em duas ações porque o dinheiro não é dela

Entregar tira item da mochila; retirar cobra dinheiro. Os dois são do
`InventorySystem`, que roda **antes** da cidade — e uma ação só estende uma
classe. Por isso a wave 12 partiu a transação em duas:

- `EntregarAction` **é** uma `RemoveItemAction` — o inventário tira o trigo, ou
  recusa por `item_insuficiente`;
- `RetirarAction` **é** uma `AddMoneyAction` com valor negativo — o inventário
  cobra a taxa, ou recusa por `dinheiro_insuficiente`.

Nenhum sistema existente precisou ser editado, e as duas recusas caras saem de
quem sabe responder por elas. A ficção fecha junto: entrega o trigo, paga o
moleiro quando busca a farinha — e a farinha fica presa ocupando cota até ele
ter o dinheiro.

O preço é o mesmo do `PlantCropAction`: a entrega cobra o item antes de a cidade
olhar a cota. Por isso existe `SistemaCidade.pode_entregar()`, e é a resposta
dela que `game/` consulta (receita 2, §4).

## O relógio da cidade não é `dia × 1440 + minuto`

A cidade guarda o próprio relógio, copiado de `MinuteTickedEvent` e
`DayEndedEvent` — nunca lido do `TimeState`. Somar `dia × 1440 + minuto` cru
**não funciona**: o relógio do mundo vira à meia-noite, mas o `dia` só vira ao
dormir ou ao colapsar às 02:00. 00:00 daria um número menor que 23:59, e toda
encomenda da madrugada ficaria pronta cedo.

`EstadoCidade.minuto_monotonico()` soma um dia inteiro à madrugada, que pertence
à noite do dia anterior. Assim o número nunca anda para trás, dormir empurra o
ponteiro sem adiantar prazo, e uma encomenda de 4 horas conclui no meio da
tarde sem ninguém escutar a virada do dia.

## O "usar" não é ação, é pergunta

Desde a wave 11.2 o jogador tem um **item na mão** (`slot_na_mao`, no save) e
uma ação só: usar. O que ela faz depende do que está na mão — enxada ara,
regador rega, semente planta *aquela* cultura, e cultura pronta colhe seja o
que for que esteja na mão.

Não existe `UsarAction`. `game/` pergunta ao `ResolvedorUso`
(`sim/items/resolvedor_uso.gd`, exposto pela `SimFactory`) qual ação um uso
vira, e despacha o que voltar — `null` quer dizer "não há o que fazer aqui", e
nada é despachado.

O resolvedor **devolve** a ação em vez de a sim expandi-la por dentro, e isso é
consequência direta da ordem do tick: `PlantCropAction` estende
`RemoveItemAction`, então quem cobra a semente é o `InventorySystem`. Uma ação
criada dentro do `FarmSystem` já teria passado dele, e a semente sairia de
graça. Devolvendo, ela entra pela porta da frente e percorre a fila inteira.

O resolvedor não é sistema: não trata ação e não muda estado. É consulta, no
mesmo espírito de `FarmSystem.pode_plantar()`, e por isso não entra na fila.

## O slot tem endereço

Desde a wave 11.3 a mochila tem sempre `capacity` posições, e a posição vazia é
um `Slot` sem item — não um buraco na lista. Item novo empilha no que já existe
e, se não couber, ocupa a **primeira posição livre**; stack que zera **esvazia
no lugar**.

Isso não é detalhe de arrumação: a mão do jogador (`slot_na_mao`) é um
**índice**. Com a lista compacta de antes, gastar o último de um stack fazia
todo mundo à direita deslizar e a mão passava a segurar outra coisa sozinha.

`MoverSlotAction` é o arrastar. Destino vazio move; item diferente **troca**;
item igual empilha até o `stack_max` e a sobra fica na origem. A mão não segue
o item — ela continua no mesmo endereço, agora com outra coisa.

Save antigo (lista compacta, mais curta que a capacidade) carrega nas primeiras
posições, que é onde os itens estavam. Foi por isso que o endereço fixo entrou
sem migração.
