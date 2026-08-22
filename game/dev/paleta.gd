class_name Paleta
extends RefCounted

## A paleta do playground, em constantes. É a tradução literal do design system
## aprovado ("Fazenda de Botões", v1) — nada aqui foi decidido nesta wave.
##
## ## A regra que este arquivo existe para valer
##
## **Nenhum nó de `game/dev/` pinta cor na mão.** Toda cor sai daqui, e trocar o
## tema inteiro é editar um arquivo só. `tests/test_paleta_dev.gd` guarda a
## regra: hex solto em qualquer outro arquivo de `game/dev/` reprova a suíte.
##
## ## Cada cor tem um dono
##
## Nenhuma cor faz dois trabalhos. Ouro é dinheiro, e só dinheiro. Céu é tempo.
## Alerta é recusa. Verde é ação, sucesso e fazenda. Terra é cidade e atenção.
## Quando um painel novo precisar de uma cor "que não tem dono", o certo é
## reusar a do assunto — não inventar a décima.
##
## Os **canais do jogo** são intocáveis e valem também para a arte final
## (ARTE.md §2): o solo fala de rega (claro seco, escuro molhado) e a planta
## fala de estágio (tamanho). Misturar os dois canais é bug de leitura, não de
## gosto.
##
## Nunca é instanciada: é um saco de constantes com nome.


# --- Superfícies ---

## O chão de tudo — o fundo da janela.
const FUNDO := Color("0F1310")
## Barras e painéis.
const PAINEL := Color("171C17")
## Botão em repouso.
const PAINEL_2 := Color("1F251F")
## Hover e item ativo.
const PAINEL_3 := Color("273027")
## Divisória discreta.
const LINHA := Color("28302A")
## Borda de controle e divisória forte.
const LINHA_2 := Color("3A443B")


# --- Texto ---

## Texto principal.
const TINTA := Color("E4EADF")
## Texto secundário.
const TINTA_2 := Color("97A192")
## Texto terciário: rótulo micro, hora do diário, unidade.
const TINTA_3 := Color("6F796C")
## Texto sobre o verde da ação primária — o único lugar onde a tinta é escura.
const TINTA_SOBRE_VERDE := Color("0C1810")


# --- Semânticas de interface ---

## Ação, sucesso, fazenda.
const VERDE := Color("63C68C")
## Cidade, atenção.
const TERRA := Color("D68B54")
## Dinheiro — só dinheiro.
const OURO := Color("D9C36A")
## Tempo e relógio.
const CEU := Color("8FB6D9")
## Recusa, perigo.
const ALERTA := Color("E2705A")


# --- Canais do jogo ---

## Terreno da fazenda.
const GRAMA := Color("26331F")
## Canal da rega: solo claro é solo seco.
const SOLO_SECO := Color("7A5A3C")
## Canal da rega: solo escuro é solo molhado.
const SOLO_MOLHADO := Color("4A3423")
## Canal do estágio: o quadrado cresce; a cor não muda até ficar pronta.
const PLANTA := Color("63C68C")
## Pronta — e nunca só pela cor: é maior, mais clara e pulsa (três sinais).
const PRONTA := Color("8FE0AE")
## A única coisa creme na tela.
const JOGADOR := Color("F2EFE4")

## Terreno do caminho entre a fazenda e a cidade (esboço da wave 10; o design
## system não nomeia o chão do caminho, e esta é a cor que já estava em uso).
const CAMINHO := Color("4E4234")
## Chão da cidade. A borda dela é a `TERRA`, que é a dona da cidade.
const CIDADE_CHAO := Color("33281E")

## Contorno do canteiro virgem: a tinta a 10%, o mesmo do mock.
const CONTORNO := Color(TINTA.r, TINTA.g, TINTA.b, 0.10)
## Fundo de pílula e de botão-fantasma: a cor do assunto, quase transparente.
const VEU: float = 0.12

## "Sem cor": fundo ou borda que não existe. Não é uma cor da paleta — é a
## ausência de uma, e mora aqui para que nem esse `Color(0,0,0,0)` precise ser
## digitado em outro arquivo.
const NADA := Color(0, 0, 0, 0)
## Os dois valores neutros de `modulate`, que é opacidade e não cor. Um nó
## visível não tinge nada; um invisível é o mesmo nó com alfa zero.
const VISIVEL := Color(1, 1, 1, 1)
const INVISIVEL := Color(1, 1, 1, 0)


# --- Espaço e forma (grade de 4px) ---

## Raio único, em tudo: botão, painel, tile.
const RAIO: int = 4
## Borda padrão.
const BORDA: int = 1
## Foco e retículo — o dobro, para saltar.
const BORDA_FOCO: int = 2

## Entre itens de um mesmo grupo.
const ESPACO_ITEM: int = 4
## Entre controles.
const ESPACO_CONTROLE: int = 8
## Respiro interno de painel.
const RESPIRO: int = 12
## Respiro interno de painel largo.
const RESPIRO_LARGO: int = 16
## Entre grupos.
const ESPACO_GRUPO: int = 24


# --- Tipografia ---

## Título de painel.
const TAMANHO_TITULO: int = 20
## Rótulo e botão.
const TAMANHO_ROTULO: int = 14
## Corpo de texto.
const TAMANHO_CORPO: int = 14
## Número: relógio, dinheiro, cota, coordenada. Sempre mono.
const TAMANHO_DADO: int = 13
## Micro-rótulo em caixa alta.
const TAMANHO_MICRO: int = 10

## Espaçamento das letras do micro-rótulo, em pixels.
const ESPACAMENTO_MICRO: int = 1


## A mesma cor, com outra opacidade. Para véus e estados sem inventar constante.
static func veu(cor: Color, alfa: float = VEU) -> Color:
	return Color(cor.r, cor.g, cor.b, alfa)

## A cor em `#rrggbb`, para BBCode do `RichTextLabel` — que só aceita texto.
## É o único caminho legítimo de hex em `game/dev/`: o hex sai daqui, não do
## painel.
static func hex(cor: Color) -> String:
	return "#" + cor.to_html(false)
