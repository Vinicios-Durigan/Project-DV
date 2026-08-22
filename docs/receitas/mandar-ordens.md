# Receita 2 — mandar ordens

**Quando usar:** sempre que um clique, uma tecla ou um encostão precisar mudar
alguma coisa no jogo.

**Arquivo de referência:** [`game/dev/farm_grid.gd`](../../game/dev/farm_grid.gd)

## A ideia em uma frase

O input não muda nada: ele monta uma `SimAction`, entrega para a bridge e
acaba ali.

## Passo a passo

### 1. Monte a ação com os dados do que aconteceu

```gdscript
func _on_canteiro_pressed(x: int, y: int) -> void:
    var regar := WaterPlotAction.new()
    regar.x = x
    regar.y = y
    _bridge.dispatch(regar)
```

### 2. Não pergunte nada antes

Nada de `if tem_agua`, `if o tile está arado`, `if dá o dinheiro`. Quem valida
é a sim, e a resposta volta como evento — inclusive a resposta "não deu", que
é um `ActionRejectedEvent`.

```gdscript
# errado: regra de jogo dentro de game/
if plot.arada and not plot.regada:
    _bridge.dispatch(regar)

# certo: manda e deixa a sim decidir
_bridge.dispatch(regar)
```

### 3. Não desenhe o resultado no clique

O botão não fica molhado porque foi clicado; ele fica molhado porque chegou um
`PlotWateredEvent`. Desenhar no clique cria dois donos da verdade — e um deles
vai mentir na hora em que a ação for rejeitada.

### 4. A exceção: quando a ação cobra antes de validar

Algumas ações **gastam** alguma coisa por serem outra ação por baixo.
`PlantCropAction` é uma `RemoveItemAction`: a semente sai da mochila antes de o
`FarmSystem` olhar o tile. Despachar num tile inválido cobraria a semente à
toa.

Nesses casos existe uma consulta pronta na sim — use a resposta dela, nunca uma
regra sua:

```gdscript
var farm := _farm_system()
if farm != null and not farm.pode_plantar(crop_id, x, y):
    return                    # a sim disse não; nada foi cobrado
_bridge.dispatch(plantar)
```

Consultas assim (`pode_arar`, `pode_plantar`, `pode_regar`, `pode_colher`)
vivem no sistema, em `sim/`. Se a que você precisa não existe, ela nasce lá —
não aqui.

### 5. O que `dispatch` devolve

Os eventos daquela ação, no mesmo frame, na ordem em que aconteceram. Dá para
usar quando a reação é local e imediata; para todo o resto, escute o sinal
(receita 3).

## Truque também é ação

"+500 moedas" no playground é um `AddMoneyAction` de verdade. Nenhum atalho
mexe no state por fora. Se o truque quebra o jogo, quem estava quebrada era a
mecânica — e é melhor descobrir por um botão de dev do que por um jogador.

## Erros comuns

| Sintoma | Causa |
| --- | --- |
| a tela mostra o que não aconteceu | desenhou no clique em vez de esperar o evento |
| item some sem motivo | despachou ação que cobra antes de validar |
| a regra existe em dois lugares | copiou o `if` da sim para dentro de `game/` |
