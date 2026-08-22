class_name SaveGateway
extends Node

## Liga a sim ao disco: carrega o slot no boot e salva sozinho quando o dia
## acaba.
##
## Não sabe o que tem dentro do save — quem monta o snapshot é o `SimWorld` e
## quem escreve o arquivo é o `SaveManager`. Aqui só moram duas decisões de
## apresentação: **quando** salvar e **o que fazer** quando não dá.
##
## Slot ausente, arquivo corrompido ou save de uma versão que este jogo não
## entende dão todos no mesmo lugar: jogo novo, com o mundo que a `SimFactory`
## acabou de montar. Meio-carregado seria pior.
##
## Recebe a bridge por injeção (`setup`), como todo nó que fala com a sim.

## O dia acabou e o mundo inteiro já está no arquivo (GAMEPLAY §3, passo 4).
signal game_saved(slot: String)
## O boot terminou. `carregado` é falso quando a partida começou do zero.
signal game_loaded(slot: String, carregado: bool)
## Tinha save no slot e não deu para usar: `game/` avisa o jogador antes que ele
## jogue meia hora achando que continuou de onde parou.
signal save_rejected(slot: String)

## Qual arquivo é a partida. Um slot é um arquivo; o seletor de slot é wave
## futura.
@export var slot: String = SaveManager.SLOT_PADRAO
## Salvar ao fim de todo dia. Desligar é ferramenta de debug, não de jogo.
@export var autosave: bool = true

var _bridge: SimBridge
var _manager: SaveManager
var _migrations: SaveMigrations

## Injeção pela bridge. O `SaveManager` é criável aqui porque disco é assunto de
## apresentação: a sim não sabe que existe arquivo.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	if _manager == null:
		_manager = SaveManager.new()
	if _migrations == null:
		_migrations = SaveMigrations.new()
	_bridge.sim_event.connect(_on_sim_event)
	_load()

## O gerenciador é injetável para o teste não escrever no save do jogador.
func set_manager(manager: SaveManager, migrations: SaveMigrations = null) -> void:
	_manager = manager
	if migrations != null:
		_migrations = migrations

func get_manager() -> SaveManager:
	return _manager

## Escreve a sim inteira no slot agora. Devolve `false` quando o disco recusou —
## quem chamou decide o que dizer ao jogador.
func save() -> bool:
	if _bridge == null or _bridge.get_world() == null:
		return false
	var ok := _manager.save_slot(_bridge.get_world().snapshot(), slot)
	if ok:
		game_saved.emit(slot)
	return ok

## Autosave é reação ao fim do dia, nunca a um timer: quando o `DayEndedEvent`
## chega aqui, a sim já fechou a cascata inteira da noite (venda, crescimento,
## calendário) — o `advance`/`handle` só emite depois de a fila esvaziar. O que
## vai para o arquivo é sempre a manhã completa, nunca um estado pela metade.
func _on_sim_event(event: SimEvent) -> void:
	if not autosave or not event is DayEndedEvent:
		return
	save()

## Boot: slot ausente é jogo novo, e não erro. O mundo já veio montado da
## fábrica, então carregar é só sobrescrever os blocos que o arquivo trouxe.
func _load() -> void:
	var bruto: Variant = _manager.load_slot(slot)
	if not bruto is Dictionary:
		game_loaded.emit(slot, false)
		return

	var migrado: Variant = _migrations.migrate(bruto as Dictionary)
	if not migrado is Dictionary:
		# save de uma versão mais nova, ou trilho sem o passo: jogo novo, com
		# aviso. O arquivo continua no disco, intacto, para não sumir com a
		# partida de ninguém.
		save_rejected.emit(slot)
		game_loaded.emit(slot, false)
		return

	_bridge.get_world().restore(migrado as Dictionary)
	game_loaded.emit(slot, true)
