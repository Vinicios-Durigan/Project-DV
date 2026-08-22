class_name PaletaTerreno
extends RefCounted

## A cor de cada cobertura do terreno no mapa do playground.
##
## Arquivo próprio, e não mais constantes soltas na `Paleta`, porque isto é uma
## **tabela de tradução** — cobertura da sim → cor da tela — e não um vocabulário
## de design. Cobertura nova na sim é uma linha aqui, e o mapa desenha sozinho.
##
## ## Nenhuma cor nasce aqui
##
## Toda cor sai da `Paleta`, como manda a doutrina dela: hex literal em
## `game/dev/` reprova o `test_paleta_dev.gd`. O que este arquivo faz é
## **escolher** entre as que já existem, e a escolha tem lógica:
##
## - **mato** é planta indesejada, então usa o verde da planta, apagado — ele
##   precisa parecer com a cultura sem ser confundido com ela;
## - **pedra** é o cinza da tinta secundária: cor morta, que não puxa o olho;
## - **árvore** é o verde vivo, cheio, porque uma árvore é o obstáculo mais
##   caro de tirar e tem que ser vista de longe;
## - **toco** é a terra: o que sobra da árvore derrubada é madeira no chão;
## - **água** é o céu, que é o azul que o projeto já tem.
##
## ## Por que a cobertura pinta o tile inteiro
##
## O canteiro comunica duas coisas com dois canais (terra = rega, planta =
## estágio; ARTE §2). A cobertura é um terceiro estado e **substitui** os dois:
## um tile coberto não tem rega nem estágio para mostrar. Por isso ela pinta o
## fundo em vez de virar um enfeite por cima — quem olha precisa ver na hora que
## ali não dá para plantar.

## Quanto o mato é apagado em relação à planta viva. Alto o bastante para não
## competir com a cultura, baixo o bastante para o verde ainda ser verde.
const APAGADO: float = 0.55


## A cor daquela cobertura, ou `NADA` para chão livre — livre é ausência, e quem
## desenha continua usando o canal da terra.
static func cor_de(cobertura: String) -> Color:
	match cobertura:
		EstadoTerreno.MATO:
			return Paleta.veu(Paleta.PLANTA, APAGADO)
		EstadoTerreno.PEDRA:
			return Paleta.TINTA_2
		EstadoTerreno.ARVORE:
			return Paleta.VERDE
		EstadoTerreno.TOCO:
			return Paleta.TERRA
		EstadoTerreno.AGUA:
			return Paleta.CEU
	return Paleta.NADA


## Este tile está coberto por alguma coisa?
static func cobre(cobertura: String) -> bool:
	return cobertura != EstadoTerreno.LIVRE and not cobertura.is_empty()


## O nome curto para a fachada e o inspetor. O id é de máquina; o texto é daqui.
static func nome_de(cobertura: String) -> String:
	match cobertura:
		EstadoTerreno.MATO:
			return "mato"
		EstadoTerreno.PEDRA:
			return "pedra"
		EstadoTerreno.ARVORE:
			return "árvore"
		EstadoTerreno.TOCO:
			return "toco"
		EstadoTerreno.AGUA:
			return "água"
	return "livre"
