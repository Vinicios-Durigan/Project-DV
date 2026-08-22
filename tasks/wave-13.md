---
wave: 13
titulo: Contrato — o dono encomenda, e aceitar é apostar
paralelo: nao
depende_de: [12, 12.1]
---

## Objetivo

Subir o segundo degrau da escada (PRINCIPIOS §3). O caixote é preguiça e o
beneficiamento é esteira: entrega, espera, busca, e nada pode dar errado. O
contrato é a primeira mecânica da cidade com uma decisão que o jogador pode
perder — o dono pede uma quantidade até um dia, e aceitar é apostar na colheita
que ainda não veio.

## Decisões

- **O contrato é cumprido no prédio, nunca no caixote.** Entrega direta é o que
  o degrau 2 destrava; cumprir jogando no caixote sairia de graça em relógio e
  mataria a ficção do dono que te conhece.
- **O dono pede o `item_entrada` dele.** Moinho pede trigo, padaria pede
  farinha — então o contrato da padaria obriga a passar pelo moinho e esperar.
  A cadeia da cidade vira pré-requisito, não enfeite.
- **Recusar é grátis; falhar o prazo custa.** Não responder até o fim do dia
  seguinte é recusa silenciosa, sem custo. Aceitar e estourar tira **2 dias**
  de constância, com piso em zero. Preserva PRINCIPIOS §6 — ausência não pune,
  igual à planta não regada — e ainda deixa a aposta doer.
- **Cumprir credita 3 dias de constância de uma vez.** É o que faz o contrato
  ser degrau e não só uma venda melhor: é o caminho rápido de contrato para
  dono, porque é a cota batendo na capacidade que destrava a compra (§4).
- **Sorteio determinístico.** A semente do RNG mora no `EstadoContratos` e entra
  no save. Mesmo save, mesma sequência de ofertas — replay e bug report
  continuam confiáveis. (Herdado da wave 09.)
- **Dia 1 não tem oferta.** A primeira chega na manhã do dia 2, junto com a
  cascata da virada — evita caso especial de boot. (Herdado da wave 09.)
- **O sistema que pede não lê o state de quem vende.** O `SistemaContratos`
  escuta `RelacaoSubiuEvent` — que já carrega `dias` e `cota` — e guarda o
  degrau no próprio state. Nunca toca no `EstadoCidade`. (Regra da wave 02,
  herdada da 09.)
- **Um contrato ativo por estabelecimento.** Oferta nova só sai onde não há
  contrato em pé. O atrito vem do prazo e do relógio, não de fila.
- **Degrau mínimo 1 para receber oferta.** Você precisa ter sido constante antes
  de o dono confiar um pedido. A escada não pula degrau.
- **Descartado: `ItemsSoldEvent.Linha` ganha `multiplicador`.** A decisão vinha
  da wave 09, quando o pedido era do caixote anônimo. O caixote saiu da jogada
  em 2026-08-21 e o contrato paga na hora, no prédio — o campo nasceria morto
  no evento da venda ao dormir.
- **Descartado: contrato pagar em capacidade do prédio.** Capacidade só muda
  comprando e melhorando, com insumo cruzado (PRINCIPIOS §5).
- **Números iniciais moram no `.tres`:** prazo 3 dias, 1–2 lotes do
  `item_entrada`, multiplicador 1.5×, degrau mínimo 1. Balanceamento é campo de
  `DefEstabelecimento`, não constante de código.

## Impacto

- **Eventos novos:** `ContratoOferecidoEvent`, `ContratoAceitoEvent`,
  `ContratoCumpridoEvent`, `ContratoFalhouEvent`, `DinheiroConcedidoEvent`.
- **Ações novas:** `ResponderContratoAction`, `CumprirContratoAction` (é uma
  `RemoveItemAction` — o inventário tira o item, ou recusa por
  `item_insuficiente`, mesmo desenho da `EntregarAction` da wave 12).
- **Sistema novo:** `SistemaContratos`, registrado no tick **depois** da Cidade
  e antes do Time. A cascata de eventos já volta para sistemas anteriores — é
  assim que o `InventorySystem` recebe o `ItemGrantedEvent` do `FarmSystem` —
  então nada na ordem precisa inverter.
- **Arquivos existentes tocados: três, um `if` cada.**
  `inventory_system.gd` (`react` aceita `DinheiroConcedidoEvent`, o irmão do
  `ItemGrantedEvent`), `sistema_cidade.gd` (`react` a cumprido/falhou) e
  `estado_cidade.gd` (débito de dias — hoje a constância só sobe).
- **Muda formato de save:** sim, campo novo com default (`contratos`), sem
  migração. `DefEstabelecimento` ganha campos com default — `.tres` antigo
  carrega.
- **Arte necessária:** nenhuma.
- **Playground:** aba de contratos no Tab, com contagem regressiva do prazo e
  selo no prédio do mapa — a mesma exigência travada na wave 12.1.

## Tarefas

### 13.1 — EstadoContratos
Cria: `sim/cidade/estado_contratos.gd`, `tests/test_estado_contratos.gd`
Faz: o contrato como dado — estabelecimento, item, qtd, pagamento, minuto de
oferta, minuto de vencimento, situação (oferecido/aceito/cumprido/falho) — mais
o degrau conhecido por estabelecimento e a semente do RNG. `to_dict`/`from_dict`
com default em todo campo. Sem lógica de sorteio e sem relógio próprio: o
vencimento é minuto monotônico, calculado por quem sorteia.

### 13.2 — SistemaContratos
Cria: `sim/cidade/sistema_contratos.gd`, `tests/test_sistema_contratos.gd`
Depende de: 13.1
Faz: reage a `RelacaoSubiuEvent` guardando o degrau; reage a `DayEndedEvent`
sorteando oferta onde couber (degrau ≥ 1, sem contrato ativo, nunca no dia 1) e
expirando oferta não respondida; reage a `MinuteTickedEvent` para vencer prazo
aceito e emitir `ContratoFalhouEvent`; trata `ResponderContratoAction` e
`CumprirContratoAction`. Consultas para `game/`: `pode_cumprir()` e
`minutos_para_vencer()`. Registra no tick em `sim/sim_factory.gd`, depois da
Cidade.

### 13.3 — O canal de pagamento
Cria: `sim/items/dinheiro_concedido_event.gd`, `tests/test_dinheiro_concedido.gd`
Depende de: 13.2
Faz: o evento que concede dinheiro sem ação, irmão do `ItemGrantedEvent`, e o
caso novo no `react` do `InventorySystem`. Qualquer mecânica futura que premie
em dinheiro — pescaria, festival — passa por aqui em vez de inventar o próprio
caminho.

### 13.4 — Constância acelerada
Cria: `tests/test_constancia_contrato.gd` (edita `sim/cidade/estado_cidade.gd` e
`sim/cidade/sistema_cidade.gd`)
Depende de: 13.2
Faz: `EstadoCidade` ganha débito de dias com piso em zero; `SistemaCidade` reage
a `ContratoCumpridoEvent` creditando 3 dias e a `ContratoFalhouEvent` tirando 2,
emitindo `RelacaoSubiuEvent` com a cota nova quando o degrau muda. O crédito
respeita a regra do dia único: contrato cumprido no mesmo dia de uma entrega não
conta duas vezes pelo mesmo dia.

### 13.5 — A aba de contratos no playground
Cria: `game/dev/painel_contratos.gd`
Depende de: 13.2, 13.4
Faz: aba própria no Tab, ao lado da mochila e da cidade — oferta com aceitar e
recusar, contrato aceito com contagem regressiva viva, e o resultado (cumprido
ou falho) na cara. Selo no prédio do mapa quando há oferta esperando resposta.
Reusa os rótulos em vez de recriar nós a cada evento — o sintoma da receita 3 §4
já custou uma pendência na 12.1.

## Em aberto

- **Quantos dias de constância um contrato deve valer.** 3 para cumprir e 2 para
  falhar são chute calibrado pela escada, não medida — a resposta vem de jogar
  com os dois estabelecimentos e ver quanto tempo leva para a cota bater na
  capacidade.
- **O que acontece com um contrato aceito na virada da estação.** Dia 28 mata a
  cultura no chão; um prazo que atravessa a virada pode ficar impossível de
  cumprir por motivo que não é decisão do jogador. Decidir se o sorteio encurta
  o prazo perto do fim da estação.
- **Contrato do ferreiro.** Ele não tem `item_entrada` que vira item de
  inventário — a saída dele é upgrade de ferramenta. O que ele encomenda fica
  para a wave dele.
- **Co-op:** `EstadoContratos` não é indexado por jogador, mesma escolha do
  caixote e do `EstadoCidade`. Dois jogadores veriam a mesma oferta. Decidir
  junto com a wave de co-op.
