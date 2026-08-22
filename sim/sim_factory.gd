class_name SimFactory
extends RefCounted

## Monta o `SimWorld` completo: catálogos de `data/`, os sistemas na ordem fixa
## e todo state registrado no save.
##
## A montagem é **regra de jogo**, por isso mora aqui e não na bridge. Duas
## coisas se decidem nesta classe e nenhuma delas pode ser decidida por um nó:
##
## - a **ordem dos sistemas** — Inventory → Shipping → Farm → Time — que
##   implementa a validação em cadeia e a sequência de dormir do GAMEPLAY §3;
## - as **chaves dos states**, que são o formato do arquivo de save.
##
## `game/` pede um mundo pronto e não sabe de nenhuma das duas.
##
## Pura: monta tudo sem janela e sem árvore de cena. Um `build()` por partida —
## dois saves abertos nunca compartilham state.

## Chaves dos blocos do save. A ordem é a ordem em que saem no arquivo.
const CHAVE_TIME: String = "time"
const CHAVE_INVENTORY: String = "inventory"
const CHAVE_FARM: String = "farm"
const CHAVE_SHIPPING: String = "shipping"

## Enquanto não existe co-op, o jogador é sempre o 0 — mas o id existe desde já.
const PLAYER_PADRAO: int = 0

## O que o jogador tem na mochila ao começar do zero (GAMEPLAY §5): o dinheiro
## vem do default do state; a semente é conteúdo, então sai do catálogo.
const CULTURA_INICIAL: String = "rabanete"
const SEMENTES_INICIAIS: int = 5

var _items: ItemCatalog
var _crops: CropCatalog
var _time: TimeState
var _inventory: InventoryState
var _farm: FarmState
var _shipping: ShippingState

## Os diretórios são injetáveis para o teste não depender do conteúdo do jogo.
func _init(dir_itens: String = ItemCatalog.DIR_PADRAO,
		dir_culturas: String = CropCatalog.DIR_PADRAO) -> void:
	_items = ItemCatalog.new()
	_items.load_from_dir(dir_itens)
	_crops = CropCatalog.new()
	_crops.load_from_dir(dir_culturas)

func get_item_catalog() -> ItemCatalog:
	return _items

func get_crop_catalog() -> CropCatalog:
	return _crops

func get_time_state() -> TimeState:
	return _time

func get_inventory_state() -> InventoryState:
	return _inventory

func get_farm_state() -> FarmState:
	return _farm

func get_shipping_state() -> ShippingState:
	return _shipping

## O mundo pronto para jogar: sistemas na ordem fixa, states no save e a mochila
## do primeiro dia. Quem vai carregar um save chama `restore()` logo depois — o
## restore substitui todo bloco registrado, inclusive o da partida nova.
func build() -> SimWorld:
	_time = TimeState.new()
	_inventory = InventoryState.new()
	_farm = FarmState.new()
	_shipping = ShippingState.new()

	var world := SimWorld.new()
	# A ordem é regra de jogo: validar → vender → crescer → virar o dia.
	world.register_system(InventorySystem.new(_inventory, _items, _crops))
	world.register_system(ShippingSystem.new(_shipping, _items))
	world.register_system(FarmSystem.new(_farm, _crops))
	world.register_system(TimeSystem.new(_time))

	# A ordem de registro é a ordem dos blocos no arquivo de save.
	world.register_state(CHAVE_TIME, _time)
	world.register_state(CHAVE_INVENTORY, _inventory)
	world.register_state(CHAVE_FARM, _farm)
	world.register_state(CHAVE_SHIPPING, _shipping)

	_entrega_inicial(world)
	return world

## As sementes do primeiro dia entram pelo mesmo caminho de qualquer item: uma
## ação. Os eventos morrem aqui de propósito — ainda não existe partida para
## eles contarem nada.
func _entrega_inicial(world: SimWorld) -> void:
	var def := _crops.get_def(CULTURA_INICIAL)
	if def == null:
		return
	var action := AddItemAction.new()
	action.player_id = PLAYER_PADRAO
	action.item_id = def.item_semente_id()
	action.qtd = SEMENTES_INICIAIS
	world.handle(action)
