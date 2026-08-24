class_name PainelOficios
extends VBoxContainer

## A aba Ofícios: o que cada ofício praticou, quanto falta para o próximo nível,
## quantos pontos sobraram e o tabuleiro inteiro de vantagens.
##
## ## Por que uma aba, e não um contador no rail
##
## Progressão sem tela é progressão que não existe. O jogador precisa ver a barra
## andar para saber que o trabalho de hoje virou alguma coisa — e precisa ver o
## tabuleiro **inteiro**, inclusive o que não dá para comprar, para a escolha
## pesar. Um número solto contaria o XP sem contar a decisão, que é a mecânica.
##
## ## Ela é o instrumento de calibragem da wave
##
## Todos os números da wave 17 são chute: limiares, custos e tetos. O dado que
## resolve o chute é **quantos pontos uma estação rende** — se os 8 chegam cedo
## demais, o tabuleiro acaba antes do jogo; se não chegam, a árvore é enfeite.
## É esta tela que mostra isso depois de uma estação jogada ponta a ponta.
##
## ## Nenhum número é calculado aqui
##
## Custo, teto, limiar, fração da barra e o motivo da recusa são perguntas de
## **regra**, e todas saem do `SistemaOficios` — do mesmo jeito que o custo de
## arar sai do corpo. Este arquivo pergunta e formata; quando a aba e a sim
## discordarem, quem errou é este arquivo (CLAUDE.md).
##
## ## O botão pergunta antes
##
## A compra é permanente e o ponto não volta. `pode_comprar()` responde antes do
## clique, mesma receita da mesa do corpo — clique que queima recurso em silêncio
## é o pior tipo de bug.

## O nome de cada ofício na tela. Os ids são da sim; o texto é daqui.
const NOMES_DOS_OFICIOS: Dictionary = {
	SistemaOficios.LAVOURA: "Lavoura",
	SistemaOficios.CAMPO: "Campo",
}

## O que cada ofício pratica, em uma linha. É legenda, não regra: quem decide o
## que dá XP é a tabela do sistema.
const RESUMOS: Dictionary = {
	SistemaOficios.LAVOURA: "arar, plantar, regar e colher",
	SistemaOficios.CAMPO: "limpar mato, pedra, toco e árvore",
}

## O nome e a promessa de cada vantagem. O efeito real mora no sistema que o
## cobra; aqui é a frase que o jogador lê antes de gastar o ponto.
const NOMES_DAS_VANTAGENS: Dictionary = {
	SistemaOficios.MAOS_LEVES: "Mãos leves",
	SistemaOficios.REGA_FUNDA: "Rega funda",
	SistemaOficios.COLHEITA_ESPECIALIZADA: "Colheita especializada",
	SistemaOficios.COSTAS_LARGAS: "Costas largas",
}

const PROMESSAS: Dictionary = {
	SistemaOficios.MAOS_LEVES: "plantar, depois colher, deixam de cansar",
	SistemaOficios.REGA_FUNDA: "os primeiros canteiros do dia seguram a água até depois de amanhã",
	SistemaOficios.COLHEITA_ESPECIALIZADA: "uma cultura rende +1 por colheita, para sempre",
	SistemaOficios.COSTAS_LARGAS: "o corpo aguenta mais",
}

## O que a sim responde quando diz não, em português. Motivo é id de máquina; a
## frase é daqui.
const MOTIVOS: Dictionary = {
	SistemaOficios.MOTIVO_SEM_PONTO: "sem ponto neste ofício",
	SistemaOficios.MOTIVO_NO_TETO: "já está no teto",
	SistemaOficios.MOTIVO_VANTAGEM_DESCONHECIDA: "vantagem desconhecida",
	SistemaOficios.MOTIVO_CULTURA_AUSENTE: "escolha uma cultura primeiro",
	SistemaOficios.MOTIVO_CULTURA_DESCONHECIDA: "essa cultura não existe",
}

## Altura da barra de XP, na grade de 4px. Menor que a do corpo: aqui são duas,
## e nenhuma delas decide o minuto seguinte.
const ALTURA_DA_BARRA: float = 12.0

var _bridge: SimBridge

## A cultura escolhida para a Colheita especializada, antes do clique. Só existe
## deste lado até a compra: quem carimba de verdade é a sim.
var _cultura: String = ""

var _barras: Dictionary = {}
var _cabecalhos: Dictionary = {}
var _linhas: Dictionary = {}
var _botoes: Dictionary = {}
var _seletor: OptionButton
var _aviso: Label
var _ultimo_aviso: String = ""


## Padrão 3: recebe o fio e escuta. Quem entrega é o `PainelMochila` — esta aba
## é conteúdo do modal dele.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_monta()
	_bridge.sim_event.connect(_on_sim_event)
	atualiza()


# --- Leitura: tudo o que é regra vem do sistema ---

## Os ofícios que a sim conhece, na ordem dela. A lista não mora nesta tela:
## ofício novo aparece aqui sozinho.
func oficios() -> Array[String]:
	return SistemaOficios.OFICIOS

## As vantagens deste ofício, na ordem do tabuleiro.
func vantagens(oficio: String) -> Array[String]:
	var sistema := _sistema()
	return sistema.vantagens_do_oficio(oficio) if sistema != null else [] as Array[String]

func xp(oficio: String) -> int:
	var sistema := _sistema()
	return sistema.xp_de(SimFactory.PLAYER_PADRAO, oficio) if sistema != null else 0

func nivel(oficio: String) -> int:
	var sistema := _sistema()
	return sistema.nivel_de(SimFactory.PLAYER_PADRAO, oficio) if sistema != null else 0

func nivel_maximo(oficio: String) -> int:
	var sistema := _sistema()
	return sistema.nivel_maximo(oficio) if sistema != null else 0

func pontos(oficio: String) -> int:
	var sistema := _sistema()
	return sistema.pontos_de(SimFactory.PLAYER_PADRAO, oficio) if sistema != null else 0

## Quanto falta para o próximo nível. Zero no topo da escada.
func falta(oficio: String) -> int:
	var sistema := _sistema()
	return sistema.xp_para_o_proximo(SimFactory.PLAYER_PADRAO, oficio) if sistema != null else 0

## Quanto do nível atual já foi andado, de 0 a 1. A conta é do sistema: quem
## conhece os limiares é o dono da tabela.
func fracao(oficio: String) -> float:
	var sistema := _sistema()
	return sistema.fracao_do_nivel(SimFactory.PLAYER_PADRAO, oficio) if sistema != null else 0.0

func custo(vantagem_id: String) -> int:
	var sistema := _sistema()
	return sistema.custo_da_vantagem(vantagem_id) if sistema != null else 0

func teto(vantagem_id: String) -> int:
	var sistema := _sistema()
	return sistema.teto_da_vantagem(vantagem_id) if sistema != null else 0

func nivel_da_vantagem(vantagem_id: String) -> int:
	var sistema := _sistema()
	return sistema.nivel_da_vantagem(SimFactory.PLAYER_PADRAO, vantagem_id) if sistema != null else 0

## Esta vantagem pede uma cultura junto do ponto?
func exige_cultura(vantagem_id: String) -> bool:
	var sistema := _sistema()
	return sistema.exige_cultura(vantagem_id) if sistema != null else false

## A sim deixa comprar isto agora? A resposta é dela, nunca um `if` daqui.
func pode_comprar(vantagem_id: String) -> bool:
	var sistema := _sistema()
	return sistema.pode_comprar(SimFactory.PLAYER_PADRAO, vantagem_id, _cultura) \
		if sistema != null else false

## O motivo da recusa, em id de máquina — vazio quando a compra passa.
func motivo(vantagem_id: String) -> String:
	var sistema := _sistema()
	return sistema.recusa_de(SimFactory.PLAYER_PADRAO, vantagem_id, _cultura) \
		if sistema != null else ""

## A cultura já carimbada pela sim, ou `""` se ninguém se especializou.
func cultura_carimbada() -> String:
	var sistema := _sistema()
	return sistema.cultura_de(SimFactory.PLAYER_PADRAO) if sistema != null else ""

## As culturas que dá para escolher. Saem do catálogo, então cultura nova em
## `.tres` aparece nesta lista sozinha.
func culturas() -> Array[String]:
	if _bridge == null:
		return []
	return _bridge.get_crop_catalog().ids()

## A cultura selecionada na tela, ainda não comprada.
func cultura_escolhida() -> String:
	return _cultura

## Quantas linhas o tabuleiro está desenhando.
func linhas_do_tabuleiro() -> int:
	return _linhas.size()

## O que a sim respondeu da última vez que ela disse não.
func ultimo_aviso() -> String:
	return _ultimo_aviso


# --- Padrão 2: o botão vira ação ---

## Escolhe a cultura da especialização, antes do clique. Só muda esta tela — quem
## carimba de verdade é a sim, e só quando a compra passar.
func escolhe_cultura(cultura: String) -> void:
	_cultura = cultura
	atualiza()

## Compra. Pergunta antes porque a escolha é permanente: um clique sem ponto
## queimaria nada, mas um clique numa cultura errada queimaria dois pontos para
## sempre.
func compra(vantagem_id: String) -> void:
	if not pode_comprar(vantagem_id):
		_mostra_aviso("a sim disse não: %s" % texto_do_motivo(vantagem_id))
		return
	var acao := EscolherVantagemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.vantagem_id = vantagem_id
	acao.cultura = _cultura
	_bridge.dispatch(acao)


# --- Texto ---

func nome_do_oficio(oficio: String) -> String:
	return String(NOMES_DOS_OFICIOS.get(oficio, oficio))

func nome_da_vantagem(vantagem_id: String) -> String:
	return String(NOMES_DAS_VANTAGENS.get(vantagem_id, vantagem_id))

func texto_do_motivo(vantagem_id: String) -> String:
	var id := motivo(vantagem_id)
	return String(MOTIVOS.get(id, id))

## "Lavoura · nível 2 · 3 pontos · faltam 360". No topo da escada o "faltam" some:
## um número que nunca chega seria a barra mentindo.
func texto_do_oficio(oficio: String) -> String:
	var partes: Array[String] = [
		"%s · nível %d/%d" % [nome_do_oficio(oficio), nivel(oficio), nivel_maximo(oficio)],
		"%d ponto%s" % [pontos(oficio), "" if pontos(oficio) == 1 else "s"],
	]
	var quanto := falta(oficio)
	partes.append("faltam %d" % quanto if quanto > 0 else "no topo")
	return " · ".join(partes)

## "Mãos leves · 1 ponto · 1/2". A fração é o que já foi comprado contra o teto —
## é ela que mostra que o tabuleiro não fecha.
func texto_da_vantagem(vantagem_id: String) -> String:
	return "%s · %d ponto%s · %d/%d" % [
		nome_da_vantagem(vantagem_id),
		custo(vantagem_id), "" if custo(vantagem_id) == 1 else "s",
		nivel_da_vantagem(vantagem_id), teto(vantagem_id),
	]

## A promessa da vantagem, ou o motivo pelo qual ela não dá para comprar agora. O
## motivo ganha da promessa: quem não pode comprar quer saber por quê.
func texto_de_apoio(vantagem_id: String) -> String:
	if nivel_da_vantagem(vantagem_id) >= teto(vantagem_id):
		return "comprada — e não volta"
	if not pode_comprar(vantagem_id):
		return texto_do_motivo(vantagem_id)
	return String(PROMESSAS.get(vantagem_id, ""))


# --- Montagem ---

func _monta() -> void:
	add_child(_titulo("Ofícios"))

	for oficio in oficios():
		_monta_oficio(oficio)

	_monta_seletor()

	_aviso = Label.new()
	_aviso.theme_type_variation = &"Micro"
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)

	var nota := Label.new()
	nota.theme_type_variation = &"Micro"
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.text = "PONTO É PRESO NO OFÍCIO QUE O GANHOU, E VANTAGEM COMPRADA NÃO" \
		+ " VOLTA. NUNCA DÁ PARA TER TUDO."
	add_child(nota)

func _monta_oficio(oficio: String) -> void:
	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"
	add_child(caixa)

	var cabecalho := Label.new()
	cabecalho.theme_type_variation = &"Dado"
	caixa.add_child(cabecalho)
	_cabecalhos[oficio] = cabecalho

	var barra := MedidorEstamina.Barra.new()
	barra.custom_minimum_size = Vector2(0, ALTURA_DA_BARRA)
	caixa.add_child(barra)
	_barras[oficio] = barra

	var resumo := Label.new()
	resumo.theme_type_variation = &"Micro"
	resumo.text = String(RESUMOS.get(oficio, "")).to_upper()
	caixa.add_child(resumo)

	for vantagem_id in vantagens(oficio):
		_monta_vantagem(caixa, vantagem_id)

## Uma linha do tabuleiro: o que é, quanto custa, o que promete e o botão.
func _monta_vantagem(caixa: VBoxContainer, vantagem_id: String) -> void:
	var linha := HBoxContainer.new()
	caixa.add_child(linha)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(coluna)

	var rotulo := Label.new()
	coluna.add_child(rotulo)

	var apoio := Label.new()
	apoio.theme_type_variation = &"Micro"
	apoio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(apoio)

	var botao := Button.new()
	botao.text = "Comprar"
	botao.pressed.connect(compra.bind(vantagem_id))
	linha.add_child(botao)

	_linhas[vantagem_id] = [rotulo, apoio]
	_botoes[vantagem_id] = botao

## O seletor da especialização. Uma lista, e não um campo de texto: a escolha é
## permanente, e digitar "rabanet" queimaria dois pontos para sempre.
func _monta_seletor() -> void:
	add_child(_titulo("A cultura da especialização"))

	_seletor = OptionButton.new()
	_seletor.item_selected.connect(_on_cultura_selecionada)
	add_child(_seletor)

func _on_cultura_selecionada(indice: int) -> void:
	var lista := culturas()
	if indice < 0 or indice >= lista.size():
		return
	escolhe_cultura(lista[indice])

func _mostra_aviso(texto: String) -> void:
	_ultimo_aviso = texto
	if _aviso != null:
		_aviso.text = texto

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label


# --- Evento vira tela ---

## O minuto que passa não mexe em ofício nenhum: XP anda por trabalho feito.
## Ignorar o tick é o que deixa esta aba de graça em ×60.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	if event is ActionRejectedEvent:
		var recusa := event as ActionRejectedEvent
		if recusa.acao == "EscolherVantagemAction":
			_mostra_aviso("a sim recusou a compra: %s" % String(MOTIVOS.get(
				recusa.motivo, recusa.motivo)))
	atualiza()

## Redesenha a aba inteira. Pública porque o teste e a casca precisam pedir o
## redesenho depois de mexer no mundo por fora do sinal.
func atualiza() -> void:
	if _bridge == null:
		return
	for oficio: String in _cabecalhos:
		(_cabecalhos[oficio] as Label).text = texto_do_oficio(oficio)
		(_barras[oficio] as MedidorEstamina.Barra).mostra(fracao(oficio), _cor(oficio))

	for vantagem_id: String in _linhas:
		var partes: Array = _linhas[vantagem_id]
		(partes[0] as Label).text = texto_da_vantagem(vantagem_id)
		(partes[1] as Label).text = texto_de_apoio(vantagem_id)
		(_botoes[vantagem_id] as Button).disabled = not pode_comprar(vantagem_id)

	_atualiza_seletor()

## A lista de culturas e o que está escolhido. Depois da compra ela trava no que
## a sim carimbou: a especialização é de uma cultura só, e ela não troca.
func _atualiza_seletor() -> void:
	if _seletor == null:
		return
	var lista := culturas()
	if _seletor.item_count != lista.size():
		_seletor.clear()
		for cultura in lista:
			_seletor.add_item(_nome_da_cultura(cultura))

	var carimbada := cultura_carimbada()
	if not carimbada.is_empty():
		_cultura = carimbada
		_seletor.disabled = true
	var indice := lista.find(_cultura)
	if indice >= 0:
		_seletor.selected = indice

func _nome_da_cultura(crop_id: String) -> String:
	if _bridge == null:
		return crop_id
	var def := _bridge.get_crop_catalog().get_def(crop_id)
	return def.nome if def != null and not def.nome.is_empty() else crop_id

## Verde enquanto anda, ouro perto do próximo nível. É leitura, não regra: a
## fração que ela pinta vem do sistema.
func _cor(oficio: String) -> Color:
	return Paleta.OURO if fracao(oficio) >= 0.75 else Paleta.VERDE


# --- De onde vêm os dados ---

## O sistema é dono das perguntas de regra; achar quem responde é problema de
## quem pergunta. `game/` nunca guarda referência de state — só de quem sabe.
func _sistema() -> SistemaOficios:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaOficios:
			return system as SistemaOficios
	return null
