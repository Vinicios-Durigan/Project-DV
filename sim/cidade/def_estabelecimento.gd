class_name DefEstabelecimento
extends Resource

## Definição de um estabelecimento da cidade — o que o designer edita no
## inspector, em `data/cidade/*.tres`.
##
## Conteúdo é id + catálogo: o `SistemaCidade` não conhece moinho nem padaria.
## Estabelecimento novo é `.tres` novo, zero código — a mesma promessa de
## `CropDef` e `ItemDef`.
##
## ## A receita
##
## `entram` unidades de `item_entrada` viram `saem` unidades de `item_saida`,
## depois de `prazo_minutos` de relógio. A entrega tem que vir em lote cheio
## (múltiplo de `entram`): moer 3 trigo num moinho que mói de 2 em 2 comeria o
## terceiro em silêncio, e item sumindo sem aviso é o pior tipo de bug.
##
## ## Cota e capacidade são números diferentes
##
## `cota` é **sua** e sobe com constância; `capacidade` é do **prédio** e só
## muda comprando (PRINCIPIOS §4). A cota nunca passa da capacidade — e é
## justamente ela encostando no teto que destrava a compra, na wave do dono.
## Por isso os dois campos existem desde já, mesmo com a compra fora do slice:
## registrar agora evita migração depois.
##
## ## A taxa é paga na retirada
##
## `taxa_por_unidade` multiplica as unidades **de entrada** entregues, mas o
## dinheiro só sai quando o jogador busca o produto (`RetirarAction`). Quem
## cobra é o `InventorySystem`, dono do dinheiro — a cidade só diz quanto.
##
## Campo novo aqui nasce com default que **fecha a porta**: uma definição em
## branco tem cota 0 e não beneficia nada. `.tres` pela metade não vira
## estabelecimento trabalhando de graça.

const DIR_PADRAO: String = "res://data/cidade"

## Receita neutra: 1 entra, 1 sai, em 4 horas de jogo.
const ENTRAM_PADRAO: int = 1
const SAEM_PADRAO: int = 1
const PRAZO_PADRAO: int = 240

@export var id: String = ""
@export var nome: String = ""

@export_group("Receita")
## Id do item que o jogador entrega.
@export var item_entrada: String = ""
## Id do item que ele vem buscar.
@export var item_saida: String = ""
## Quantas unidades de entrada formam um lote.
@export_range(1, 99, 1) var entram: int = ENTRAM_PADRAO
## Quantas unidades de saída um lote rende.
@export_range(1, 99, 1) var saem: int = SAEM_PADRAO
## Quanto tempo o lote leva, em minutos de jogo (1440 = um dia).
@export_range(1, 40320, 1) var prazo_minutos: int = PRAZO_PADRAO
## Quanto o estabelecimento cobra por unidade **de entrada**. Pago na retirada.
@export_range(0, 9999, 1) var taxa_por_unidade: int = 0

@export_group("Cota e capacidade")
## Quantas unidades de entrada o jogador pode ter aqui de uma vez, no dia em
## que chega na cidade pela primeira vez.
@export_range(0, 9999, 1) var cota_inicial: int = 0
## O teto do prédio. A cota nunca passa daqui; encostar destrava a compra.
@export_range(0, 9999, 1) var capacidade: int = 0
## Quanto a cota sobe a cada degrau de relação alcançado.
@export_range(0, 999, 1) var cota_por_degrau: int = 0
## Dias com entrega necessários para cada degrau, em ordem crescente.
@export var limiares_relacao: Array[int] = []

@export_group("Contrato")
## Degrau de relação a partir do qual o dono passa a encomendar. Zero libera
## desde o primeiro dia — o default é 1 porque a escada não pula degrau: só
## quem foi constante ganha pedido (PRINCIPIOS §3).
@export_range(0, 9, 1) var contrato_degrau_minimo: int = 1
## Quantos dias o jogador tem para cumprir depois de aceitar. **Zero desliga o
## contrato neste estabelecimento** — é o default que fecha a porta: `.tres`
## sem esta seção preenchida nunca encomenda nada.
@export_range(0, 28, 1) var contrato_prazo_dias: int = 0
## Menos e mais lotes de `item_entrada` que uma encomenda pode pedir.
@export_range(1, 99, 1) var contrato_lotes_min: int = 1
@export_range(1, 99, 1) var contrato_lotes_max: int = 1
## Quanto o contrato paga em cima do preço de venda do item pedido. 1.0 = o
## mesmo do caixote, e aí não haveria motivo para aceitar.
@export_range(1.0, 5.0, 0.05) var contrato_multiplicador: float = 1.0


## Quantos degraus de relação `dias` com entrega já valeram. O limiar conta no
## dia em que é alcançado.
func degrau_com(dias: int) -> int:
	var degrau := 0
	for limiar in limiares_relacao:
		if dias >= limiar:
			degrau += 1
	return degrau

## A cota do jogador com essa constância, já limitada pela capacidade do prédio.
func cota_com(dias: int) -> int:
	return mini(cota_inicial + degrau_com(dias) * cota_por_degrau, capacidade)

## A cota encostou no teto do prédio? É o que destrava a compra na wave do dono.
func cota_no_teto(dias: int) -> bool:
	return capacidade > 0 and cota_com(dias) >= capacidade

## Quantos degraus a escada tem ao todo. Zero é escada nenhuma: a cota nasce e
## morre no valor inicial.
func degraus() -> int:
	return limiares_relacao.size()

## O limiar do próximo degrau, ou `-1` quando a escada acabou.
##
## Não assume `limiares_relacao` em ordem: pega o menor limiar ainda não
## alcançado. O campo é uma lista digitada à mão no inspector, e uma linha fora
## de ordem não pode fazer a tela mentir sobre o que falta.
func proximo_limiar(dias: int) -> int:
	var menor := -1
	for limiar in limiares_relacao:
		if dias >= limiar:
			continue
		if menor < 0 or limiar < menor:
			menor = limiar
	return menor

## Quantos dias com entrega faltam para o próximo degrau, ou `-1` no topo.
##
## `-1` e não `0`: "não falta nada" e "a escada acabou" são coisas diferentes, e
## quem desenha precisa poder escrever "no topo" em vez de "faltam 0 dias".
func dias_para_o_proximo(dias: int) -> int:
	var limiar := proximo_limiar(dias)
	return -1 if limiar < 0 else maxi(limiar - dias, 0)

## Quanto a cota sobe quando o próximo degrau cair.
##
## Zero no topo da escada — e zero também quando a cota já encostou na
## capacidade: o degrau vem, mas não cabe mais nada dentro do prédio. Daí em
## diante quem levanta o número é a compra, não a amizade (PRINCIPIOS §4).
func ganho_do_proximo_degrau(dias: int) -> int:
	var limiar := proximo_limiar(dias)
	if limiar < 0:
		return 0
	return cota_com(limiar) - cota_com(dias)

## A entrega vem em lote cheio? Sobra não é aceita — ela sumiria sem virar nada.
func lote_valido(qtd: int) -> bool:
	return qtd > 0 and qtd % entram == 0

## Quanto sai de `qtd` unidades de entrada. Sobra é descartada no cálculo —
## quem garante que não há sobra é `lote_valido`, antes.
func saida_de(qtd: int) -> int:
	if qtd <= 0:
		return 0
	@warning_ignore("integer_division")
	var lotes := qtd / entram
	return lotes * saem

## Quanto custa beneficiar `qtd` unidades de entrada.
func taxa_de(qtd: int) -> int:
	return maxi(qtd, 0) * taxa_por_unidade

## Este dono já encomenda, com essa constância? Prazo zero desliga o contrato
## no `.tres`; o degrau mínimo é a escada — só quem apareceu ganha pedido.
func encomenda_com(dias: int) -> bool:
	return contrato_prazo_dias > 0 and degrau_com(dias) >= contrato_degrau_minimo

## Quanto o contrato paga por `qtd` unidades cujo preço de venda é
## `preco_unitario`. O total é combinado na oferta e não se recalcula depois:
## rebalancear o `.tres` no meio do prazo não muda o que foi prometido.
func pagamento_de(qtd: int, preco_unitario: int) -> int:
	return roundi(maxi(qtd, 0) * maxi(preco_unitario, 0) * contrato_multiplicador)


## Carrega todo `.tres` do diretório em `id -> DefEstabelecimento`.
## Diretório inexistente não é erro: catálogo vazio.
##
## É estática e não uma classe `CatalogoEstabelecimentos` porque não há o que
## uma classe dessas guardaria além do dicionário: o dono das definições é o
## `SistemaCidade`, e o painel as lê por ele. Definição é leitura livre — o que
## é proibido é ler *state* alheio.
static func carrega_de(dir_path: String = DIR_PADRAO) -> Dictionary:
	var defs: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return defs
	var nomes := dir.get_files()
	nomes.sort()
	for nome in nomes:
		# em build exportada o .tres vira .tres.remap
		var arquivo := nome.trim_suffix(".remap")
		if not arquivo.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(dir_path.path_join(arquivo)) as DefEstabelecimento
		if def == null or def.id.is_empty():
			continue
		defs[def.id] = def
	return defs
