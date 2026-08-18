# Modelo de dados da simulação

**Estado** — cada sistema é dono de um `SimState` próprio (campos explícitos, todos com default). `SimWorld` agrega os states; o save é o snapshot deles. Nenhum sistema lê o state de outro: pede por ação ou reage a evento.

**Ação** — intenção que entra, no imperativo: `WaterPlotAction`, `SellItemAction`. Só dados, sem método.

**Evento** — fato consumado que sai, no particípio: `PlotWateredEvent`, `ItemSoldEvent`. Campos `from`/`to` quando descreve transição.

**Tick central** — `SimWorld` percorre `_systems` em **ordem fixa** (a ordem é regra de jogo) e concatena os eventos, na sequência em que aconteceram — `game/` depende disso para animar certo. Ação é oferecida a todos por `handle()` (mesmo laço do `advance`); quem não reconhece devolve `[]`.

```gdscript
func advance(ticks: int) -> Array[SimEvent]:            # sim/sim_world.gd
    var events: Array[SimEvent] = []
    for _i in ticks:
        for system in _systems:
            events.append_array(system.tick())
    return events

func handle(action: SimAction) -> Array[SimEvent]:      # sim/farming/farm_system.gd
    if not action is WaterPlotAction:
        return []
    var plot := _state.plots[action.plot_id]
    if plot.watered:
        return []                      # sem mudança, sem evento
    plot.watered = true
    var e := PlotWateredEvent.new()
    e.plot_id = action.plot_id
    return [e]
```

# Nascimento de um módulo — regras de extensão

**Mecânica nova = arquivo novo** — sistema entra registrando no tick do `SimWorld`, nunca editando sistema existente. Se a feature exige mexer em outro sistema, o design falhou: o dado que faltava devia chegar por evento.

**Evento gordo, sistema magro** — todo evento carrega contexto completo (`player_id`, ids, causa, `from`/`to`), mesmo sem consumidor hoje. Ex.: `DayEndedEvent.cause = SLEPT | COLLAPSED` — hoje ninguém trata `COLLAPSED`; amanhã fadiga/morte/hospital escutam a causa que sempre existiu, sem refatorar nada.

**Conteúdo é id + catálogo** — sistema não conhece tipo concreto de conteúdo. Item = `item_id: String` + quantidade; cultura, peixe e minério são definições em `data/`, não classes. Adicionar conteúdo = criar `.tres`, zero código novo.

**Definição `.tres` com default** — campo novo numa definição sempre tem default que preserva o comportamento antigo (ex.: `bloqueia_movimento := false`). `.tres` existente continua válido sem edição.

**Save versionado** — todo campo de state tem default; snapshot carrega `save_version`. Campo novo entra sem migração; remover ou renomear campo exige uma.

**`player_id` em toda ação** — hoje sempre `0`, sem singleton "o jogador". É o que deixa co-op futuro ser problema de rede, não de refatoração.

# Comunicação entre sistemas (definido na wave 02)

**react()** — evento emitido entra numa fila do `SimWorld` e é oferecido a todos os sistemas via `react(event)` na ordem fixa, antes de sair para `game/`; reações geram eventos que voltam à fila (processa até esvaziar — determinístico). É assim que um sistema "reage a evento" de outro.

**Validação em cadeia** — ação tem campo `rejeitada: bool`. O sistema que detecta impossibilidade (sem semente, sem dinheiro) marca a flag e emite `ActionRejectedEvent`; sistemas seguintes ignoram ação rejeitada. Ninguém desfaz nada: quem valida vem antes de quem executa.

**Ordem de handle: Inventory → Shipping → Farm → Time.** A ordem é regra de jogo — ela implementa a validação em cadeia e a sequência de dormir (vender → crescer → virar o dia). Sistema novo entra na posição que sua regra exige, documentando o porquê.

**Definições são leitura livre** — catálogos (`data/*.tres`) qualquer sistema lê; o que é proibido é ler *state* alheio.
