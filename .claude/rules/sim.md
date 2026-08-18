---
paths:
  - "sim/**/*"
---

# Regras — sim/ (núcleo de simulação)

`sim/` é lógica pura. Não conhece a engine, não conhece a tela.

## Proibido

- Importar, estender ou referenciar qualquer tipo de engine: `Node`, `Node2D`,
  `Sprite2D`, `SceneTree`, `Resource` de cena, etc.
- `get_node()`, `$Atalho`, `preload()`/`load()` de cenas (`.tscn`), `add_child()`,
  `queue_free()`, `_process()`, `_physics_process()`, `_ready()`.
- Sinais de nós. Comunicação sai por eventos tipados, não por `Node.signal`.

Se precisar de algo do mundo externo, receba por parâmetro ou injeção — nunca busque.

## Estado e eventos

Toda mudança de estado emite um evento tipado (uma classe/struct de evento com
campos explícitos, não `Dictionary` solto).

```gdscript
class_name CropGrewEvent
extends SimEvent

var plot_id: int
var stage_from: int
var stage_to: int
```

Mudou estado sem emitir evento = bug. `game/` só sabe do mundo por esses eventos.

## Tipagem

Toda função pública tem tipo em **todos** os parâmetros e no retorno.

```gdscript
func advance_growth(plot_id: int, ticks: int) -> Array[SimEvent]:
func get_price(item_id: StringName) -> int:
func _internal_helper(x):  # privada, tipagem recomendada mas não obrigatória
```

Sem retorno útil → `-> void`. Nunca deixe o retorno implícito em função pública.

## Testes

Sistema novo em `sim/` nasce com teste em `tests/` **na mesma tarefa**. Não é
etapa seguinte, não é backlog. Sem teste, o sistema não está pronto.

Espelhe a estrutura: `sim/economy/pricing.gd` → `tests/economy/test_pricing.gd`.

## Determinismo

A simulação roda igual duas vezes com a mesma entrada.

- Nada de `randi()`, `randf()`, `randi_range()` globais. Use uma
  `RandomNumberGenerator` própria com `seed` explícita, vinda do estado da sim.
- Nada de `Time.get_ticks_msec()`, `Time.get_unix_time_from_system()` ou
  `OS.get_time()` para lógica. O tempo da simulação é o contador de ticks dela.
- Nada de `delta` de frame. `sim/` avança por tick, não por tempo real.
- Cuidado com ordem de iteração: `Dictionary` preserva inserção, mas não
  itere sobre coleções cuja ordem depende de endereço/instância.
