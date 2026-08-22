class_name MundoEsboco
extends Control

## O mundo em retângulos: fazenda à esquerda, caminho no meio, cidade à
## direita, e o jogador é um quadrado creme que anda de verdade.
##
## É o esboço da wave 10 — a gameplay inteira testável antes de existir um
## pixel de arte. A posição em pixel mora aqui e NUNCA chega à sim: quando o
## quadrado cruza a fronteira de um terreno, este nó despacha `ViajarAction` e
## a sim fica sabendo só do **local**. O custo da viagem é o tempo de relógio
## que passa durante a caminhada — não existe número mágico de viagem.
##
## Nenhum `if` de regra mora aqui. Quem decide se a ação vale onde o jogador
## está é o `SistemaLocais`; a recusa volta como `ActionRejectedEvent` e vira
## texto no feed. Este nó só desenha e traduz.
##
## Os filhos (mira e inspetor) recebem o fio por `setup`, no mesmo padrão da
## `PlaygroundWindow`: quem tem filho com `setup` repassa a bridge à mão.
##
## Toda cor sai da `paleta.gd` — este arquivo não declara nenhuma.

## Um tile lógico da sim (16px do jogo real) desenhado em 20px de tela.
const TILE: float = 20.0
## GAMEPLAY §1: 4,5 tiles/s. A velocidade é a real para o playtest de
## distância valer — é ela que precifica a viagem à cidade.
const TILES_POR_SEGUNDO: float = 4.5

## O mapa do esboço, em tiles. Fazenda | caminho | cidade, lado a lado.
## ~15 tiles de caminho ≈ 3,3s de caminhada ≈ 4 min de relógio (wave 10, "em
## aberto": calibrar com o medidor do dia da wave 11).
const FAZENDA_LARGURA: int = 10
const CAMINHO_LARGURA: int = 15
const CIDADE_LARGURA: int = 8
const MAPA_ALTURA: int = 16
## A faixa vertical do caminho (o resto é "mato" que não se atravessa… por
## enquanto atravessa — esboço não tem colisão).
const CAMINHO_Y: int = 6
const CAMINHO_ALTURA: int = 4

## Os canteiros são os MESMOS 8×6 do farm_grid, nas MESMAS coordenadas da sim
## (0..7, 0..5). O offset só desloca o desenho para dentro do terreno.
const CANTEIRO_COLUNAS: int = 8
const CANTEIRO_LINHAS: int = 6
const CANTEIRO_OFFSET: Vector2i = Vector2i(1, 5)

## ## Os prédios da cidade (wave 12.1)
##
## **Quais** estabelecimentos existem é da sim (`SistemaCidade.ids()`); **onde**
## cada um fica é apresentação e é decidido aqui. Por isso a posição sai de uma
## conta pela ordem da lista, e não de um mapa id → tile: estabelecimento novo
## aparece no mapa sozinho, sem ninguém editar este arquivo.
##
## Eles existem para a mecânica ter lugar. Painel no rail não mostra que ir até
## o moinho custa o dia; um retângulo do outro lado do caminho mostra.
const PREDIO_OFFSET: Vector2i = Vector2i(2, 2)
const PREDIO_TAMANHO: Vector2i = Vector2i(4, 3)
## Distância vertical entre um prédio e o próximo, em tiles.
const PREDIO_ESPACO: int = 5

## ## Juice em retângulo (wave 11)
##
## Tudo abaixo é `Tween` de números e `draw_rect` — zero sprite, zero
## partícula. A aposta da wave: se com retângulo já for gostoso, com arte será
## ótimo; se for morno, a arte não salvaria.
##
## A regra dos ≤2 frames (GAMEPLAY §6) é sobre **latência**, não duração: o
## efeito começa no mesmo frame em que o evento chega, porque quem o dispara é
## o `_on_sim_event`. O que dura são estes números, e eles são de gosto —
## calibre jogando.

## Tremida da tela ao arar: deslocamento máximo em pixels e a velocidade com
## que ele volta a zero.
const TREMIDA_PIXELS: float = 3.0
const TREMIDA_DECAI: float = 14.0
## Quanto o jogador fica achatado no swing.
const ACHATADA_SEGUNDOS: float = 0.09
## O quanto ele achata: 1.0 é altura normal.
const ACHATADA_FATOR: float = 0.78
## Quanto o canteiro pisca ao receber uma ação.
const PISCA_SEGUNDOS: float = 0.22
## Quanto o quadradinho leva voando do canteiro até o jogador, e a altura do
## arco em pixels.
const VOO_SEGUNDOS: float = 0.34
const VOO_ARCO: float = 26.0
const VOO_LADO: float = 6.0
## O pulso da cultura pronta: um ciclo a cada 1,6s, crescendo 8% — o mesmo do
## mock aprovado.
const PULSO_SEGUNDOS: float = 1.6
const PULSO_AMPLITUDE: float = 0.08

var _bridge: SimBridge
## Posição do jogador em pixels de tela, relativa ao canto do mapa. Começa no
## meio da fazenda.
var _pos: Vector2 = Vector2(5.0 * TILE, 8.0 * TILE)
## Para onde o jogador olha (4 direções). Decide o tile mirado.
var _direcao: Vector2i = Vector2i(0, 1)
## Último local que este nó comunicou à sim — evita despachar viagem repetida
## a cada frame. A verdade continua sendo o `EstadoLocais`.
var _local_comunicado: String = EstadoLocais.FAZENDA
## Cache dos plots do snapshot; atualiza a cada evento da sim.
var _plots: Dictionary = {}

## O jogador apertou direção neste frame. É apresentação pura — a sim não sabe
## e não precisa saber que existe alguém andando.
var _andando: bool = false
## Mundo congelado: um painel modal está por cima. Também é apresentação — o
## relógio da sim continua correndo, e é isso que se quer: abrir a mochila não
## pausa o jogo, só tira as mãos do jogador do mundo.
var _congelado: bool = false
## Segundos que faltam de cada efeito. Todos decaem no `_process`, e nenhum
## deles mexe em estado de jogo.
var _tremida: float = 0.0
## A sacudida sorteada para ESTE frame — uma vez só, para o mundo e o retículo
## caírem no mesmo lugar.
var _deslocamento: Vector2 = Vector2.ZERO
var _achatada: float = 0.0
var _pulso: float = 0.0
## Canteiro ("x:y") → segundos restantes de piscada.
var _piscadas: Dictionary = {}
## Quadradinhos voando do canteiro até o jogador: {"de": Vector2i, "t": float}.
var _voos: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(_largura_mapa() * TILE, MAPA_ALTURA * TILE)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Um `Control` nasce com `MOUSE_FILTER_STOP`: ele engole o mouse antes de o
	# evento chegar ao `_unhandled_input`, que é por onde a mira lê o cursor.
	# Este nó desenha e não clica — quem lê o mouse é a mira, e para isso o
	# evento precisa atravessar o mundo inteiro sem ser consumido.
	#
	# O mesmo vale para os containers acima dele no `.tscn` (`Raiz`, `Corpo`,
	# `Mundo`), todos em `mouse_filter = 2`. Botão de painel continua em STOP e
	# continua recebendo clique normalmente — o filtro de um container não
	# alcança os filhos.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## Padrão 1: o fio chega e desce à mão para os filhos que sabem recebê-lo.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza_plots()
	for filho in get_children():
		if filho.has_method("setup"):
			filho.call("setup", bridge)
	set_process(true)

func get_bridge() -> SimBridge:
	return _bridge


# --- Leituras que os filhos (mira, inspetor) usam ---

## O tile do mapa onde o jogador está (pelo centro dos pés).
func tile_do_jogador() -> Vector2i:
	var pes := _pos + Vector2(TILE * 0.5, TILE * 1.8)
	return Vector2i(int(pes.x / TILE), int(pes.y / TILE))

## O tile mirado: o tile à frente do jogador (GAMEPLAY §1, facing-based).
func tile_mirado() -> Vector2i:
	return tile_do_jogador() + _direcao

## Um tile do mapa em coordenadas da sim (as mesmas do farm_grid), ou
## Vector2i(-1,-1) se cai fora do recorte de canteiros do playground. O recorte
## é apresentação — o mesmo 8×6 que o grid mostra — e não regra.
func canteiro_no_tile(tile_do_mapa: Vector2i) -> Vector2i:
	var tile := tile_do_mapa - CANTEIRO_OFFSET
	if tile.x < 0 or tile.x >= CANTEIRO_COLUNAS:
		return Vector2i(-1, -1)
	if tile.y < 0 or tile.y >= CANTEIRO_LINHAS:
		return Vector2i(-1, -1)
	return tile

## O canteiro à frente do jogador (mira do teclado).
func canteiro_mirado() -> Vector2i:
	return canteiro_no_tile(tile_mirado())

## O plot cru do snapshot para um canteiro em coordenadas da sim ({} se vazio).
func plot_em(canteiro: Vector2i) -> Dictionary:
	return _plots.get("%d:%d" % [canteiro.x, canteiro.y], {})

## Onde a tela acha que o jogador está — para os painéis; a verdade é da sim.
func local_visual() -> String:
	return _local_comunicado


# --- Os prédios da cidade ---

## O jogador apertou `E` em cima de um estabelecimento. A casca liga isto à aba
## da cidade — este nó não sabe que existe painel, e o painel não sabe que
## existe mapa.
signal predio_ativado(id: String)

## Os estabelecimentos que a sim conhece, na ordem em que aparecem no mapa.
func predios() -> Array[String]:
	var sistema := _sistema_cidade()
	return sistema.ids() if sistema != null else ([] as Array[String])

## Os tiles que o prédio ocupa no mapa, ou um `Rect2i()` vazio se a sim não
## conhece esse id — o mapa não inventa prédio.
func tiles_do_predio(id: String) -> Rect2i:
	var indice := predios().find(id)
	if indice < 0:
		return Rect2i()
	var canto := Vector2i(FAZENDA_LARGURA + CAMINHO_LARGURA, 0) \
		+ PREDIO_OFFSET + Vector2i(0, indice * PREDIO_ESPACO)
	return Rect2i(canto, PREDIO_TAMANHO)

## O que o prédio escreve na fachada: `PRONTA`, o tempo que falta, ou nada.
##
## É a contagem regressiva que a regra do projeto pede — o jogador olha para a
## cidade do outro lado do caminho e decide a rota do dia sem abrir painel.
func selo_do_predio(id: String) -> String:
	var sistema := _sistema_cidade()
	if sistema == null:
		return ""
	if sistema.tem_pronto(id):
		return "PRONTA"
	var faltam := sistema.minutos_para_a_proxima(id)
	return "" if faltam < 0 else PainelCidade.texto_do_tempo(faltam)

## Em que prédio o jogador está pisando, ou `""`. A conta é em pixel, e pixel é
## assunto de `game/` — a sim só sabe que ele está na cidade.
func predio_sob_o_jogador() -> String:
	var tile := tile_do_jogador()
	for id in predios():
		if tiles_do_predio(id).has_point(tile):
			return id
	return ""

## Abre o balcão do prédio onde o jogador está. Ativar **não** entrega nem
## retira: quanto e quando são o miolo da mecânica e continuam sendo botão.
func ativa_predio() -> void:
	if _congelado:
		return
	var id := predio_sob_o_jogador()
	if id.is_empty():
		return
	predio_ativado.emit(id)

## Põe o jogador em cima do prédio. Existe para o teste não precisar simular
## quatro segundos de caminhada — e para o dev conferir o balcão sem atravessar
## o mapa.
func teleporta_para_o_predio(id: String) -> void:
	var tiles := tiles_do_predio(id)
	if tiles.size == Vector2i.ZERO:
		return
	@warning_ignore("integer_division")
	var centro := tiles.position + tiles.size / 2
	# `tile_do_jogador` lê os pés (1,8 tile abaixo do canto), então a posição
	# desenhada sobe o mesmo tanto para o quadrado cair no tile pedido.
	_pos = Vector2(centro) * TILE - Vector2(TILE * 0.5, TILE * 1.8)
	_comunica_regiao()

## O sistema é dono das perguntas de regra; achar quem responde é problema de
## quem pergunta.
func _sistema_cidade() -> SistemaCidade:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			return system as SistemaCidade
	return null


# --- Movimento e viagem ---

func _process(delta: float) -> void:
	_avanca_juice(delta)
	_anda(delta)
	queue_redraw()

## `E` é interagir. Vai por `_unhandled_key_input` — só recebe o que ninguém
## mais quis, então a mochila aberta (que lê em `_input`) come a tecla antes.
##
## `SPACE` já é usar, `WASD` anda, `1–8` é hotbar e `Tab` é mochila: `E` era a
## que sobrava, e é a que o gênero inteiro usa para "entrar".
func _unhandled_key_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode != KEY_E:
		return
	get_viewport().set_input_as_handled()
	ativa_predio()

## O jogador está andando neste frame? O medidor do dia usa para separar
## "andando" de "parado" — a única pergunta que ele faz a este nó.
func esta_andando() -> bool:
	return _andando

## Congela ou descongela o mundo inteiro, mira junto. Quem chama é a casca,
## quando um painel modal abre — o mundo não sabe que a mochila existe.
##
## Congelado, o jogador continua desenhado e o relógio continua andando: o que
## para são as mãos dele. É por isso que congelar não é pausar.
func congela(valor: bool) -> void:
	_congelado = valor
	_andando = false
	var mira := get_node_or_null("MiraFerramentas") as MiraFerramentas
	if mira != null:
		mira.set_process_unhandled_key_input(not valor)
		mira.set_process_unhandled_input(not valor)

func congelado() -> bool:
	return _congelado

func _anda(delta: float) -> void:
	if _congelado:
		_andando = false
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	_andando = dir != Vector2.ZERO
	if not _andando:
		return

	dir = dir.normalized()
	_pos += dir * TILES_POR_SEGUNDO * TILE * delta
	_pos.x = clampf(_pos.x, 0.0, (_largura_mapa() - 1) * TILE)
	_pos.y = clampf(_pos.y, -TILE, (MAPA_ALTURA - 2) * TILE)
	# 4 direções: o eixo dominante do movimento decide o facing.
	if absf(dir.x) >= absf(dir.y):
		_direcao = Vector2i(1 if dir.x > 0.0 else -1, 0)
	else:
		_direcao = Vector2i(0, 1 if dir.y > 0.0 else -1)

	_comunica_regiao()

## Cruzou a fronteira de um terreno → a sim fica sabendo por ação, uma vez.
## O caminho não é local: quem está nele continua "vindo de onde veio" até
## pisar do outro lado.
func _comunica_regiao() -> void:
	var regiao := _regiao_atual()
	if regiao.is_empty() or regiao == _local_comunicado:
		return
	var acao := ViajarAction.new()
	acao.player_id = 0
	acao.destino = regiao
	_bridge.dispatch(acao)

func _regiao_atual() -> String:
	var tile_x := tile_do_jogador().x
	if tile_x < FAZENDA_LARGURA:
		return EstadoLocais.FAZENDA
	if tile_x >= FAZENDA_LARGURA + CAMINHO_LARGURA:
		return EstadoLocais.CIDADE
	return ""


# --- Eventos da sim ---

func _on_sim_event(event: SimEvent) -> void:
	if event is JogadorViajouEvent:
		_local_comunicado = (event as JogadorViajouEvent).para
	_atualiza_plots()
	_reage_com_juice(event)
	queue_redraw()

## O evento chega e o efeito começa **neste frame** — é isso que a regra dos ≤2
## frames pede. Cada ação tem a sua assinatura: arar sacode a tela, colher
## manda o quadradinho voando, crescer só pisca (é a cascata da manhã).
##
## Nenhum destes `match` decide regra: eles reagem ao que a sim já decidiu.
func _reage_com_juice(event: SimEvent) -> void:
	if event is PlotTilledEvent:
		var arado := event as PlotTilledEvent
		_tremida = TREMIDA_PIXELS
		_bate(Vector2i(arado.x, arado.y))
		return
	if event is PlotWateredEvent:
		var regado := event as PlotWateredEvent
		_bate(Vector2i(regado.x, regado.y))
		return
	if event is CropPlantedEvent:
		var plantado := event as CropPlantedEvent
		_bate(Vector2i(plantado.x, plantado.y))
		return
	if event is CropHarvestedEvent:
		var colhido := event as CropHarvestedEvent
		var canteiro := Vector2i(colhido.x, colhido.y)
		_bate(canteiro)
		_voos.append({"de": canteiro, "t": 0.0})
		return
	if event is CropGrewEvent:
		# Manhã-espetáculo: o canteiro pisca, mas o jogador não dá swing —
		# quem trabalhou foi a noite.
		var cresceu := event as CropGrewEvent
		_pisca(Vector2i(cresceu.x, cresceu.y))

## O par que toda ação de ferramenta faz: o canteiro pisca e o jogador achata.
func _bate(canteiro: Vector2i) -> void:
	_pisca(canteiro)
	_achatada = ACHATADA_SEGUNDOS

func _pisca(canteiro: Vector2i) -> void:
	_piscadas[_chave(canteiro)] = PISCA_SEGUNDOS

func _chave(canteiro: Vector2i) -> String:
	return "%d:%d" % [canteiro.x, canteiro.y]

## Todo efeito anda para o fim sozinho. Nenhum deles guarda estado de jogo:
## zerar tudo agora não muda uma vírgula do que a sim sabe.
func _avanca_juice(delta: float) -> void:
	_pulso = fmod(_pulso + delta, PULSO_SEGUNDOS)
	_tremida = move_toward(_tremida, 0.0, TREMIDA_DECAI * delta)
	_deslocamento = Vector2.ZERO if _tremida <= 0.0 else Vector2(
		randf_range(-_tremida, _tremida),
		randf_range(-_tremida, _tremida)).round()
	_achatada = maxf(_achatada - delta, 0.0)

	for chave: String in _piscadas.keys():
		var restante: float = float(_piscadas[chave]) - delta
		if restante <= 0.0:
			_piscadas.erase(chave)
			continue
		_piscadas[chave] = restante

	var voando: Array[Dictionary] = []
	for voo in _voos:
		voo["t"] = float(voo["t"]) + delta
		if float(voo["t"]) < VOO_SEGUNDOS:
			voando.append(voo)
	_voos = voando

## Painel mostra o snapshot, nunca state vivo (regra da wave 08).
func _atualiza_plots() -> void:
	_plots = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_FARM, {}).get("plots", {})


# --- Desenho ---

func _draw() -> void:
	var origem := _origem_desenho()

	# Terrenos: três retângulos e uma faixa. É o mapa inteiro do esboço.
	_desenha_tiles(origem, Rect2i(0, 0, FAZENDA_LARGURA, MAPA_ALTURA), Paleta.GRAMA)
	_desenha_tiles(origem,
		Rect2i(FAZENDA_LARGURA, CAMINHO_Y, CAMINHO_LARGURA, CAMINHO_ALTURA), Paleta.CAMINHO)
	var cidade := Rect2i(FAZENDA_LARGURA + CAMINHO_LARGURA, 0, CIDADE_LARGURA, MAPA_ALTURA)
	_desenha_tiles(origem, cidade, Paleta.CIDADE_CHAO)
	draw_rect(_rect_tiles(origem, cidade), Paleta.TERRA, false, 2.0)

	_desenha_canteiros(origem)
	_desenha_predios(origem)
	_desenha_voos(origem)
	_desenha_jogador(origem)

## Um retângulo por estabelecimento, com o nome e o selo de tempo na fachada.
##
## O prédio com coisa pronta é desenhado em ouro e o selo vira caixa alta: é o
## "dá para ver de longe" que o `ARTE.md` §11 pede do sprite, adiantado em
## retângulo. O prédio sob os pés do jogador ganha contorno — é o retorno de que
## `E` vai funcionar ali.
func _desenha_predios(origem: Vector2) -> void:
	var aqui := predio_sob_o_jogador()
	for id in predios():
		var rect := _rect_tiles(origem, tiles_do_predio(id)).grow(-2.0)
		var selo := selo_do_predio(id)
		var pronto := selo == "PRONTA"

		draw_rect(rect, Paleta.PAINEL_2)
		draw_rect(rect, Paleta.OURO if pronto else Paleta.TERRA, false, 2.0)
		if id == aqui:
			draw_rect(rect.grow(3.0), Paleta.JOGADOR, false, 1.0)

		_escreve(rect.position + Vector2(6.0, 16.0), _nome_do_predio(id), Paleta.TINTA)
		if not selo.is_empty():
			_escreve(rect.position + Vector2(6.0, 32.0), selo,
				Paleta.OURO if pronto else Paleta.TINTA_2)

## Nome bonito é conteúdo do `.tres`; sem definição, o id serve — sumir da tela
## seria pior.
func _nome_do_predio(id: String) -> String:
	var sistema := _sistema_cidade()
	var def := sistema.def_de(id) if sistema != null else null
	return def.nome if def != null and not def.nome.is_empty() else id

func _escreve(pos: Vector2, texto: String, cor: Color) -> void:
	var fonte := ThemeDB.fallback_font
	draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor)

func _desenha_canteiros(origem: Vector2) -> void:
	for y in CANTEIRO_LINHAS:
		for x in CANTEIRO_COLUNAS:
			var canteiro := Vector2i(x, y)
			var canto := origem + Vector2(CANTEIRO_OFFSET + canteiro) * TILE
			var rect := Rect2(canto, Vector2(TILE, TILE)).grow(-1.0)
			var plot: Dictionary = plot_em(canteiro)
			if plot.is_empty():
				# Canteiro virgem: só o contorno, para se saber onde arar.
				draw_rect(rect, Paleta.CONTORNO, false, 1.0)
				_desenha_piscada(rect, canteiro)
				continue
			# Canal 1 — o SOLO fala de rega: claro seco, escuro molhado.
			var regada := bool(plot.get("regada", false))
			draw_rect(rect, Paleta.SOLO_MOLHADO if regada else Paleta.SOLO_SECO)
			_desenha_broto(rect, plot)
			_desenha_piscada(rect, canteiro)

## O canteiro que acabou de receber ação clareia por um instante. É luz por
## cima, não troca de cor: os dois canais (rega no solo, estágio na planta)
## continuam dizendo o que diziam.
func _desenha_piscada(rect: Rect2, canteiro: Vector2i) -> void:
	var restante: float = float(_piscadas.get(_chave(canteiro), 0.0))
	if restante <= 0.0:
		return
	draw_rect(rect, Paleta.veu(Paleta.TINTA, 0.55 * (restante / PISCA_SEGUNDOS)))

## A colheita voa em arco do canteiro até o jogador (GAMEPLAY §6). Sem sprite:
## é um quadradinho da cor da cultura pronta.
func _desenha_voos(origem: Vector2) -> void:
	var destino := origem + _pos + Vector2(TILE * 0.5, TILE * 0.6)
	for voo in _voos:
		var fracao: float = float(voo["t"]) / VOO_SEGUNDOS
		var canteiro: Vector2i = voo["de"]
		var saida := origem \
			+ Vector2(CANTEIRO_OFFSET + canteiro) * TILE \
			+ Vector2(TILE * 0.5, TILE * 0.5)
		var ponto := saida.lerp(destino, fracao)
		# O arco: uma parábola que sobe no meio do caminho e volta.
		ponto.y -= VOO_ARCO * sin(fracao * PI)
		var lado := VOO_LADO * (1.0 - fracao * 0.4)
		draw_rect(Rect2(ponto - Vector2(lado, lado) * 0.5, Vector2(lado, lado)),
			Paleta.PRONTA)

## Canal 2 — a PLANTA fala de estágio: o quadrado verde cresce com ele e a
## pronta é maior e mais clara. Nunca misturar os canais (ARTE.md §2).
func _desenha_broto(rect: Rect2, plot: Dictionary) -> void:
	var crop_id := String(plot.get("crop_id", ""))
	if crop_id.is_empty():
		return
	var def := _bridge.get_crop_catalog().get_def(crop_id)
	if def == null:
		return
	var estagio := int(plot.get("estagio", 0))
	var pronta := estagio >= def.estagio_pronta()
	var fracao := 0.25 + 0.55 * (float(estagio) / float(maxi(def.estagio_pronta(), 1)))
	var lado := rect.size.x * fracao
	# Terceiro sinal da pronta: ela pulsa. O primeiro é ser maior, o segundo é
	# ser mais clara — três sinais redundantes, legíveis para daltônicos
	# (GAMEPLAY §6).
	if pronta:
		lado *= 1.0 + PULSO_AMPLITUDE * sin(_pulso / PULSO_SEGUNDOS * TAU)
	var broto := Rect2(
		rect.get_center() - Vector2(lado * 0.5, lado * 0.5),
		Vector2(lado, lado))
	draw_rect(broto, Paleta.PRONTA if pronta else Paleta.PLANTA)

func _desenha_jogador(origem: Vector2) -> void:
	# 16×32 do jogo real = 1×2 tiles do esboço.
	var corpo := Rect2(origem + _pos, Vector2(TILE, TILE * 2.0))
	corpo = _achata(corpo)
	draw_rect(corpo, Paleta.JOGADOR)
	# O "rosto": um ponto escuro no lado para onde o jogador olha.
	var olho := corpo.get_center() + Vector2(_direcao) * TILE * 0.3 - Vector2(2, 6)
	draw_rect(Rect2(olho, Vector2(4, 4)), Paleta.FUNDO)

## O swing: o corpo achata e alarga por um instante, com os pés no chão. É o
## truque mais barato de animação que existe e o que mais devolve peso ao
## golpe — se funcionar no retângulo, funciona no sprite.
func _achata(corpo: Rect2) -> Rect2:
	if _achatada <= 0.0:
		return corpo
	var forca := _achatada / ACHATADA_SEGUNDOS
	var altura := corpo.size.y * lerpf(1.0, ACHATADA_FATOR, forca)
	var largura := corpo.size.x * lerpf(1.0, 2.0 - ACHATADA_FATOR, forca)
	return Rect2(
		Vector2(corpo.get_center().x - largura * 0.5, corpo.end.y - altura),
		Vector2(largura, altura))


# --- Geometria ---

func _largura_mapa() -> int:
	return FAZENDA_LARGURA + CAMINHO_LARGURA + CIDADE_LARGURA

## O mapa centralizado no espaço que o painel deu. **Sem tremida**: esta é a
## origem da geometria, e é ela que traduz mouse em tile. Se a tremida entrasse
## aqui, um clique durante os 0,2s do efeito poderia cair no canteiro do lado —
## juice não pode mudar onde a ação acerta.
func _origem_mapa() -> Vector2:
	var mapa := Vector2(_largura_mapa(), MAPA_ALTURA) * TILE
	return ((size - mapa) * 0.5).floor()

## A origem do desenho: a de cima, sacudida. Quem desenha usa esta; quem mira
## usa a outra. O retículo desenha por aqui de propósito — ele acompanha a
## tremida em vez de ficar solto no meio dela.
##
## O sorteio da sacudida acontece uma vez por frame, no `_avanca_juice`: se
## fosse sorteado a cada chamada, o mundo e o retículo cairiam em pontos
## diferentes dentro do mesmo frame.
func _origem_desenho() -> Vector2:
	return _origem_mapa() + _deslocamento

func _rect_tiles(origem: Vector2, tiles: Rect2i) -> Rect2:
	return Rect2(origem + Vector2(tiles.position) * TILE, Vector2(tiles.size) * TILE)

func _desenha_tiles(origem: Vector2, tiles: Rect2i, cor: Color) -> void:
	draw_rect(_rect_tiles(origem, tiles), cor)

## A mira usa para converter tile do mapa em retângulo de tela. Vai pela origem
## do desenho: o retículo sacode junto com o mundo.
func rect_do_tile(tile: Vector2i) -> Rect2:
	return Rect2(_origem_desenho() + Vector2(tile) * TILE, Vector2(TILE, TILE))

## O inverso: em que tile do mapa caiu um ponto da tela (posição local deste
## nó). A mira usa para o mouse.
func tile_na_posicao(pos: Vector2) -> Vector2i:
	var relativa := pos - _origem_mapa()
	return Vector2i(floori(relativa.x / TILE), floori(relativa.y / TILE))

## O ponto está dentro do desenho do mapa? Fora dele o mouse não mira nada.
func posicao_no_mapa(pos: Vector2) -> bool:
	var tile := tile_na_posicao(pos)
	if tile.x < 0 or tile.x >= _largura_mapa():
		return false
	return tile.y >= 0 and tile.y < MAPA_ALTURA
