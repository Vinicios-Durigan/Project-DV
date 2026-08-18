---
name: novo-sistema-sim
description: Procedimento para criar um sistema novo em sim/ — define o estado, as ações aceitas, os eventos emitidos, escreve o teste primeiro, implementa e registra o sistema no tick central. Use quando pedirem uma mecânica ou sistema novo de simulação (economia, clima, energia, inventário, fome, reputação, produção) ou quando pedirem para mover regra de jogo de game/ para sim/.
when_to_use: Dispare em "cria um sistema de X", "quero mecânica de clima", "adiciona economia", "isso devia estar em sim/". Não dispare para adicionar cultura (use nova-cultura), para trabalho visual/UI em game/, nem para ajustar sistema que já existe sem mudar seu contrato.
---

# Criar um sistema novo em `sim/`

Ordem obrigatória. Não pule para a implementação — o teste vem antes.

Antes de tudo, releia o contrato em `.claude/rules/sim.md`: zero engine, tudo tipado, tudo determinístico, evento para cada mudança de estado.

## 1. Estado

Uma classe de estado, campos explícitos, todos com default válido. Sem `Dictionary` solto, sem estado escondido em variável estática.

```gdscript
class_name WeatherState
extends SimState

var current: int = Weather.CLEAR
var ticks_until_change: int = 0
```

Pergunte-se: **isso entra no save?** Se sim, `/revisar-save` vale a partir de agora — todo campo precisa de default e a versão do save sobe.

## 2. Ações que ele aceita

Uma classe por ação, com os dados que a ação carrega. Ação é intenção vinda de fora (de `game/`), não resultado.

## 3. Eventos que ele emite

Uma classe por evento. Toda mudança de estado emite um. Evento é passado, ação é futuro — nomeie assim: `WaterPlotAction` / `PlotWateredEvent`.

## 4. Teste primeiro

Crie `tests/<area>/test_<sistema>.gd` **antes** do sistema existir. Ele deve falhar por ausência do sistema, não por erro de sintaxe.

Cubra: estado inicial; cada ação aceita produzindo o evento certo; ação inválida sendo rejeitada sem alterar estado; determinismo (mesma seed + mesma sequência = mesmo estado final).

## 5. Implementar

Só agora. Interface mínima que todo sistema segue:

```gdscript
class_name WeatherSystem
extends SimSystem

var _state := WeatherState.new()
var _rng: RandomNumberGenerator          # nunca randi() global

func _init(seed_value: int) -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = seed_value               # seed explícita = determinismo

func handle(action: SimAction) -> Array[SimEvent]:
    if action is ForceWeatherAction:
        return _set_weather(action.weather)
    return []

func tick() -> Array[SimEvent]:
    _state.ticks_until_change -= 1
    if _state.ticks_until_change > 0:
        return []
    return _set_weather(_rng.randi_range(0, Weather.SIZE - 1))

func _set_weather(next: int) -> Array[SimEvent]:
    var previous := _state.current
    if previous == next:
        return []
    _state.current = next
    _state.ticks_until_change = TICKS_PER_WEATHER
    var event := WeatherChangedEvent.new()   # mudou estado -> emite evento
    event.from = previous
    event.to = next
    return [event]
```

O padrão em uma linha: **ação entra → estado muda → evento sai.** Nunca mude estado sem devolver evento; nunca devolva evento sem ter mudado estado.

## 6. Registrar no tick central

Um sistema que ninguém chama não existe. Ache o orquestrador e registre:

```
grep -rn "class_name SimWorld\|func tick\|_systems" sim/ --include=*.gd
```

```gdscript
# sim/sim_world.gd
func _init(seed_value: int) -> void:
    _systems = [
        GrowthSystem.new(seed_value),
        EconomySystem.new(seed_value),
        WeatherSystem.new(seed_value),   # <- novo, ordem importa
    ]

func advance(ticks: int) -> Array[SimEvent]:
    var events: Array[SimEvent] = []
    for _i in ticks:
        for system in _systems:
            events.append_array(system.tick())
    return events
```

**A ordem da lista é regra de jogo.** Se clima afeta crescimento, clima roda antes. Diga explicitamente por que escolheu a posição.

## 7. Rodar e reportar

Rode a suíte GUT completa — sistema novo costuma quebrar teste antigo pela ordem do tick. Reporte: arquivos criados, ações e eventos definidos (por nome), onde entrou no tick e por quê, resultado da suíte.

Se o sistema tocou estado persistido, rode `/revisar-save` antes de commitar.
