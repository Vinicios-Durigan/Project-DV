class_name SimFactory
extends RefCounted

## Monta o `SimWorld` completo: catálogos de `data/`, os sistemas na ordem fixa
## e todo state registrado no save.
##
## A montagem é **regra de jogo**, por isso mora aqui e não na bridge. Duas
## coisas se decidem nesta classe e nenhuma delas pode ser decidida por um nó:
##
## - a **ordem dos sistemas** — Locais → Terreno → Inventory → Shipping → Farm →
##   Corpo → Cidade → Contratos → Time — que implementa a validação em cadeia e
##   a sequência de dormir do GAMEPLAY §3. O Locais vem primeiro porque o
##   carimbo de "fora do lugar" tem que existir antes de o Inventory cobrar
##   qualquer coisa; a Cidade vem depois do Farm, para a colheita da manhã já
##   estar na mochila quando ela age, e antes do Time, que é quem fecha o dia;
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
## Bloco novo entra no FIM do arquivo — save antigo carrega sem migração.
const CHAVE_LOCAIS: String = "locais"
const CHAVE_CIDADE: String = "cidade"
const CHAVE_CONTRATOS: String = "contratos"
const CHAVE_TERRENO: String = "terreno"
const CHAVE_CORPO: String = "corpo"
const CHAVE_OFICIOS: String = "oficios"

## Enquanto não existe co-op, o jogador é sempre o 0 — mas o id existe desde já.
const PLAYER_PADRAO: int = 0

## O que o jogador tem na mochila ao começar do zero (GAMEPLAY §5): o dinheiro
## vem do default do state; a semente é conteúdo, então sai do catálogo.
const CULTURA_INICIAL: String = "rabanete"
const SEMENTES_INICIAIS: int = 5

## As ferramentas do primeiro dia. Elas são itens e ocupam slot (§4) — o custo
## é de propósito: capacidade é o que vai fazer a cota da cidade doer.
##
## A ordem importa uma vez só: são os dois primeiros slots da mochila, e a
## hotbar do playground é a mochila. Enxada na tecla 1, regador na 2 é o
## arranjo com que se começa a jogar — quem quiser trocar, arrasta.
##
## Machado e picareta entram na wave 14, e não são conveniência: a fazenda nasce
## com entulho, e sem eles metade do chão fica inalcançável para sempre. O custo
## de slot vai junto — quatro ferramentas na mochila é metade da hotbar
## ocupada, e é de propósito.
const FERRAMENTAS_INICIAIS: Array[String] = ["enxada", "regador", "machado", "picareta"]

var _items: ItemCatalog
var _crops: CropCatalog
var _time: TimeState
var _inventory: InventoryState
var _farm: FarmState
var _shipping: ShippingState
var _locais: EstadoLocais
var _cidade: EstadoCidade
var _contratos: EstadoContratos
var _terreno: EstadoTerreno
var _corpo: EstadoCorpo
var _oficios: EstadoOficios
var _resolvedor: ResolvedorUso

## As definições dos estabelecimentos são carregadas pelo próprio
## `SistemaCidade`, no `build()` — por isso só o caminho é guardado aqui.
var _dir_estabelecimentos: String

## Os diretórios são injetáveis para o teste não depender do conteúdo do jogo.
func _init(dir_itens: String = ItemCatalog.DIR_PADRAO,
		dir_culturas: String = CropCatalog.DIR_PADRAO,
		dir_estabelecimentos: String = DefEstabelecimento.DIR_PADRAO) -> void:
	_items = ItemCatalog.new()
	_items.load_from_dir(dir_itens)
	_crops = CropCatalog.new()
	_crops.load_from_dir(dir_culturas)
	_dir_estabelecimentos = dir_estabelecimentos

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

## O resolvedor do "usar". Não é sistema — é consulta, como `pode_plantar`.
## `game/` pergunta a ele qual ação um clique vira e despacha o que voltar.
func get_resolvedor_uso() -> ResolvedorUso:
	return _resolvedor

func get_estado_locais() -> EstadoLocais:
	return _locais

func get_estado_cidade() -> EstadoCidade:
	return _cidade

func get_estado_terreno() -> EstadoTerreno:
	return _terreno

func get_estado_contratos() -> EstadoContratos:
	return _contratos

func get_estado_corpo() -> EstadoCorpo:
	return _corpo

func get_estado_oficios() -> EstadoOficios:
	return _oficios

## O mundo pronto para jogar: sistemas na ordem fixa, states no save e a mochila
## do primeiro dia. Quem vai carregar um save chama `restore()` logo depois — o
## restore substitui todo bloco registrado, inclusive o da partida nova.
func build() -> SimWorld:
	_time = TimeState.new()
	_inventory = InventoryState.new()
	_farm = FarmState.new()
	_shipping = ShippingState.new()
	_locais = EstadoLocais.new()
	_cidade = EstadoCidade.new()
	_contratos = EstadoContratos.new()
	_terreno = EstadoTerreno.new()
	_corpo = EstadoCorpo.new()
	_oficios = EstadoOficios.new()

	var world := SimWorld.new()
	# A ordem é regra de jogo: barrar fora de lugar → validar → vender →
	# crescer → virar o dia. O Locais é o primeiro porque o carimbo de rejeição
	# tem que chegar antes de o Inventory debitar (PlantCropAction cobra a
	# semente ao passar pelo Inventory).
	world.register_system(SistemaLocais.new(_locais))
	# Segundo, pela mesma razão do primeiro: `LimparTerrenoAction` tem que poder
	# ser recusada antes de qualquer sistema cobrar alguma coisa. A propagação da
	# noite não depende desta posição — ela acontece em `react`, e a fila do
	# `SimWorld` oferece cada evento a todos os sistemas.
	world.register_system(SistemaTerreno.new(_terreno, _farm, _items))
	world.register_system(InventorySystem.new(_inventory, _items, _crops))
	world.register_system(ShippingSystem.new(_shipping, _items))
	world.register_system(FarmSystem.new(_farm, _crops))
	# Depois do Farm: trabalho não passa por ação nenhuma aqui — o corpo só reage
	# ao que aconteceu. Para reações a posição não muda nada (a fila oferece cada
	# evento a todos), e a razão de estar aqui é de leitura: os eventos de
	# trabalho já passaram quando ele aparece na lista.
	#
	# Para a única ação que ele trata, a posição importa e é esta: `ComerAction`
	# estende `RemoveItemAction`, então o pão sai da mochila no Inventory antes de
	# o corpo recebê-lo. O catálogo vai junto porque quanto uma comida restaura é
	# campo de `.tres` — comida nova chega ao corpo sem tocar em código.
	world.register_system(SistemaCorpo.new(_corpo, _items))
	# Logo depois do Corpo, porque é o mesmo golpe: o que cansa é o que ensina, e
	# a tabela de XP é lida da dele. Para reações a posição não muda nada (a fila
	# oferece cada evento a todos), e a razão de estar aqui é de leitura.
	#
	# A única ação que ele trata não depende de sistema nenhum — comprar vantagem
	# não cobra item, não cobra dinheiro e não pode ser recusada por outro. O
	# `VantagemEscolhidaEvent` que sai daqui chega ao Corpo e ao Farm pela fila,
	# mesmo eles vindo antes na lista.
	world.register_system(SistemaOficios.new(_oficios, _crops))
	world.register_system(SistemaCidade.new(_cidade, _dir_estabelecimentos))
	# Depois da Cidade: o contrato é o degrau seguinte da mesma escada e reage ao
	# `RelacaoSubiuEvent` que ela emite. A posição só importa para as ações —
	# `CumprirContratoAction` estende `RemoveItemAction`, então tem que vir
	# depois do Inventory, que é quem tira o item.
	world.register_system(SistemaContratos.new(_contratos, _dir_estabelecimentos, _items))
	world.register_system(TimeSystem.new(_time))

	# A ordem de registro é a ordem dos blocos no arquivo de save. Bloco novo
	# entra no fim: save antigo carrega e o campo ausente cai no default.
	world.register_state(CHAVE_TIME, _time)
	world.register_state(CHAVE_INVENTORY, _inventory)
	world.register_state(CHAVE_FARM, _farm)
	world.register_state(CHAVE_SHIPPING, _shipping)
	world.register_state(CHAVE_LOCAIS, _locais)
	world.register_state(CHAVE_CIDADE, _cidade)
	world.register_state(CHAVE_CONTRATOS, _contratos)
	world.register_state(CHAVE_TERRENO, _terreno)
	world.register_state(CHAVE_CORPO, _corpo)
	world.register_state(CHAVE_OFICIOS, _oficios)

	# Depois dos states, porque ele lê dois deles. Não entra na fila do tick: o
	# resolvedor responde perguntas, não trata ações.
	_resolvedor = ResolvedorUso.new(_inventory, _farm, _items, _crops, _terreno)

	_entrega_inicial(world)
	# A fazenda nasce com o entulho espalhado. Os eventos morrem aqui pelo mesmo
	# motivo dos da entrega inicial — ainda não existe ninguém para desenhá-los,
	# e quem carregar um save troca este terreno pelo de lá.
	_terreno_inicial(world)
	return world

## As ferramentas e as sementes do primeiro dia entram pelo mesmo caminho de
## qualquer item: uma ação. Os eventos morrem aqui de propósito — ainda não
## existe partida para eles contarem nada.
##
## As ferramentas vêm primeiro para ocuparem os dois primeiros slots.
func _entrega_inicial(world: SimWorld) -> void:
	for item_id in FERRAMENTAS_INICIAIS:
		if _items.has(item_id):
			_entrega(world, item_id, 1)

	var def := _crops.get_def(CULTURA_INICIAL)
	if def == null:
		return
	_entrega(world, def.item_semente_id(), SEMENTES_INICIAIS)

## A fazenda que o jogador encontra no dia 1: entulho em manchas, sorteado pela
## semente do `EstadoTerreno`.
##
## Quem faz o trabalho é o sistema, e é ele que o teste cobre; aqui só se decide
## **quando** — na criação da partida, nunca no carregamento, porque o
## `restore()` substitui o bloco inteiro logo depois.
func _terreno_inicial(world: SimWorld) -> void:
	for system in world.get_systems():
		if system is SistemaTerreno:
			(system as SistemaTerreno).gera()
			return

func _entrega(world: SimWorld, item_id: String, qtd: int) -> void:
	var action := AddItemAction.new()
	action.player_id = PLAYER_PADRAO
	action.item_id = item_id
	action.qtd = qtd
	world.handle(action)
