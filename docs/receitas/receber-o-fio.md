# Receita 1 — receber o fio

**Quando usar:** sempre que um nó novo precisar falar com a simulação.

**Arquivo de referência:** [`game/dev/playground.gd`](../../game/dev/playground.gd)

## A ideia em uma frase

Ninguém procura a sim: a sim chega até o nó, entregue por quem está acima dele
na cena.

## Passo a passo

### 1. Declare o método `setup`

O nó recebe a `SimBridge` e guarda. É o único jeito de entrar.

```gdscript
extends Node2D

var _bridge: SimBridge

func setup(bridge: SimBridge) -> void:
    _bridge = bridge
```

### 2. Pendure o nó na árvore abaixo da bridge

A `SimBridge` é o nó raiz da cena. No `_ready` dela, todo **filho direto** que
tiver `setup` recebe a bridge.

```
Playground (SimBridge)
├── SaveGateway        ← tem setup, recebe
└── UI                 ← tem setup, recebe
```

### 3. Passe o fio adiante, se você tem filhos

Um nó que recebeu a bridge é responsável por entregá-la aos próprios filhos. É
o que `playground.gd` faz:

```gdscript
func _passa_o_fio(no: Node) -> void:
    for filho in no.get_children():
        if filho.has_method("setup"):
            filho.call("setup", _bridge)
            continue          # dali para baixo o problema é dele
        _passa_o_fio(filho)   # caixa de layout: a busca continua
```

### 4. Use a bridge só depois do `setup`

No `_ready` a bridge ainda não chegou — o `_ready` do filho roda **antes** do
`_ready` do pai. Monte o layout no `_ready`; converse com a sim no `setup`.

```gdscript
func _ready() -> void:
    _monta_os_botoes()        # não precisa da sim

func setup(bridge: SimBridge) -> void:
    _bridge = bridge
    _bridge.sim_event.connect(_on_sim_event)
    _atualiza()               # aqui já dá para ler o snapshot
```

## Por que não um autoload

Um autoload deixaria qualquer script do projeto mexer no jogo de qualquer
lugar. Com o fio descendo pela árvore, quem pode falar com a sim é visível na
cena: quem não recebeu, não fala. Um botão perdido não muda o mundo por acaso.

## Erros comuns

| Sintoma | Causa |
| --- | --- |
| `Nil` ao usar `_bridge` | usou a bridge no `_ready` em vez do `setup` |
| o nó nunca recebe o fio | não é descendente da bridge, ou o pai não repassa |
| dois mundos ao mesmo tempo | alguém criou um `SimWorld` fora da bridge |
