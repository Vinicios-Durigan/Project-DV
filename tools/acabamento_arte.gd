class_name AcabamentoArte
extends RefCounted

## O que fazer com um recorte depois de achá-lo: tamanho, alinhamento, alfa e
## paleta.
##
## Existe porque virou muita opção para passar solta como parâmetro, e porque a
## janela e a linha de comando precisam montar exatamente a mesma coisa — se
## divergirem, o artista vê um resultado na tela e outro no arquivo.
##
## Os dois presets cobrem quase todo caso real:
##
## - `pixel_art()` — a folha já é pixel art no tamanho certo. Não reamostra,
##   não mexe em cor: um pixel do arquivo é um pixel do jogo.
## - `arte_gerada()` — a imagem veio grande e suave, de IA ou de pintura
##   digital. Reduz, corta o alfa e diminui a paleta até o resultado parecer
##   pixel art de verdade.

## Quantas cores um ícone de 16×16 aguenta antes de parecer sujo. Pixel art de
## fazenda vive com bem menos que isso; 16 é um teto seguro que ainda deixa
## sombra e brilho.
const CORES_PADRAO: int = 16

## Meio caminho do alfa. Pixel art não tem transparência parcial — ou o pixel
## está lá, ou não está. É o que apaga o halo que a redução deixa em volta.
const ALFA_CORTE_PADRAO: int = 128

## Lado da célula. 0 = o recorte sai no tamanho justo do desenho.
var celula: int = 0
## Onde o desenho encosta quando sobra espaço na célula.
var ancora: Fatiador.Ancora = Fatiador.Ancora.CENTRO
## Multiplicador aplicado antes de tudo. 1.0 = não mexe.
var escala: float = 1.0
## Reduz o que não couber na célula, em vez de deixar sair fora do padrão.
var encaixar: bool = false
## Como reamostrar. Suave só faz sentido reduzindo imagem grande.
var filtro: Fatiador.Filtro = Fatiador.Filtro.NEAREST
## Alfa abaixo disto some, acima vira opaco. 0 = não mexe no alfa.
var alfa_corte: int = 0
## Teto de cores diferentes. 0 = não mexe na paleta.
var cores: int = 0


## A folha já é pixel art, no tamanho em que foi desenhada. Só posiciona.
static func pixel_art(lado_da_celula: int = 0,
		onde: Fatiador.Ancora = Fatiador.Ancora.CENTRO) -> AcabamentoArte:
	var acabamento: AcabamentoArte = AcabamentoArte.new()
	acabamento.celula = lado_da_celula
	acabamento.ancora = onde
	return acabamento


## A imagem veio de IA ou de pintura digital: grande, com bordas suaves e
## centenas de tons. Reduzir com nearest serrilha e reduzir sem tratar o resto
## deixa halo e sujeira — os quatro ajustes andam juntos.
static func arte_gerada(lado_da_celula: int,
		onde: Fatiador.Ancora = Fatiador.Ancora.CENTRO) -> AcabamentoArte:
	var acabamento: AcabamentoArte = AcabamentoArte.new()
	acabamento.celula = lado_da_celula
	acabamento.ancora = onde
	acabamento.encaixar = true
	acabamento.filtro = Fatiador.Filtro.SUAVE
	acabamento.alfa_corte = ALFA_CORTE_PADRAO
	acabamento.cores = CORES_PADRAO
	return acabamento


func duplica() -> AcabamentoArte:
	var copia: AcabamentoArte = AcabamentoArte.new()
	copia.celula = celula
	copia.ancora = ancora
	copia.escala = escala
	copia.encaixar = encaixar
	copia.filtro = filtro
	copia.alfa_corte = alfa_corte
	copia.cores = cores
	return copia


## Uma linha para o resumo na tela e no terminal.
func descricao() -> String:
	var partes: PackedStringArray = PackedStringArray()
	partes.append("%d×%d" % [celula, celula] if celula > 0 else "tamanho justo")
	if not is_equal_approx(escala, 1.0):
		partes.append("escala %s" % escala)
	if encaixar:
		partes.append("reduz para caber")
	if filtro == Fatiador.Filtro.SUAVE:
		partes.append("suave")
	if alfa_corte > 0:
		partes.append("alfa %d" % alfa_corte)
	if cores > 0:
		partes.append("%d cores" % cores)
	return ", ".join(partes)
