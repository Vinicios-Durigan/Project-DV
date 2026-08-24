class_name Estabelecimento
extends Node2D

## Um prédio da cidade na tela. Não decide nada de jogo: pergunta à sim, despacha
## a ação e apresenta o que voltar por evento.
##
## Moinho, padaria e ferreiro são **a mesma cena** com `id_estabelecimento` e
## `textura` diferentes — conteúdo é id, não classe.

## Qual estabelecimento este nó é. Casa com o `id` do `.tres` em `data/cidade/`.
@export var id_estabelecimento: String = ""

## A arte deste prédio. Exposta aqui, e não no `Sprite2D` filho, porque o Godot
## esconde os filhos de uma cena instanciada: sem este campo, trocar o sprite da
## padaria exigiria ligar *Editable Children* e a cena-molde pararia de se
## propagar para as instâncias.
@export var textura: Texture2D

## O aviso em cima do prédio — "tem coisa pronta para buscar".
@export var textura_selo: Texture2D

@onready var _arte: Sprite2D = $Arte
@onready var _selo: Sprite2D = $Selo
@onready var _area: Area2D = $AreaInteracao

var _bridge: SimBridge = null
var _jogador_perto: bool = false


## A bridge chega por injeção — quem chama é o pai. A `SimBridge` só injeta nos
## filhos diretos dela, então a cena do mundo precisa repassar.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_ao_evento)


func _ready() -> void:
	if textura != null:
		_arte.texture = textura
	if textura_selo != null:
		_selo.texture = textura_selo
	_ancora_no_pe()

	_selo.visible = false
	_area.body_entered.connect(_entrou)
	_area.body_exited.connect(_saiu)


func _unhandled_input(evento: InputEvent) -> void:
	if not _jogador_perto or _bridge == null:
		return
	if not evento.is_action_pressed("interagir"):
		return
	get_viewport().set_input_as_handled()
	_abre_painel()


## Só apresentação: o selo acende quando a encomenda **deste** prédio fica
## pronta e apaga quando o jogador busca. Quem decide quando é a `SistemaCidade`.
func _ao_evento(evento: SimEvent) -> void:
	if evento is BeneficiamentoProntoEvent \
			and evento.estabelecimento == id_estabelecimento:
		_selo.visible = true
	elif evento is RetiradaFeitaEvent \
			and evento.estabelecimento == id_estabelecimento:
		_selo.visible = false


## O pé do prédio no (0,0) do nó, seja qual for o tamanho da arte. Dispensa
## digitar offset na mão a cada prédio novo — e garante que todos encostem no
## chão na mesma linha.
func _ancora_no_pe() -> void:
	if _arte.texture == null:
		return
	_arte.centered = false
	_arte.offset = Vector2(
		-_arte.texture.get_width() / 2.0,
		-_arte.texture.get_height())


func _entrou(_corpo: Node2D) -> void:
	_jogador_perto = true


func _saiu(_corpo: Node2D) -> void:
	_jogador_perto = false


## Aqui entra a UI de verdade, na wave de `game/`. Ela vai perguntar à sim o que
## pode ser feito (`SistemaCidade.pode_entregar()`) e despachar pela bridge —
## nenhum `if` de regra passa por este arquivo.
func _abre_painel() -> void:
	print("abriu ", id_estabelecimento)
