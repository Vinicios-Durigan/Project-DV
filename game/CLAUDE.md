# Convenção de cenas

**Referência da sim** — `SimBridge` (nó em `game/main.tscn`) é o único dono do `SimWorld`. Ele avança o tick e reemite cada evento como sinal Godot. Nós filhos **recebem** a referência por injeção — `setup(bridge: SimBridge)` chamado pelo pai ao instanciar. Nunca busque a bridge por `get_node("/root/...")` nem por autoload: quem não recebeu a bridge não deveria falar com a sim.

**Escutar eventos** — conecte no `_ready`, filtre por tipo, ignore o resto em silêncio. Um nó reage só ao que é dele.

**Input vira ação** — o nó não decide nada, só traduz. Nenhum `if` sobre estado da sim antes de despachar: quem valida é a sim, e a resposta chega como evento (ou como ausência dele).

```gdscript
extends Node2D

var _bridge: SimBridge
var _plot_id: int

func setup(bridge: SimBridge, plot_id: int) -> void:
    _bridge = bridge
    _plot_id = plot_id
    _bridge.sim_event.connect(_on_sim_event)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("regar"):
        _bridge.dispatch(WaterPlotAction.new(_plot_id))   # traduz e manda

func _on_sim_event(e: SimEvent) -> void:
    if e is PlotWateredEvent and e.plot_id == _plot_id:
        _tocar_animacao_de_rega()
```

Fluxo completo: input → ação → sim → evento → visual. Se você precisou ler estado da sim para decidir o que mostrar, o dado que faltava devia ter vindo dentro do evento.

# Regras de extensão

**Interagível único** — caixote, cama, futuro lago: todos cumprem o mesmo contrato — "interagir" despacha a ação do seu conteúdo. Um sistema de interação, N conteúdos; nenhum `if` por tipo no código de input.

**Input não conhece ferramentas** — o nó de input lê o `ToolDef` (`.tres`) equipado e despacha a ação que ele declara. Ferramenta nova (vara de pesca) = um `.tres` novo + um sistema novo em `sim/`; o código de input não muda.
