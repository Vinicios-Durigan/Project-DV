extends GutTest

## O estabelecimento é conteúdo, não código: `data/cidade/*.tres` editado no
## inspector, como cultura e item.
##
## Duas coisas moram aqui e não podem escapar para o sistema:
##
## - **a receita** — o que entra, o que sai, em que proporção, em quanto tempo e
##   por qual taxa. Estabelecimento novo é `.tres` novo, zero código;
## - **a escada da relação** — quantos dias com entrega valem cada degrau e
##   quanto a cota sobe em cada um. `cota` é sua e sobe com amizade;
##   `capacidade` é do prédio e só muda comprando (PRINCIPIOS §4). São números
##   diferentes de propósito, e a cota **nunca** passa da capacidade: quando ela
##   encosta no teto, é isso que destrava a compra na wave do dono.
##
## Todo campo nasce com default que **fecha a porta**, não que abre: uma
## definição em branco tem cota 0 e não aceita entrega nenhuma. `.tres` pela
## metade não vira estabelecimento que trabalha de graça.

var _defs: Dictionary
var _items: ItemCatalog


func before_each() -> void:
	_defs = DefEstabelecimento.carrega_de()
	_items = ItemCatalog.new()
	_items.load_from_dir()

func _def(id: String) -> DefEstabelecimento:
	return _defs.get(id, null) as DefEstabelecimento


# --- Defaults ---

func test_definicao_em_branco_e_inerte() -> void:
	var def := DefEstabelecimento.new()
	assert_eq(def.cota_com(0), 0, "sem capacidade não há cota")
	assert_eq(def.cota_com(9999), 0, "constância nenhuma abre um prédio que não existe")
	assert_false(def.cota_no_teto(0), "prédio de capacidade 0 não destrava compra nenhuma")
	assert_eq(def.entram, 1, "1 por 1 é a receita neutra")
	assert_eq(def.saem, 1)
	assert_eq(def.taxa_de(10), 0, "taxa nasce em zero")
	assert_gt(def.prazo_minutos, 0, "prazo zero seria beneficiamento instantâneo")

func test_saida_e_taxa_saem_da_receita() -> void:
	var def := DefEstabelecimento.new()
	def.entram = 2
	def.saem = 1
	def.taxa_por_unidade = 5

	assert_eq(def.saida_de(6), 3, "6 entram de 2 em 2, saem 3")
	assert_eq(def.taxa_de(6), 30, "a taxa é por unidade de entrada")
	assert_eq(def.saida_de(0), 0)

func test_lote_incompleto_nao_e_lote() -> void:
	var def := DefEstabelecimento.new()
	def.entram = 2

	assert_true(def.lote_valido(2), "um lote cheio")
	assert_true(def.lote_valido(4), "dois lotes cheios")
	assert_false(def.lote_valido(3),
		"3 não é múltiplo de 2 — moer 3 comeria o terceiro trigo em silêncio")
	assert_false(def.lote_valido(0), "nada não é entrega")
	assert_false(def.lote_valido(-2), "quantidade negativa não existe")


# --- A escada da relação ---

func test_cota_sobe_um_degrau_por_limiar_cruzado() -> void:
	var def := DefEstabelecimento.new()
	def.cota_inicial = 6
	def.cota_por_degrau = 4
	def.capacidade = 99
	def.limiares_relacao = [3, 7, 14]

	assert_eq(def.degrau_com(0), 0, "dia zero, nenhum degrau")
	assert_eq(def.degrau_com(2), 0, "faltou um dia")
	assert_eq(def.degrau_com(3), 1, "o limiar conta no dia em que é alcançado")
	assert_eq(def.degrau_com(6), 1)
	assert_eq(def.degrau_com(7), 2)
	assert_eq(def.degrau_com(14), 3)
	assert_eq(def.degrau_com(500), 3, "acabaram os degraus, a escada para")

	assert_eq(def.cota_com(0), 6, "cota inicial")
	assert_eq(def.cota_com(3), 10)
	assert_eq(def.cota_com(7), 14)
	assert_eq(def.cota_com(14), 18)

func test_cota_nunca_passa_da_capacidade_do_predio() -> void:
	var def := DefEstabelecimento.new()
	def.cota_inicial = 6
	def.cota_por_degrau = 10
	def.capacidade = 12
	def.limiares_relacao = [3, 7]

	assert_eq(def.cota_com(3), 12, "16 não cabe num prédio de 12")
	assert_eq(def.cota_com(7), 12, "e continua não cabendo")
	assert_false(def.cota_no_teto(0), "no começo sobra prédio")
	assert_true(def.cota_no_teto(3),
		"cota encostando na capacidade é o que destrava a compra do prédio")


# --- Os dois estabelecimentos de data/cidade/ ---

func test_moinho_e_padaria_carregam_do_disco() -> void:
	assert_eq(_defs.size(), 2, "os 2 estabelecimentos do slice")
	assert_not_null(_def("moinho"))
	assert_not_null(_def("padaria"))
	for id: String in _defs:
		var def := _def(id)
		assert_eq(def.id, id, "a chave é o id da própria definição")
		assert_false(def.nome.is_empty(), "%s: sem nome não dá para mostrar" % id)

func test_diretorio_inexistente_nao_e_erro() -> void:
	assert_eq(DefEstabelecimento.carrega_de("res://data/nao_existe").size(), 0,
		"catálogo vazio, não crash")

func test_a_padaria_come_a_saida_do_moinho() -> void:
	assert_eq(_def("moinho").item_entrada, "trigo")
	assert_eq(_def("moinho").item_saida, "farinha")
	assert_eq(_def("padaria").item_entrada, _def("moinho").item_saida,
		"a cadeia só prova dependência se um degrau come o outro")
	assert_eq(_def("padaria").item_saida, "pao")

func test_todo_item_da_receita_existe_no_catalogo() -> void:
	for id: String in _defs:
		var def := _def(id)
		assert_true(_items.has(def.item_entrada),
			"%s: pede um item que não existe" % id)
		assert_true(_items.has(def.item_saida),
			"%s: fabrica um item que não existe" % id)

func test_beneficiar_paga_a_taxa_com_folga() -> void:
	for id: String in _defs:
		var def := _def(id)
		var entrada := _items.get_def(def.item_entrada).preco_venda * def.entram
		var saida := _items.get_def(def.item_saida).preco_venda * def.saem
		assert_gt(saida, entrada + def.taxa_de(def.entram),
			"%s: se a taxa come o valor agregado, ninguém entrega duas vezes" % id)

func test_prazo_custa_tempo_mas_nao_a_estacao() -> void:
	for id: String in _defs:
		var def := _def(id)
		assert_gt(def.prazo_minutos, 0, "%s: beneficiamento instantâneo não custa decisão" % id)
		assert_lt(def.prazo_minutos, TimeSystem.MINUTOS_POR_DIA,
			"%s: no slice o prazo cabe no dia — 'volte amanhã' é wave do contrato" % id)

func test_a_escada_dos_dois_termina_no_teto_do_predio() -> void:
	for id: String in _defs:
		var def := _def(id)
		assert_gt(def.cota_inicial, 0, "%s: cota inicial zero trancaria o jogador de fora" % id)
		assert_lt(def.cota_inicial, def.capacidade,
			"%s: começar no teto entregaria a compra do prédio de graça" % id)
		assert_false(def.limiares_relacao.is_empty(), "%s: sem limiar a relação não sobe" % id)
		var ultimo: int = def.limiares_relacao[def.limiares_relacao.size() - 1]
		assert_true(def.cota_no_teto(ultimo),
			"%s: o último degrau tem que encostar na capacidade — senão a compra nunca destrava" % id)

func test_os_limiares_sobem() -> void:
	for id: String in _defs:
		var def := _def(id)
		var anterior := 0
		for limiar: int in def.limiares_relacao:
			assert_gt(limiar, anterior, "%s: limiar fora de ordem pula degrau" % id)
			anterior = limiar
