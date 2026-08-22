class_name MedidorDia
extends VBoxContainer

## O instrumento que mede como o dia foi gasto: andando, na fazenda, na cidade
## ou parado. E, ao dormir, o resumo do dia junto do resumo de vendas.
##
## ## Por que ele existe
##
## A wave 10 deixou uma pergunta em aberto: **a cidade está longe demais?** Os
## 15 tiles de caminho foram um chute. Discutir isso de cabeça não resolve —
## alguém acha longe, alguém acha curto, e o número não muda.
##
## Este painel troca o achismo por dado. Depois de um dia jogado, dá para ler
## "40% do dia foi andando" e decidir com o número na mão. Se a caminhada comer
## metade do dia, o caminho encolhe; se não aparecer no gráfico, ele pode
## crescer.
##
## ## Por que ele NÃO está em `sim/`
##
## Porque ele cronometra **tempo de parede da sessão**, não tempo de jogo. Isso
## não é regra: não muda o que a sim decide, não entra no save e não vira
## evento. Duas pessoas jogando o mesmo dia com o mesmo save teriam medições
## diferentes — o que é exatamente o oposto de uma sim determinística.
##
## É por isso que `game.md` proíbe acumular `delta` para mexer em regra e este
## arquivo acumula `delta` mesmo assim: aqui o `delta` é o objeto de medida, não
## o motor do jogo. O relógio do jogo continua sendo o tick da sim, e é dele que
## sai a virada do dia que zera este cronômetro.

## As quatro categorias. Uma só por segundo — não existe segundo contado duas
## vezes, e é isso que faz o total fechar.
const ANDANDO: String = "andando"
const NA_FAZENDA: String = "na_fazenda"
const NA_CIDADE: String = "na_cidade"
const PARADO: String = "parado"

const CATEGORIAS: Array[String] = [ANDANDO, NA_FAZENDA, NA_CIDADE, PARADO]

## O nome de cada categoria na tela.
const NOMES: Dictionary = {
	ANDANDO: "andando",
	NA_FAZENDA: "na fazenda",
	NA_CIDADE: "na cidade",
	PARADO: "parado",
}

## Largura da barrinha de proporção, em pixels.
const BARRA_LARGURA: float = 120.0

var _bridge: SimBridge
var _mundo: MundoEsboco

## Segundos de parede por categoria, no dia corrente.
var _segundos: Dictionary = {}
## O que o caixote vendeu nesta madrugada. Zera junto com o dia — dia sem venda
## mostra zero, e não o total de ontem.
var _vendas_linhas: Array = []
var _vendas_total: int = 0
## O último dia fechado, pronto para leitura: contagens + vendas + o número do
## dia.
var _resumo: Dictionary = {}

var _linhas: Dictionary = {}
var _rotulo_resumo: Label


func _ready() -> void:
	_zera()
	add_child(_titulo("O dia até agora"))
	for categoria in CATEGORIAS:
		_linhas[categoria] = _monta_linha(String(NOMES[categoria]))

	add_child(_titulo("Ao dormir"))
	_rotulo_resumo = Label.new()
	_rotulo_resumo.theme_type_variation = &"Dado"
	_rotulo_resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_resumo.text = "durma para ver o resumo do dia"
	add_child(_rotulo_resumo)

	set_process(false)

## Padrão 3: recebe o fio e escuta. O mundo entra na conta porque só ele sabe
## se o jogador está andando — e andar é apresentação, não estado da sim.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_bridge.sim_event.connect(_on_sim_event)
	_mundo = _acha_mundo()
	set_process(true)
	_mostra()


# --- Leitura ---

func segundos_em(categoria: String) -> float:
	return float(_segundos.get(categoria, 0.0))

func total() -> float:
	var soma := 0.0
	for categoria in CATEGORIAS:
		soma += segundos_em(categoria)
	return soma

## A fatia da categoria no dia, de 0 a 1. Dia vazio não divide por zero.
func fracao_de(categoria: String) -> float:
	var soma := total()
	if soma <= 0.0:
		return 0.0
	return segundos_em(categoria) / soma

## O resumo do último dia fechado: as quatro contagens, o número do dia e as
## linhas de venda. Vazio até a primeira dormida.
func ultimo_resumo() -> Dictionary:
	return _resumo


# --- Contagem ---

## Em que categoria cai este segundo. Andar ganha do lugar: a pergunta que o
## medidor responde é "quanto do dia foi deslocamento", e deslocamento na
## fazenda também é deslocamento.
##
## O caminho não é local nenhum (wave 10) — quem está nele e não anda está
## parado, o que é exatamente o que se quer ver no número.
func categoria_de(local: String, andando: bool) -> String:
	if andando:
		return ANDANDO
	match local:
		EstadoLocais.FAZENDA:
			return NA_FAZENDA
		EstadoLocais.CIDADE:
			return NA_CIDADE
		_:
			return PARADO

func acumula(segundos: float, categoria: String) -> void:
	_segundos[categoria] = segundos_em(categoria) + segundos


func _process(delta: float) -> void:
	if _mundo == null:
		return
	acumula(delta, categoria_de(_mundo.local_visual(), _mundo.esta_andando()))
	_mostra()


# --- Eventos da sim ---

## Duas metades do resumo, em dois eventos. `ItemsSoldEvent` é o passo 1 da
## sequência de dormir e `DayEndedEvent` é o último — quando o segundo chega, o
## primeiro já passou, e o painel junta os dois.
func _on_sim_event(event: SimEvent) -> void:
	if event is ItemsSoldEvent:
		var venda := event as ItemsSoldEvent
		_vendas_linhas = venda.linhas
		_vendas_total = venda.total
		return
	if event is DayEndedEvent:
		_fecha_o_dia(event as DayEndedEvent)

func _fecha_o_dia(dia: DayEndedEvent) -> void:
	_resumo = _segundos.duplicate()
	_resumo["dia"] = dia.dia_encerrado
	_resumo["estacao"] = dia.estacao
	_resumo["vendas_linhas"] = _vendas_linhas
	_resumo["vendas_total"] = _vendas_total
	_zera()
	_mostra()

func _zera() -> void:
	for categoria in CATEGORIAS:
		_segundos[categoria] = 0.0
	_vendas_linhas = []
	_vendas_total = 0


# --- Tela ---

func _mostra() -> void:
	for categoria: String in _linhas:
		var linha: Dictionary = _linhas[categoria]
		var valor: Label = linha["valor"]
		valor.text = "%s  %3d%%" % [_relogio(segundos_em(categoria)),
			int(round(fracao_de(categoria) * 100.0))]
		var barra: ProgressBar = linha["barra"]
		barra.value = fracao_de(categoria) * 100.0

	if _rotulo_resumo != null and not _resumo.is_empty():
		_rotulo_resumo.text = _texto_do_resumo()

## O resumo do dia como o jogador vê ao dormir: as vendas linha a linha (o
## formato do GAMEPLAY §6) e, embaixo, para onde o dia foi.
##
## As linhas de venda vêm prontas dentro do evento — nenhuma conta e nenhuma
## consulta ao catálogo deste lado.
func _texto_do_resumo() -> String:
	var partes: Array[String] = []
	partes.append("Dia %d — %s" % [
		int(_resumo.get("dia", 0)),
		String(_resumo.get("estacao", "")).capitalize(),
	])

	var linhas: Array = _resumo.get("vendas_linhas", [])
	if linhas.is_empty():
		partes.append("caixote vazio")
	else:
		for entrada: Variant in linhas:
			var linha: ItemsSoldEvent.Linha = entrada
			partes.append("%s  %d × %d = %d" % [
				linha.item_id, linha.qtd, linha.preco_unitario, linha.subtotal,
			])
	partes.append("total: %dg" % int(_resumo.get("vendas_total", 0)))

	partes.append("")
	for categoria in CATEGORIAS:
		partes.append("%s: %s" % [
			String(NOMES[categoria]),
			_relogio(float(_resumo.get(categoria, 0.0))),
		])
	return "\n".join(partes)

## Segundos de parede em mm:ss. Número é sempre mono — quem garante isso é a
## variação `Dado` do tema.
func _relogio(segundos: float) -> String:
	var inteiros := int(segundos)
	return "%02d:%02d" % [inteiros / 60, inteiros % 60]

func _monta_linha(nome: String) -> Dictionary:
	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"
	add_child(caixa)

	var topo := HBoxContainer.new()
	caixa.add_child(topo)

	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(rotulo)

	var valor := Label.new()
	valor.theme_type_variation = &"Dado"
	topo.add_child(valor)

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(BARRA_LARGURA, 8)
	barra.max_value = 100.0
	caixa.add_child(barra)

	return {"valor": valor, "barra": barra}

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label

## O mundo de esboço: sobe-se a árvore até achar quem sabe respondê-lo (a casca
## do playground). Nenhum painel guarda caminho de nó.
func _acha_mundo() -> MundoEsboco:
	var no := get_parent()
	while no != null:
		if no.has_method("get_mundo"):
			return no.call("get_mundo") as MundoEsboco
		no = no.get_parent()
	return null
