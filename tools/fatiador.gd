class_name Fatiador
extends RefCounted

## A lógica de imagem por trás de `tools/fatiar_sprites.gd`: tirar o fundo,
## achar cada sprite na folha, recortar e padronizar no tamanho do projeto.
##
## Fica separada do script de linha de comando por um motivo só: assim dá para
## testar. Ferramenta que corta arte errado estraga o pipeline do artista em
## silêncio — o erro só aparece semanas depois, com o ícone torto na hotbar.
## `tests/test_fatiador.gd` cobre cada etapa.
##
## Não é `sim/` e não é `game/`: não tem regra de jogo nem nó de cena, é
## utilitário de pipeline de arte. Mexe em `Image`, que é tipo de engine, e por
## isso mesmo não poderia morar em `sim/`.

## Alpha a partir do qual o pixel conta como desenho. Abaixo disso é fundo:
## pega anti-aliasing de sobra sem catar sujeira invisível.
const ALPHA_MINIMO: int = 8

## Onde o sprite encosta quando sobra espaço na célula. Ícone de mochila fica
## no centro; objeto que se apoia no chão fica embaixo, senão flutua no tile.
enum Ancora { CENTRO, BAIXO, TOPO }

## Como reamostrar ao mudar de tamanho.
##
## `NEAREST` é o certo para pixel art já pronta: nenhum tom novo aparece, a
## paleta do artista fica intacta. Mas reduzir 512px para 16px com nearest joga
## fora 99% dos pixels e escolhe um a cada 32 — o resultado vira ruído.
##
## `SUAVE` faz a média da vizinhança, que é o que preserva a forma numa redução
## grande. Em troca inventa tons intermediários, e é por isso que `alfa_corte` e
## `cores` existem: eles limpam o que a suavização sujou.
enum Filtro { NEAREST, SUAVE }

var _imagem: Image = null
var _largura: int = 0
var _altura: int = 0
## Um byte por pixel: 1 = tem desenho. Ler `get_data()` uma vez e varrer bytes
## é o que torna a busca viável — `get_pixel` por pixel numa folha grande custa
## caro demais em GDScript.
var _opaco: PackedByteArray = PackedByteArray()


func define_imagem(imagem: Image) -> void:
	_imagem = imagem.duplicate()
	if _imagem.get_format() != Image.FORMAT_RGBA8:
		_imagem.convert(Image.FORMAT_RGBA8)
	_largura = _imagem.get_width()
	_altura = _imagem.get_height()
	_remapeia()


func imagem() -> Image:
	return _imagem


func largura() -> int:
	return _largura


func altura() -> int:
	return _altura


func _remapeia() -> void:
	var bytes: PackedByteArray = _imagem.get_data()
	_opaco = PackedByteArray()
	_opaco.resize(_largura * _altura)
	for i in _largura * _altura:
		_opaco[i] = 1 if bytes[i * 4 + 3] >= ALPHA_MINIMO else 0


func tem_desenho(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _largura or y >= _altura:
		return false
	return _opaco[y * _largura + x] == 1


func pixels_com_desenho() -> int:
	var total: int = 0
	for byte in _opaco:
		total += byte
	return total


# --- fundo ---------------------------------------------------------------

## A cor que mais aparece na moldura de 1px. Folha de spritesheet quase sempre
## tem borda de fundo puro, então a moda da moldura acerta — e erra barato,
## porque `--fundo=#rrggbb` sempre sobrepõe o palpite.
##
## Se vier transparente, a folha já está pronta e não há fundo a remover.
func cor_de_fundo_provavel() -> Color:
	var contagem: Dictionary = {}
	var vencedora: Color = Color(0, 0, 0, 0)
	var mais: int = 0

	for x in _largura:
		_conta(contagem, _imagem.get_pixel(x, 0))
		_conta(contagem, _imagem.get_pixel(x, _altura - 1))
	for y in _altura:
		_conta(contagem, _imagem.get_pixel(0, y))
		_conta(contagem, _imagem.get_pixel(_largura - 1, y))

	for chave: Color in contagem:
		if contagem[chave] > mais:
			mais = contagem[chave]
			vencedora = chave
	return vencedora


func _conta(contagem: Dictionary, cor: Color) -> void:
	contagem[cor] = int(contagem.get(cor, 0)) + 1


## Fundo vira transparência. `so_das_bordas` é o modo seguro e o padrão: apaga
## espalhando a partir da moldura, então cor de fundo que aparece **dentro** do
## desenho — o cinza do cabo da enxada, o preto do olho — fica onde está. Sem
## isso o item sai furado.
##
## Devolve quantos pixels foram apagados.
func remove_fundo(cor: Color, tolerancia: int, so_das_bordas: bool = true) -> int:
	if cor.a < ALPHA_MINIMO / 255.0:
		return 0

	var apagados: int = 0
	if not so_das_bordas:
		for y in _altura:
			for x in _largura:
				if _parece(_imagem.get_pixel(x, y), cor, tolerancia):
					_imagem.set_pixel(x, y, Color(0, 0, 0, 0))
					apagados += 1
		_remapeia()
		return apagados

	var visto: PackedByteArray = PackedByteArray()
	visto.resize(_largura * _altura)
	var fila: Array[Vector2i] = []

	for x in _largura:
		_enfileira_borda(fila, visto, x, 0, cor, tolerancia)
		_enfileira_borda(fila, visto, x, _altura - 1, cor, tolerancia)
	for y in _altura:
		_enfileira_borda(fila, visto, 0, y, cor, tolerancia)
		_enfileira_borda(fila, visto, _largura - 1, y, cor, tolerancia)

	const VIZINHOS: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		_imagem.set_pixel(atual.x, atual.y, Color(0, 0, 0, 0))
		apagados += 1
		for passo in VIZINHOS:
			var vizinho: Vector2i = atual + passo
			if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= _largura or vizinho.y >= _altura:
				continue
			_enfileira_borda(fila, visto, vizinho.x, vizinho.y, cor, tolerancia)

	_remapeia()
	return apagados


func _enfileira_borda(fila: Array[Vector2i], visto: PackedByteArray,
		x: int, y: int, cor: Color, tolerancia: int) -> void:
	var indice: int = y * _largura + x
	if visto[indice] == 1:
		return
	visto[indice] = 1
	if _parece(_imagem.get_pixel(x, y), cor, tolerancia):
		fila.append(Vector2i(x, y))


## Tolerância em passos de 0–255 por canal: JPEG e gradiente sujam o fundo
## chapado, e comparação exata deixaria uma moldura de lixo em volta do sprite.
func _parece(a: Color, b: Color, tolerancia: int) -> bool:
	if a.a < ALPHA_MINIMO / 255.0:
		return true
	var limite: float = tolerancia / 255.0
	return (absf(a.r - b.r) <= limite
		and absf(a.g - b.g) <= limite
		and absf(a.b - b.b) <= limite)


# --- achar os sprites ----------------------------------------------------

## Cada sprite é uma ilha de pixels com desenho. Varre a folha atrás da
## primeira ilha ainda não vista e cresce ela por vizinhança até acabar.
##
## O `raio` é o que deixa um sprite ter pedaços soltos: o brilho separado do
## cabo, o ponto do "i". Raio alto demais cola dois itens vizinhos num recorte
## só — é o botão a mexer quando a contagem sai errada.
func acha_sprites(raio: int, area_minima: int) -> Array[Rect2i]:
	var visto: PackedByteArray = PackedByteArray()
	visto.resize(_largura * _altura)
	var achados: Array[Rect2i] = []

	for y in _altura:
		for x in _largura:
			var inicio: int = y * _largura + x
			if _opaco[inicio] == 0 or visto[inicio] == 1:
				continue

			visto[inicio] = 1
			var fila: Array[Vector2i] = [Vector2i(x, y)]
			var area: int = 0
			var caixa: Rect2i = Rect2i(x, y, 1, 1)

			while not fila.is_empty():
				var atual: Vector2i = fila.pop_back()
				area += 1
				caixa = caixa.expand(atual).expand(atual + Vector2i.ONE)
				for dy in range(-raio, raio + 1):
					for dx in range(-raio, raio + 1):
						var vx: int = atual.x + dx
						var vy: int = atual.y + dy
						if not tem_desenho(vx, vy):
							continue
						var indice: int = vy * _largura + vx
						if visto[indice] == 1:
							continue
						visto[indice] = 1
						fila.append(Vector2i(vx, vy))

			if area >= area_minima:
				achados.append(caixa)

	return achados


## Folha desenhada em grid certinho não precisa de adivinhação: corta as
## células e joga fora as vazias.
func recorta_por_grade(lado: int) -> Array[Rect2i]:
	var achados: Array[Rect2i] = []
	for y in range(0, _altura, lado):
		for x in range(0, _largura, lado):
			var celula: Rect2i = Rect2i(x, y, mini(lado, _largura - x), mini(lado, _altura - y))
			if _tem_algum_desenho(celula):
				achados.append(celula)
	return achados


func _tem_algum_desenho(area: Rect2i) -> bool:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if tem_desenho(x, y):
				return true
	return false


## Ordem de leitura — de cima para baixo, da esquerda para a direita. Agrupa em
## linha os recortes que se sobrepõem na vertical e ordena cada linha por x.
##
## É o contrato de `--nomes`: a lista que o artista escreve casa com o que o
## olho dele vê na folha, mesmo quando os desenhos não estão alinhados.
static func em_ordem_de_leitura(recortes: Array[Rect2i]) -> Array[Rect2i]:
	var pendentes: Array[Rect2i] = recortes.duplicate()
	pendentes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.position.y < b.position.y)

	var ordenados: Array[Rect2i] = []
	var linha: Array[Rect2i] = []
	var fim_da_linha: int = -1

	for recorte in pendentes:
		if not linha.is_empty() and recorte.position.y >= fim_da_linha:
			ordenados.append_array(_por_x(linha))
			linha = []
			fim_da_linha = -1
		linha.append(recorte)
		fim_da_linha = maxi(fim_da_linha, recorte.end.y)

	ordenados.append_array(_por_x(linha))
	return ordenados


static func _por_x(linha: Array[Rect2i]) -> Array[Rect2i]:
	var copia: Array[Rect2i] = linha.duplicate()
	copia.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.position.x < b.position.x)
	return copia


# --- recortar e padronizar -----------------------------------------------

## Um sprite pronto para o disco.
##
## A ordem das etapas não é arbitrária:
##
## 1. **recorta** o pedaço da folha;
## 2. **escala** manual, quando o artista pediu um multiplicador;
## 3. **encaixa**, reduzindo o que não couber na célula — antes de mexer em cor,
##    porque reduzir depois estragaria a paleta recém-arrumada;
## 4. **corta o alfa**, matando o halo semitransparente que a redução deixa;
## 5. **reduz a paleta**, agora que a imagem já está no tamanho final e cada
##    cor contada é uma cor que vai mesmo para o disco;
## 6. **posiciona** na célula, com a âncora escolhida.
##
## Sem acabamento (`null`) devolve o recorte justo, do tamanho do desenho.
func recorte(area: Rect2i, acabamento: AcabamentoArte = null) -> Image:
	var pedaco: Image = _imagem.get_region(area)
	if acabamento == null:
		return pedaco

	if acabamento.escala > 0.0 and not is_equal_approx(acabamento.escala, 1.0):
		pedaco = redimensiona(pedaco,
			maxi(1, roundi(pedaco.get_width() * acabamento.escala)),
			maxi(1, roundi(pedaco.get_height() * acabamento.escala)),
			acabamento.filtro)

	var celula: int = acabamento.celula
	if celula > 0 and acabamento.encaixar:
		pedaco = encaixa(pedaco, celula, acabamento.filtro)

	if acabamento.alfa_corte > 0:
		pedaco = achata_alfa(pedaco, acabamento.alfa_corte)

	if acabamento.cores > 0:
		pedaco = reduz_paleta(pedaco, acabamento.cores)

	if celula <= 0:
		return pedaco

	var tamanho: Vector2i = pedaco.get_size()
	if tamanho.x > celula or tamanho.y > celula:
		# Cortar o desenho para caber seria pior que devolver fora do padrão: o
		# artista precisa ver que passou do tamanho. Quem avisa é o chamador —
		# ou ele liga `encaixar` e o problema deixa de existir.
		return pedaco

	var canvas: Image = Image.create_empty(celula, celula, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(pedaco, Rect2i(Vector2i.ZERO, tamanho),
		_encosta(tamanho, celula, acabamento.ancora))
	return canvas


static func redimensiona(origem: Image, nova_largura: int, nova_altura: int, filtro: Filtro) -> Image:
	var copia: Image = origem.duplicate()
	copia.resize(nova_largura, nova_altura,
		Image.INTERPOLATE_LANCZOS if filtro == Filtro.SUAVE else Image.INTERPOLATE_NEAREST)
	return copia


## Reduz até caber na célula **preservando a proporção** — um regador alto
## continua alto. Imagem que já cabe não é tocada: aumentar pixel art para
## preencher a célula só engordaria o desenho sem acrescentar detalhe.
static func encaixa(origem: Image, celula: int, filtro: Filtro) -> Image:
	var tamanho: Vector2i = origem.get_size()
	if tamanho.x <= celula and tamanho.y <= celula:
		return origem

	var fator: float = minf(float(celula) / tamanho.x, float(celula) / tamanho.y)
	return redimensiona(origem,
		clampi(roundi(tamanho.x * fator), 1, celula),
		clampi(roundi(tamanho.y * fator), 1, celula),
		filtro)


## Pixel art não tem transparência parcial: ou o pixel está lá, ou não está.
##
## Reduzir uma imagem grande deixa uma auréola de pixels meio transparentes na
## silhueta. Na hotbar isso vira uma franja cinza em volta do ícone — e some
## quando cada pixel é obrigado a escolher um lado.
static func achata_alfa(origem: Image, corte: int) -> Image:
	var copia: Image = origem.duplicate()
	var limite: float = corte / 255.0
	for y in copia.get_height():
		for x in copia.get_width():
			var cor: Color = copia.get_pixel(x, y)
			if cor.a >= limite:
				cor.a = 1.0
			else:
				cor = Color(0, 0, 0, 0)
			copia.set_pixel(x, y, cor)
	return copia


## Corta a paleta para no máximo `maximo` cores.
##
## O que faz uma imagem parecer pixel art não é só o tamanho — é a quantidade
## de cores. Arte gerada por IA chega com centenas de tons quase iguais, e
## reduzida para 16×16 vira uma mancha suja. Com dezesseis cores a mesma imagem
## lê como sprite.
##
## O método: agrupa as cores parecidas em caixas, fica com as caixas mais
## populosas e usa a média real de cada uma como cor final — a média evita o
## deslocamento de tom que sair pegando a cor do centro da caixa causaria.
## Depois cada pixel vai para a cor mais próxima que sobrou.
static func reduz_paleta(origem: Image, maximo: int) -> Image:
	if maximo <= 0:
		return origem

	# Sair pela contagem de cores, não pela de caixas: várias cores diferentes
	# cabem na mesma caixa, e desistir por "poucas caixas" devolveria a imagem
	# ainda acima do teto pedido.
	if conta_cores(origem) <= maximo:
		return origem

	const LADO_DA_CAIXA: int = 16
	var soma: Dictionary = {}
	var quantos: Dictionary = {}

	for y in origem.get_height():
		for x in origem.get_width():
			var cor: Color = origem.get_pixel(x, y)
			if cor.a <= 0.0:
				continue
			var caixa: Vector3i = Vector3i(
				int(cor.r * 255) / LADO_DA_CAIXA,
				int(cor.g * 255) / LADO_DA_CAIXA,
				int(cor.b * 255) / LADO_DA_CAIXA)
			var antes: Color = soma.get(caixa, Color(0, 0, 0, 0))
			soma[caixa] = Color(antes.r + cor.r, antes.g + cor.g, antes.b + cor.b, 0)
			quantos[caixa] = int(quantos.get(caixa, 0)) + 1

	var caixas: Array[Vector3i] = []
	for caixa: Vector3i in quantos:
		caixas.append(caixa)
	caixas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return int(quantos[a]) > int(quantos[b]))

	var paleta: Array[Color] = []
	for i in mini(maximo, caixas.size()):
		var caixa: Vector3i = caixas[i]
		var total: float = float(quantos[caixa])
		var acumulado: Color = soma[caixa]
		paleta.append(Color(acumulado.r / total, acumulado.g / total, acumulado.b / total))

	var copia: Image = origem.duplicate()
	for y in copia.get_height():
		for x in copia.get_width():
			var cor: Color = copia.get_pixel(x, y)
			if cor.a <= 0.0:
				continue
			copia.set_pixel(x, y, _mais_proxima(cor, paleta, cor.a))
	return copia


static func _mais_proxima(alvo: Color, paleta: Array[Color], alfa: float) -> Color:
	var melhor: Color = paleta[0]
	var menor: float = INF
	for cor in paleta:
		var distancia: float = ((cor.r - alvo.r) * (cor.r - alvo.r)
			+ (cor.g - alvo.g) * (cor.g - alvo.g)
			+ (cor.b - alvo.b) * (cor.b - alvo.b))
		if distancia < menor:
			menor = distancia
			melhor = cor
	return Color(melhor.r, melhor.g, melhor.b, alfa)


## Quantas cores diferentes a imagem tem, ignorando o que é transparente. É o
## número que diz se a folha já é pixel art ou se veio de pintura digital.
static func conta_cores(origem: Image) -> int:
	var vistas: Dictionary = {}
	for y in origem.get_height():
		for x in origem.get_width():
			var cor: Color = origem.get_pixel(x, y)
			if cor.a > 0.0:
				vistas[Color(cor.r, cor.g, cor.b)] = true
	return vistas.size()


func _encosta(tamanho: Vector2i, celula: int, ancora: Ancora) -> Vector2i:
	var x: int = (celula - tamanho.x) / 2
	match ancora:
		Ancora.TOPO:
			return Vector2i(x, 0)
		Ancora.BAIXO:
			return Vector2i(x, celula - tamanho.y)
		_:
			return Vector2i(x, (celula - tamanho.y) / 2)


static func ancora_por_nome(nome: String) -> Ancora:
	match nome.to_lower():
		"baixo", "chao", "chão":
			return Ancora.BAIXO
		"topo", "cima":
			return Ancora.TOPO
		_:
			return Ancora.CENTRO


# --- conferência ---------------------------------------------------------

## Uma imagem única com todos os recortes lado a lado, na ordem de leitura,
## sobre um xadrez que mostra onde cada célula começa e termina.
##
## Serve para o artista conferir a ordem **antes** de escrever `--nomes`, e
## para enxergar sprite colado no vizinho ou cortado pela metade. Contar
## quadrado numa imagem é mais rápido que ler a lista no terminal.
func folha_de_contato(recortes: Array[Rect2i], colunas: int = 8, celula: int = 20) -> Image:
	var quantos: int = recortes.size()
	if quantos == 0:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)

	var largura_em_celulas: int = mini(colunas, quantos)
	var linhas: int = ceili(float(quantos) / largura_em_celulas)
	var folha: Image = Image.create_empty(
		largura_em_celulas * celula, linhas * celula, false, Image.FORMAT_RGBA8)

	for i in quantos:
		var coluna: int = i % largura_em_celulas
		var linha: int = i / largura_em_celulas
		var canto: Vector2i = Vector2i(coluna * celula, linha * celula)
		var xadrez: Color = (Color(0.16, 0.16, 0.18) if (coluna + linha) % 2 == 0
			else Color(0.22, 0.22, 0.25))
		folha.fill_rect(Rect2i(canto, Vector2i(celula, celula)), xadrez)

		var pedaco: Image = recorte(recortes[i], AcabamentoArte.pixel_art(celula))
		var tamanho: Vector2i = pedaco.get_size()
		if tamanho.x > celula or tamanho.y > celula:
			pedaco = pedaco.get_region(Rect2i(Vector2i.ZERO, Vector2i(
				mini(tamanho.x, celula), mini(tamanho.y, celula))))
			tamanho = pedaco.get_size()
		folha.blend_rect(pedaco, Rect2i(Vector2i.ZERO, tamanho),
			canto + (Vector2i(celula, celula) - tamanho) / 2)

	return folha
