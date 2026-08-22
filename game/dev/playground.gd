class_name Playground
extends Control

## Casca do playground: a fazenda de botões.
##
## Aqui a sim inteira é jogável sem um pixel de arte — grid clicável, relógio,
## truques e o diário de avisos. É a implementação de referência dos três
## padrões de ligação entre `game/` e `sim/`; o jogo visual só implementa o que
## já foi jogado e aprovado aqui (CLAUDE.md, "Playground primeiro").
##
## Não entra no jogo final: `game/dev/` é ferramenta de time.
##
## ---
##
## ## Padrão 1 — receber o fio
##
## Ninguém busca a sim. A `SimBridge` (nó raiz desta cena) chama `setup(self)`
## em todo filho direto que tiver o método; este nó faz o mesmo com os próprios
## filhos, e assim o fio desce a árvore inteira sem autoload e sem
## `get_node("/root/...")`.
##
## Um nó que não recebeu a bridge não fala com a sim — e isso é de propósito:
## é o que impede um botão perdido de mexer no jogo pelas costas.
##
## Copie daqui: `docs/receitas/receber-o-fio.md`.

var _bridge: SimBridge

## O fio chega aqui pela bridge e segue para baixo. É o único ponto de entrada
## deste nó: sem `setup`, o playground é um monte de botões que não fazem nada.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_passa_o_fio(self)

func get_bridge() -> SimBridge:
	return _bridge

## Desce a árvore entregando a bridge a quem sabe recebê-la.
##
## Quem tem `setup` recebe e a recursão para ali: aquele nó é dono dos próprios
## filhos e decide se passa o fio adiante. Quem não tem é caixa de layout
## (margem, coluna, separador) e não fala com a sim — a busca continua abaixo
## dele.
func _passa_o_fio(no: Node) -> void:
	for filho in no.get_children():
		if filho.has_method("setup"):
			filho.call("setup", _bridge)
			continue
		_passa_o_fio(filho)
