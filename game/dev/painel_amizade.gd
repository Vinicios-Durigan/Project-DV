class_name PainelAmizade
extends VBoxContainer

## A ficha de amizade de cada estabelecimento: em que degrau o jogador está,
## quanto falta para o próximo e o que ele vai comprar.
##
## ## Por que uma aba, e não uma linha no balcão
##
## A aba da cidade mostra a relação em **um número cru** — "relação 7 dias". O
## número sozinho não diz nada: não diz que 7 acabou de cruzar um degrau, não
## diz que faltam 7 para o próximo, não diz que o dono passou a encomendar por
## causa dele. Constância é a mecânica mais lenta do jogo — ela leva semanas de
## jogo para andar — e a mecânica mais lenta é justamente a que precisa mostrar
## a curva, senão ela parece parada.
##
## Aqui a escada aparece inteira: a parte já subida, o degrau de agora e o que
## cada um dos próximos entrega. É a tela de "vale a pena continuar aparecendo".
##
## ## Nenhum degrau é calculado aqui
##
## Degrau, limiar, ganho de cota, teto do prédio e liberação de contrato são
## **perguntas de regra**, e todas saem do `SistemaCidade` — do mesmo jeito que
## `cota_de` e `pode_entregar`. Este arquivo só formata a resposta. Quando a
## tela e a sim discordarem sobre em que degrau o jogador está, quem errou é
## este arquivo (CLAUDE.md).
##
## ## O histórico é de sessão, e diz isso
##
## Os movimentos listados embaixo de cada ficha saem de `RelacaoSubiuEvent` e
## `RelacaoCaiuEvent` conforme eles passam — a sim não guarda um diário de
## amizade, e inventar um só para a tela seria state paralelo. Carregar um save
## começa a lista vazia, e é isso que o rótulo promete: "nesta sessão".

## Quantos movimentos de relação a ficha lembra. Cinco cabem sem empurrar a
## escada para fora da janela, e é o suficiente para a curva aparecer.
const MOVIMENTOS_LEMBRADOS: int = 5

## Altura da barra de progresso, na grade de 4px.
const ALTURA_DA_BARRA: float = 8.0

var _bridge: SimBridge

## Qual estabelecimento o jogador acabou de abrir pelo mapa. Só destaque de
## tela, como no balcão.
var _destacado: String = ""

## id -> os nós daquela ficha, para redesenhar sem remontar.
var _nomes: Dictionary = {}
var _selos: Dictionary = {}
var _barras: Dictionary = {}
var _progressos: Dictionary = {}
var _cotas: Dictionary = {}
var _escadas: Dictionary = {}
var _contratos: Dictionary = {}
var _diarios: Dictionary = {}

## id -> os movimentos desta sessão, o mais recente primeiro.
var _historicos: Dictionary = {}
## id -> quantos dias a relação tinha da última vez que este painel olhou. É o
## que transforma o total do evento em "+1" ou "−2".
var _ultimos_dias: Dictionary = {}


func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_monta()
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza()


# --- Leitura: tudo o que aparece na tela vem da sim ---

## Os estabelecimentos que a sim conhece. A lista não mora neste arquivo.
func estabelecimentos() -> Array[String]:
	var sistema := _sistema()
	return sistema.ids() if sistema != null else ([] as Array[String])

## Quantos dias diferentes tiveram entrega aqui.
func dias(id: String) -> int:
	var sistema := _sistema()
	return sistema.dias_de_relacao(id) if sistema != null else 0

## Em que degrau da escada o jogador está.
func degrau(id: String) -> int:
	var sistema := _sistema()
	return sistema.degrau_de(id) if sistema != null else 0

## Quantos degraus a escada tem ao todo.
func degraus(id: String) -> int:
	var sistema := _sistema()
	return sistema.degraus_de(id) if sistema != null else 0

## Quantos dias faltam para o próximo degrau, ou `-1` no topo.
func falta(id: String) -> int:
	var sistema := _sistema()
	return sistema.dias_para_o_proximo_degrau(id) if sistema != null else -1

## Quanto a cota sobe quando o próximo degrau cair.
func ganho(id: String) -> int:
	var sistema := _sistema()
	return sistema.ganho_do_proximo_degrau(id) if sistema != null else 0

## A cota vigente do jogador aqui.
func cota(id: String) -> int:
	var sistema := _sistema()
	return sistema.cota_de(id) if sistema != null else 0

## O teto do prédio, que só a compra levanta.
func capacidade(id: String) -> int:
	var sistema := _sistema()
	return sistema.capacidade_de(id) if sistema != null else 0

## A cota encostou no teto? É o sinal que destrava a compra na wave do dono.
func no_teto(id: String) -> bool:
	var sistema := _sistema()
	return sistema.cota_no_teto(id) if sistema != null else false

## Quanto do caminho até o próximo degrau já foi andado, de 0 a 1. No topo da
## escada é 1: não há trecho a andar.
func fracao(id: String) -> float:
	var sistema := _sistema()
	if sistema == null:
		return 0.0
	var limiar := sistema.proximo_limiar_de(id)
	if limiar <= 0:
		return 1.0
	return clampf(float(dias(id)) / float(limiar), 0.0, 1.0)

## Os movimentos de relação desta sessão, o mais recente primeiro.
func historico(id: String) -> Array[String]:
	var bruto: Variant = _historicos.get(id, [])
	return bruto if bruto is Array[String] else ([] as Array[String])

## Qual estabelecimento está em destaque, ou `""`.
func destacado() -> String:
	return _destacado

## Marca o estabelecimento que o jogador abriu pelo prédio no mapa — o mesmo
## gesto do balcão, para as duas abas concordarem sobre onde ele está.
func destaca(id: String) -> void:
	_destacado = id
	_mostra_destaque()


# --- Texto ---

## "degrau 2 de 4". Sem degrau nenhum ainda, "sem degrau" — "degrau 0" leria
## como um degrau que existe.
func texto_do_degrau(id: String) -> String:
	var atual := degrau(id)
	if degraus(id) <= 0:
		return "sem escada"
	return "sem degrau" if atual <= 0 else "degrau %d de %d" % [atual, degraus(id)]

## "3 de 7 dias · faltam 4 para o degrau 2 (+4 de cota)", ou o topo da escada.
func texto_do_progresso(id: String) -> String:
	var quanto := falta(id)
	if quanto < 0:
		return "%s · no topo da escada" % _dias_em_texto(dias(id))

	var proximo := "%s · faltam %s para o degrau %d" % [
		_dias_em_texto(dias(id)), _dias_em_texto(quanto), degrau(id) + 1,
	]
	var sobe := ganho(id)
	# Degrau que não levanta cota nenhuma é degrau que não cabe no prédio.
	# Prometer "+0 de cota" seria pior que não prometer nada.
	return proximo if sobe <= 0 else "%s (+%d de cota)" % [proximo, sobe]

## "cota 10 · capacidade 20", com o aviso quando ela encosta no teto.
func texto_da_cota(id: String) -> String:
	var base := "cota %d · capacidade %d" % [cota(id), capacidade(id)]
	return "%s · no teto do prédio" % base if no_teto(id) else base

## A escada inteira: "●3 ●7 ○14 ○24". O que já caiu fica cheio.
func texto_da_escada(id: String) -> String:
	var sistema := _sistema()
	if sistema == null:
		return ""
	var partes: Array[String] = []
	for limiar in sistema.limiares_de(id):
		partes.append("%s%d" % ["●" if dias(id) >= limiar else "○", limiar])
	return "  ".join(partes)

## O que a amizade já destravou do contrato, na língua do jogador.
func texto_do_contrato(id: String) -> String:
	var sistema := _sistema()
	if sistema == null:
		return ""
	var faltam := sistema.degraus_para_o_contrato(id)
	if faltam < 0:
		return "não encomenda"
	if faltam == 0:
		return "o dono encomenda"
	return "encomenda em %d degrau%s" % [faltam, "" if faltam == 1 else "s"]

## "1 dia" / "4 dias". O singular é o caso do primeiro dia, que é o que mais
## aparece na tela — e "1 dias" é o tipo de detalhe que faz o painel parecer
## rascunho.
static func _dias_em_texto(quantos: int) -> String:
	return "%d dia" % quantos if quantos == 1 else "%d dias" % quantos


# --- Montagem ---

func _monta() -> void:
	add_child(_titulo("Amizade"))
	for id in estabelecimentos():
		add_child(_ficha(id))

	var nota := Label.new()
	nota.theme_type_variation = &"Micro"
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.text = "A RELAÇÃO SOBE POR CONSTÂNCIA — UMA ENTREGA POR DIA, NÃO VOLUME." \
		+ " SÓ PROMESSA QUEBRADA DERRUBA."
	add_child(nota)
	_mostra_destaque()

func _ficha(id: String) -> Control:
	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"

	var topo := HBoxContainer.new()
	caixa.add_child(topo)

	var nome := Label.new()
	nome.text = _nome_de(id)
	nome.theme_type_variation = &"Micro"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	_nomes[id] = nome

	var selo := _selo_do_degrau()
	topo.add_child(selo)
	_selos[id] = selo

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, ALTURA_DA_BARRA)
	barra.max_value = 1.0
	barra.step = 0.0
	caixa.add_child(barra)
	_barras[id] = barra

	_progressos[id] = _linha(caixa, &"Dado")
	_cotas[id] = _linha(caixa, &"Micro")
	_escadas[id] = _linha(caixa, &"Dado")
	_contratos[id] = _linha(caixa, &"Micro")

	# O diário fica no fim porque é o único bloco que cresce. Em cima da escada
	# ele empurraria a linha que o jogador veio ler.
	var diario := VBoxContainer.new()
	caixa.add_child(diario)
	_diarios[id] = diario
	return caixa

## O selo é `PanelContainer` + `Label` porque as pílulas do tema são estilo de
## painel: a cor mora na variação, e nenhum painel a escreve à mão.
func _selo_do_degrau() -> PanelContainer:
	var pilula := PanelContainer.new()
	pilula.theme_type_variation = &"PilulaNeutra"
	pilula.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var texto := Label.new()
	texto.theme_type_variation = &"Micro"
	pilula.add_child(texto)
	return pilula

func _linha(pai: Node, variacao: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variacao
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(label)
	return label

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label

func _nome_de(id: String) -> String:
	var sistema := _sistema()
	var def := sistema.def_de(id) if sistema != null else null
	return def.nome if def != null and not def.nome.is_empty() else id

func _mostra_destaque() -> void:
	for id: String in _nomes:
		var rotulo := _nomes[id] as Label
		var aqui := id == _destacado
		rotulo.theme_type_variation = &"Rotulo" if aqui else &"Micro"
		rotulo.text = "▸ %s" % _nome_de(id) if aqui else _nome_de(id)


# --- Evento vira tela ---

## O minuto que passa não mexe em amizade: ela anda por entrega, por contrato
## cumprido e por prazo estourado, e nada disso é o relógio. Ignorar o tick é o
## que deixa esta aba de graça em ×60.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	if event is RelacaoSubiuEvent or event is RelacaoCaiuEvent:
		_anota(event)
	_atualiza()

## Guarda o movimento como o jogador o leria: quanto andou, para onde foi e em
## que dia. O delta sai da diferença para o que este painel viu por último —
## o evento carrega o total, não o passo.
func _anota(event: SimEvent) -> void:
	var id := ""
	var total := 0
	var motivo := ""
	if event is RelacaoSubiuEvent:
		var subiu := event as RelacaoSubiuEvent
		id = subiu.estabelecimento
		total = subiu.dias
	else:
		var caiu := event as RelacaoCaiuEvent
		id = caiu.estabelecimento
		total = caiu.dias
		# O evento de queda só existe por um motivo, e ele está no cabeçalho da
		# classe: prazo aceito e estourado. Faltar não desconta nada.
		motivo = " · promessa quebrada"

	var antes := int(_ultimos_dias.get(id, 0))
	_ultimos_dias[id] = total
	var passo := total - antes
	var linha := "dia %d · %s%d → %s%s" % [
		_dia_do_jogo(), "+" if passo >= 0 else "−", absi(passo),
		_dias_em_texto(total), motivo,
	]

	var lista: Array[String] = historico(id).duplicate()
	lista.insert(0, linha)
	while lista.size() > MOVIMENTOS_LEMBRADOS:
		lista.remove_at(lista.size() - 1)
	_historicos[id] = lista

func _atualiza() -> void:
	if _bridge == null:
		return
	for id in estabelecimentos():
		(_barras[id] as ProgressBar).value = fracao(id)
		(_progressos[id] as Label).text = texto_do_progresso(id)
		(_cotas[id] as Label).text = texto_da_cota(id)
		(_escadas[id] as Label).text = texto_da_escada(id)
		(_contratos[id] as Label).text = texto_do_contrato(id)
		_mostra_selo(id)
		_mostra_diario(id)

## A cor do selo conta o estado sem ler: neutro enquanto não subiu nada, verde
## subindo, ouro quando a cota encostou no teto — que é quando a amizade deixa
## de ser o caminho e a compra passa a ser.
func _mostra_selo(id: String) -> void:
	var pilula := _selos[id] as PanelContainer
	var texto := pilula.get_child(0) as Label
	texto.text = texto_do_degrau(id)
	if no_teto(id):
		pilula.theme_type_variation = &"PilulaOuro"
	elif degrau(id) > 0:
		pilula.theme_type_variation = &"PilulaVerde"
	else:
		pilula.theme_type_variation = &"PilulaNeutra"

## O diário só aumenta o pool de rótulos: em ×60 nenhum nó é liberado no meio
## do frame, pelo mesmo motivo da fila do balcão.
func _mostra_diario(id: String) -> void:
	var caixa := _diarios[id] as VBoxContainer
	var linhas := historico(id)
	var usadas := maxi(linhas.size(), 1)
	while caixa.get_child_count() < usadas:
		var label := Label.new()
		label.theme_type_variation = &"Micro"
		caixa.add_child(label)

	for i in caixa.get_child_count():
		var linha := caixa.get_child(i) as Label
		linha.visible = i < usadas
		if not linha.visible:
			continue
		linha.text = linhas[i] if not linhas.is_empty() \
			else "nenhum movimento nesta sessão"


# --- De onde vêm os dados ---

## O sistema é dono das perguntas de regra; achar quem responde é problema de
## quem pergunta. `game/` nunca guarda referência de state — só de quem sabe.
func _sistema() -> SistemaCidade:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaCidade:
			return system as SistemaCidade
	return null

## O dia do calendário, para carimbar o movimento. Sai do snapshot, a mesma
## foto que o save grava.
func _dia_do_jogo() -> int:
	if _bridge == null:
		return 0
	var time: Variant = _bridge.get_world().snapshot().get(SimFactory.CHAVE_TIME, {})
	return int((time as Dictionary).get("dia", 0)) if time is Dictionary else 0
