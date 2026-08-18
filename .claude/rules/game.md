---
paths:
  - "game/**/*"
---

# Regras — game/ (camada de apresentação)

`game/` é a casca. Traduz input em ação, manda para `sim/`, escuta eventos de
`sim/` e reage visualmente. Nada além disso.

## Proibido: regra de jogo

Nenhum cálculo de crescimento, preço, dano, XP, progressão, loot, energia ou
qualquer outro número que defina o jogo. Se envolve balanceamento ou regra,
mora em `sim/`.

Sinal de alerta: fórmula, tabela de valores, `if` sobre estágio/nível/custo
dentro de `game/`. Isso é regra vazada — mova para `sim/`.

```gdscript
# ERRADO — game/ decidindo regra
if plot.growth + 1 >= MAX_STAGE:
    plot.growth = MAX_STAGE

# CERTO — game/ manda a intenção
sim.dispatch(WaterPlotAction.new(plot_id))
```

## Fluxo de mão única

1. Input → uma **ação** tipada enviada para `sim/`.
2. `sim/` processa e emite eventos.
3. `game/` escuta os eventos e atualiza visual, áudio, UI.

`game/` nunca lê nem escreve estado de `sim/` direto. Só ação para dentro,
evento para fora.

## delta

`delta` do frame serve para animação, tween, interpolação, partícula, câmera.
Nunca para lógica de jogo — nada de acumular `delta` para "passar o tempo",
avançar produção, recarregar recurso ou disparar timer de regra.

```gdscript
func _process(delta: float) -> void:
    sprite.position = sprite.position.lerp(target, delta * 8.0)  # ok
    # crop.growth += delta  <- nunca
```

O tempo de jogo é tick da simulação.
