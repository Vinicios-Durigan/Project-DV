class_name MiraFerramentas
extends Control

## O retículo no tile alvo e o **usar**. Uma ação só: o que ela faz depende do
## item que está na mão.
##
## ## Não existe mais "modo ferramenta"
##
## Até a wave 11.1 este arquivo tinha um enum de quatro ferramentas nas teclas
## 1–4 e plantava sempre a primeira cultura do catálogo. Era um atalho da wave
## 10 que contradizia o `GAMEPLAY §4` ("hotbar 8 slots; ferramentas e sementes
## ocupam slots") — e foi ele que fez comprar semente não servir para nada.
##
## Agora quem decide é `sim/`: este nó pergunta ao `ResolvedorUso` qual ação um
## uso no tile alvo vira, e despacha o que voltar. Nenhum `if` de regra mora
## aqui, nem sequer para escolher entre arar e plantar.
##
## ## Duas miras, uma regra
##
## O **mouse manda**: onde ele está sobre o mapa é o alvo, e o clique usa. Sem
## cursor sobre o mapa, o retículo **some** — antes ele pulava para o tile à
## frente do personagem, e era esse pulo que fazia a mira parecer ter vontade
## própria.
##
## O caminho do teclado continua vivo: facing + espaço agem no tile à frente.
## Ele não custa nada, já existe, e é a única coisa que segura a promessa de
## gamepad e co-op do §1.
##
## ## Alcance mora aqui, e só podia morar aqui
##
## Sem limite de alcance, dá para arar a fazenda inteira clicando de longe — e
## isso mataria a mecânica que a wave 10 construiu, porque andar deixaria de
## custar tempo.
##
## O alcance é a única regra que `game/` julga, e é assim por decisão de
## design: o GAMEPLAY §8 diz que **a posição do jogador não entra na sim** — ela
## conhece só o tile alvo dentro da ação. Sem posição, não tem como julgar
## distância. Quem tem a posição é este arquivo, então o alcance é dele. Não é
## regra vazada; é a consequência de onde a posição foi colocada.
##
## ---
##
## ## Padrão 2 — mandar ordens
##
## O clique não muda nada na tela. Ele monta a `SimAction` que a sim indicou,
## entrega para a bridge e acaba ali. Se o jogador estiver na cidade, o
## `SistemaLocais` recusa e o motivo volta como `ActionRejectedEvent` — este nó
## não sabe e não decide.
##
## **Regra de jogo nunca desabilita a ação** (design system v1): quando o
## resolvedor devolve uma ação, ela vai à sim mesmo que vá ser recusada. É a
## recusa que ensina o jogador. O `null` do resolvedor é outra coisa: é
## ausência de ação, não impossibilidade — usar a enxada num tile já arado não
## tem o que recusar.

## Quantos tiles de distância o jogador alcança, em cada eixo. 1 = os 8 tiles
## em volta mais o de baixo dos pés. Calibrar jogando.
const ALCANCE: int = 1

## Distância do rótulo do item até o topo do retículo, em pixels.
const FOLGA_DO_ROTULO: float = 6.0

var _bridge: SimBridge
var _mundo: MundoEsboco
var _ultimo_tile: Vector2i = Vector2i(-999, -999)
## Onde o mouse está mirando. Ele manda enquanto estiver sobre o mapa; saiu, o
## retículo some e só o teclado age.
var _tile_mouse: Vector2i = Vector2i(-999, -999)
var _mouse_no_mapa: bool = false
## O que está na mão, segundo a sim. Chega pelo `SlotEquipadoEvent` — o painel
## não precisa avisar ninguém.
var _item_na_mao: String = ""
## Quanto o item na mão ainda tem, e quanto cabe. `-1` na capacidade é "não
## carrega nada" — o caso de tudo menos o regador.
var _carga: int = 0
var _capacidade: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Ignora o mouse para não roubar clique de botão nenhum: quem lê o clique é
	# `_unhandled_input`, que só recebe o que ninguém mais quis.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_unhandled_key_input(false)
	set_process_unhandled_input(false)

func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_mundo = get_parent() as MundoEsboco
	_bridge.sim_event.connect(_on_sim_event)
	_le_a_mao()
	set_process(true)
	set_process_unhandled_key_input(true)
	set_process_unhandled_input(true)


# --- Alvo ---

## Existe um tile alvo agora? Sem cursor sobre o mapa, não existe — e é por isso
## que o retículo some em vez de pular.
func tem_alvo() -> bool:
	return _mouse_no_mapa

## O tile que a ação vai atingir. O mouse manda quando está sobre o mapa; sem
## ele, vale o facing, que é o caminho do teclado.
func tile_alvo() -> Vector2i:
	if _mouse_no_mapa:
		return _tile_mouse
	return _mundo.tile_mirado()

## O alvo está ao alcance do jogador? Ver o cabeçalho: esta é a única regra que
## `game/` julga, porque a sim não tem a posição para julgá-la.
func no_alcance(tile: Vector2i) -> bool:
	var jogador := _mundo.tile_do_jogador()
	return absi(tile.x - jogador.x) <= ALCANCE and absi(tile.y - jogador.y) <= ALCANCE

## O que está na mão. O rótulo do retículo sai daqui.
func item_na_mao() -> String:
	return _item_na_mao

## O texto escrito acima do retículo: o nome do item e, quando ele carrega
## alguma coisa, quanto ainda tem.
##
## Existe como função pública, e não solto dentro do `_draw`, porque é a única
## forma de o teste ler o que o jogador lê — texto desenhado com `draw_string`
## não deixa nó nenhum para inspecionar.
func rotulo() -> String:
	if _item_na_mao.is_empty():
		return ""
	var def := _bridge.get_item_catalog().get_def(_item_na_mao) if _bridge != null else null
	var nome := def.nome if def != null and not def.nome.is_empty() else _item_na_mao
	if _capacidade <= 0:
		return nome
	return "%s %d/%d" % [nome, _carga, _capacidade]


# --- Input ---

## O espaço continua agindo no tile à frente: é o caminho do teclado e do
## gamepad, e some junto com a promessa de co-op se for removido. As teclas da
## hotbar (1–8) não chegam aqui — o painel da mochila as consome antes, em
## `_input`.
func _unhandled_key_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode != KEY_SPACE:
		return
	accept_event()
	var canteiro := _mundo.canteiro_mirado()
	usa(canteiro.x, canteiro.y)

## O mouse: mover reposiciona a mira, clicar usa.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_atualiza_mouse(event)
		return

	var clique := event as InputEventMouseButton
	if clique == null or not clique.pressed:
		return
	if clique.button_index != MOUSE_BUTTON_LEFT:
		return
	_atualiza_mouse(clique)
	if not _mouse_no_mapa:
		return
	accept_event()
	var canteiro := _mundo.canteiro_no_tile(tile_alvo())
	usa(canteiro.x, canteiro.y)

## Onde o cursor está, no espaço do mundo.
##
## A posição vem **do evento**, e não de `get_local_mouse_position()`. Os dois
## dão o mesmo resultado com um cursor de verdade na tela, mas o segundo
## pergunta ao SO onde o mouse está agora — o que torna o caminho impossível de
## testar (sem cursor, ele responde sempre a mesma coisa) e frágil quando o
## playground está numa janela separada, que é o caso aqui.
##
## `make_input_local` converte a posição do espaço do viewport para o espaço do
## nó do mundo, que é onde o mapa é desenhado.
func _atualiza_mouse(evento: InputEvent) -> void:
	if _mundo == null:
		return
	var local: Vector2 = (_mundo.make_input_local(evento) as InputEventMouse).position
	var antes := _mouse_no_mapa
	_mouse_no_mapa = _mundo.posicao_no_mapa(local)
	_tile_mouse = _mundo.tile_na_posicao(local)
	if antes != _mouse_no_mapa:
		queue_redraw()
	_marca_redesenho()

func _process(_delta: float) -> void:
	# O mundo redesenha sozinho ao andar; a mira precisa acompanhar o alvo.
	_marca_redesenho()

func _marca_redesenho() -> void:
	var tile := tile_alvo()
	if tile == _ultimo_tile:
		return
	_ultimo_tile = tile
	queue_redraw()

func _on_sim_event(event: SimEvent) -> void:
	if event is SlotEquipadoEvent:
		_item_na_mao = (event as SlotEquipadoEvent).item_id
		_le_a_carga()
	# A carga muda em dois momentos, e os dois avisam: uma regada saiu, ou o
	# regador voltou cheio do poço. Reler aqui, e não no `_draw`, é o que evita
	# um `snapshot()` por frame — a foto é cara, e o retículo redesenha sempre.
	if event is RegadorEnchidoEvent or event is PlotWateredEvent:
		_le_a_carga()
	queue_redraw()

## A mão no boot: nenhum evento aconteceu ainda, então o valor inicial vem do
## snapshot — a mesma foto que o save grava.
func _le_a_mao() -> void:
	_item_na_mao = _resolvedor().item_na_mao(SimFactory.PLAYER_PADRAO)
	_le_a_carga()

## Quanto o item na mão ainda tem dentro, e quanto cabe. Padrão 3: sai do
## `snapshot()`, a mesma foto que o save grava.
##
## `-1` na capacidade quer dizer "isto não carrega nada", que é o caso de tudo
## menos o regador — e é o que faz o rótulo não escrever `0/0` na enxada.
func _le_a_carga() -> void:
	_carga = 0
	_capacidade = -1
	if _bridge == null or _item_na_mao.is_empty():
		return

	var def := _bridge.get_item_catalog().get_def(_item_na_mao)
	if def == null or def.capacidade_carga <= 0:
		return
	_capacidade = def.capacidade_carga

	var jogador: Dictionary = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_INVENTORY, {}).get(str(SimFactory.PLAYER_PADRAO), {})
	var slots: Array = jogador.get("slots", [])
	var indice := int(jogador.get("slot_na_mao", 0))
	if indice < 0 or indice >= slots.size():
		return
	_carga = int((slots[indice] as Dictionary).get("carga", 0))


# --- Ordens ---

## Usa no canteiro, em coordenadas da sim. **Zero regra aqui**: quem diz o que
## um uso vira é o `ResolvedorUso`, em `sim/`. Este método confere o alcance,
## pergunta e despacha.
##
## O alcance é medido em tiles do **mapa**, não em coordenadas de canteiro — por
## isso a conversão acontece aqui dentro, e não em quem chama. Assim não existe
## caminho de entrada que esqueça de conferir o braço.
func usa(x: int, y: int) -> void:
	if x < 0 or y < 0:
		return
	# Braço curto é a regra que impede arar a fazenda toda de longe, e sem ela
	# andar deixaria de custar tempo.
	if not no_alcance(Vector2i(x, y) + MundoEsboco.CANTEIRO_OFFSET):
		return

	var acao := _resolvedor().acao_para(SimFactory.PLAYER_PADRAO, x, y)
	if acao == null:
		return
	_bridge.dispatch(acao)

## O resolvedor é da fábrica, como os catálogos. `game/` não guarda referência
## de state — pergunta e esquece.
func _resolvedor() -> ResolvedorUso:
	return _bridge.get_factory().get_resolvedor_uso()


# --- Desenho ---

func _draw() -> void:
	if _mundo == null or not _mouse_no_mapa:
		# Sem cursor sobre o mapa não há alvo, e sem alvo não há retículo. Antes
		# ele pulava para a frente do personagem — e era esse pulo que fazia a
		# mira parecer ter vontade própria.
		return

	# A cor diz se o alvo serve, não a ausência. Vermelho é "não dá para agir
	# aqui de onde você está" — fora do alcance ou fora dos canteiros. Nunca é
	# julgamento de regra de jogo: se a cultura já pode ser colhida, quem
	# responde é a sim, e a resposta vem no diário.
	var alvo := tile_alvo()
	var pode := no_alcance(alvo) and _mundo.canteiro_no_tile(alvo).x >= 0
	var rect := _mundo.rect_do_tile(alvo).grow(-1.0)
	draw_rect(rect, Paleta.VERDE if pode else Paleta.ALERTA, false, Paleta.BORDA_FOCO)

	_desenha_rotulo(rect, pode)

## O item na mão, escrito em cima do retículo. É o que responde "o que este
## clique vai fazer?" sem tirar o olho do canteiro.
func _desenha_rotulo(rect: Rect2, pode: bool) -> void:
	if _item_na_mao.is_empty():
		return
	# O que carrega mostra quanto tem, no mesmo rótulo. Regar até acabar precisa
	# ser legível sem abrir painel — o número na mão é o aviso, e ele fica onde
	# o olho do jogador já está: em cima do retículo.
	var nome := rotulo()
	var fonte := get_theme_default_font()
	var largura := fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Paleta.TAMANHO_DADO).x
	draw_string(fonte,
		Vector2(rect.get_center().x - largura * 0.5, rect.position.y - FOLGA_DO_ROTULO),
		nome, HORIZONTAL_ALIGNMENT_LEFT, -1, Paleta.TAMANHO_DADO,
		Paleta.TINTA if pode else Paleta.ALERTA)
