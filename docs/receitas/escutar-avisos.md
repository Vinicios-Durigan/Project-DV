# Receita 3 — escutar avisos

**Quando usar:** sempre que a tela precisar mudar porque alguma coisa aconteceu
no jogo.

**Arquivo de referência:** [`game/dev/event_feed.gd`](../../game/dev/event_feed.gd)

## A ideia em uma frase

A sim avisa; o nó reage. Ninguém fica perguntando de tempos em tempos se algo
mudou.

## Passo a passo

### 1. Conecte no sinal, uma vez, no `setup`

```gdscript
func setup(bridge: SimBridge) -> void:
    _bridge = bridge
    _bridge.sim_event.connect(_on_sim_event)
```

Todo evento da sim sai por esse sinal — os de `advance` (o tempo passando) e os
de `dispatch` (alguém agiu) pelo mesmo cano, na ordem em que aconteceram.

### 2. Filtre o tipo que é seu e ignore o resto em silêncio

```gdscript
func _on_sim_event(event: SimEvent) -> void:
    if not event is PlotWateredEvent:
        return
    var regado := event as PlotWateredEvent
    if regado.plot_id == _meu_plot:
        _toca_animacao_de_rega()
```

Sem `else`, sem log de "evento desconhecido". Um nó reage só ao que é dele.

### 3. Use o que veio dentro do evento

O evento é gordo de propósito: ids, x, y, de/para, causa, totais. Se você
precisou consultar state para desenhar, **o dado que faltava devia ter vindo no
evento** — o conserto é em `sim/`, engordando o evento, não em `game/`.

```gdscript
# errado: foi buscar o que faltava
var dinheiro := _bridge.get_world().get_state("inventory").get_player(0).dinheiro

# certo: já veio
func _on_sim_event(event: SimEvent) -> void:
    if event is MoneyChangedEvent:
        _label.text = "%d moedas" % (event as MoneyChangedEvent).para
```

### 4. Cuide do tique do relógio

`MinuteTickedEvent` sai uma vez por minuto de jogo — em ×60 são 60 por segundo.
Trate-o à parte e barato; redesenhar o painel inteiro nele engasga a tela.

```gdscript
func _on_sim_event(event: SimEvent) -> void:
    if event is MinuteTickedEvent:
        var tick := event as MinuteTickedEvent
        _mostra_relogio(tick.dia, tick.minuto)     # só o relógio
        return
    _atualiza()                                    # o resto é raro
```

### 5. Para mostrar o estado inteiro, use o `snapshot()`

Evento serve para reagir a uma mudança; painel que mostra a situação toda lê
`_bridge.get_world().snapshot()` — o mesmo dicionário que vai para o arquivo de
save. É por isso que os painéis do playground funcionam como inspetor de save
de graça: campo que não aparece ali é campo que não está sendo salvo.

Nunca leia o state vivo (`get_state(...)` e os objetos de dentro) para
desenhar: é o caminho curto que vira dependência de estrutura interna da sim.

## A ordem dos eventos é contrato

Causa antes de consequência, sempre: `CropHarvestedEvent` chega antes do
`ItemAddedEvent` que ele provocou; ao dormir, a venda do caixote chega antes da
virada do dia, e o crescimento das plantas vem logo depois dela — é reação ao
`DayEndedEvent`. Animação pode confiar nisso.

## Erros comuns

| Sintoma | Causa |
| --- | --- |
| a tela pisca ou trava em ×60 | redesenhou tudo no `MinuteTickedEvent` |
| conectou duas vezes, tudo dobrado | `connect` no `_ready` **e** no `setup` |
| o nó lê state para desenhar | o evento estava magro — engorde o evento em `sim/` |
