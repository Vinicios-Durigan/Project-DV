extends SceneTree

## Joga uma imagem aqui e sai arte no padrão do projeto: fundo removido, um PNG
## por sprite, tamanho certo, nome certo.
##
## Roda pela Godot mesmo — nada de Python, Pillow ou pip:
##
##     godot --headless -s res://tools/fatiar_sprites.gd -- --entrada=<imagem>
##
## O trabalho pesado mora em `tools/fatiador.gd`, que tem teste. Aqui só lê
## argumento, decide e escreve em disco.
##
## O caminho normal são três passos:
##
##     # 1. ver o que a folha tem, sem escrever nada
##     godot --headless -s res://tools/fatiar_sprites.gd -- \
##         --entrada=C:/Users/durigan/Downloads/itens.png --listar \
##         --contato=C:/Users/durigan/Downloads/conferir.png
##
##     # 2. abrir conferir.png, contar os quadrados e escrever os nomes na ordem
##     # 3. recortar de verdade
##     godot --headless -s res://tools/fatiar_sprites.gd -- \
##         --entrada=C:/Users/durigan/Downloads/itens.png \
##         --saida=res://assets/items --celula=16 \
##         --nomes=enxada,regador,machado,picareta
##
## Se a contagem sair errada no passo 1, o botão é `--raio`: baixo demais parte
## um sprite em dois, alto demais cola dois num só.

const RAIO_PADRAO: int = 2
const AREA_MINIMA_PADRAO: int = 6
const TOLERANCIA_PADRAO: int = 12
const PREFIXO_PADRAO: String = "sprite"
const SAIDA_PADRAO: String = "res://assets/items"
## O padrão do projeto para ícone de item e tile de mundo (docs/ARTE.md §1).
const CELULA_DO_PROJETO: int = 16


func _initialize() -> void:
	var opcoes: Dictionary = _le_argumentos()

	if opcoes.has("ajuda") or opcoes.is_empty():
		_ajuda()
		quit(0 if opcoes.has("ajuda") else 1)
		return

	var entrada: String = String(opcoes.get("entrada", ""))
	if entrada.is_empty():
		printerr("erro: falta --entrada=<caminho da imagem>")
		_ajuda()
		quit(1)
		return

	if not _aplica_tipo(opcoes):
		quit(1)
		return

	var imagem: Image = _carrega(entrada)
	if imagem == null:
		quit(1)
		return

	var fatiador: Fatiador = Fatiador.new()
	fatiador.define_imagem(imagem)

	if not _tira_o_fundo(fatiador, opcoes):
		quit(1)
		return

	var recortes: Array[Rect2i] = _acha(fatiador, opcoes)
	if recortes.is_empty():
		printerr("nenhum sprite encontrado.")
		printerr("  - a folha tem fundo chapado? tente --fundo=auto (é o padrão) ou --tolerancia=32")
		printerr("  - fundo com gradiente ou textura? passe a cor na mão: --fundo=#2b2b2b")
		quit(1)
		return

	recortes = Fatiador.em_ordem_de_leitura(recortes)
	var nomes: PackedStringArray = _nomes_dos_recortes(opcoes, recortes.size())
	var maior: Vector2i = _relata(recortes, nomes)

	if opcoes.has("contato"):
		_grava_contato(fatiador, recortes, String(opcoes["contato"]))

	var celula: int = int(opcoes.get("celula", 0))
	var escala: float = float(opcoes.get("escala", 1.0))
	_avisa_sobre_tamanho(maior, celula, escala)

	if opcoes.has("listar"):
		print("\n--listar: nenhum PNG foi escrito.")
		quit(0)
		return

	var saida: String = String(opcoes.get("saida", SAIDA_PADRAO))
	var acabamento: AcabamentoArte = _monta_acabamento(opcoes, celula, escala)
	print("acabamento: %s" % acabamento.descricao())
	var escritos: int = _salva(fatiador, recortes, nomes, saida, acabamento,
		opcoes.has("sobrescrever"))
	if escritos < 0:
		quit(1)
		return

	print("\n%d PNGs em %s" % [escritos, saida])
	if saida.begins_with("res://"):
		print("rode `godot --headless --import` para a Godot enxergar os arquivos novos.")
	quit(0)


func _ajuda() -> void:
	print("uso: godot --headless -s res://tools/fatiar_sprites.gd -- --entrada=<imagem> [opcoes]")
	print("")
	print("  entrada e saida")
	print("    --entrada=CAMINHO   a folha a recortar (caminho do sistema ou res://)")
	print("    --tipo=TIPO         resolve pasta, celula e nomes sozinho. Um de:")
	print("                        %s" % DestinoArte.nomes_de_tipo_aceitos())
	print("    --slug=NOME         o nome da cultura, quando --tipo=cultura")
	print("    --saida=PASTA       onde gravar (padrao: %s; ganha de --tipo)" % SAIDA_PADRAO)
	print("    --nomes=a,b,c       nomes na ordem de leitura, sem .png")
	print("    --prefixo=NOME      nome dos recortes sem --nomes (padrao: %s)" % PREFIXO_PADRAO)
	print("    --sobrescrever      deixa apagar PNG que ja existe na pasta de saida")
	print("")
	print("  fundo")
	print("    --fundo=auto        detecta a cor de fundo pela moldura (padrao)")
	print("    --fundo=#2b2b2b     usa esta cor como fundo")
	print("    --fundo=nenhum      nao mexe no fundo (folha ja transparente)")
	print("    --tolerancia=N      variacao de cor ainda tratada como fundo, 0-255 (padrao: %d)"
		% TOLERANCIA_PADRAO)
	print("    --fundo-em-tudo     apaga a cor na imagem inteira, nao so a partir das bordas")
	print("                        (rapido, mas fura o sprite que tem a cor do fundo dentro)")
	print("")
	print("  corte")
	print("    --grade=N           corta grade fixa N×N em vez de detectar sozinho")
	print("    --raio=N            distancia que ainda une pedacos do mesmo sprite (padrao: %d)"
		% RAIO_PADRAO)
	print("    --area-minima=N     descarta recorte com menos de N pixels (padrao: %d)"
		% AREA_MINIMA_PADRAO)
	print("")
	print("  acabamento")
	print("    --celula=N          centraliza cada recorte num canvas N×N (%d no projeto)"
		% CELULA_DO_PROJETO)
	print("    --ancora=centro|baixo|topo   onde o sprite encosta na celula (padrao: centro)")
	print("    --escala=F          redimensiona por F antes de encaixar (0.5 = metade)")
	print("")
	print("  imagem grande, gerada por IA ou pintada")
	print("    --de-ia             liga as quatro etapas de uma vez: encaixar, filtro suave,")
	print("                        alfa-corte=%d e cores=%d. E o atalho para o caso comum."
		% [AcabamentoArte.ALFA_CORTE_PADRAO, AcabamentoArte.CORES_PADRAO])
	print("    --encaixar          reduz o recorte grande ate caber na celula, sem cortar")
	print("    --filtro=suave      media a vizinhanca ao reduzir, em vez de pular pixel")
	print("    --alfa-corte=N      alfa abaixo de N some, acima vira opaco (tira o halo)")
	print("    --cores=N           corta a paleta em N cores (e o que faz virar pixel art)")
	print("")
	print("  conferencia")
	print("    --listar            so mostra o que achou, nao escreve PNG nenhum")
	print("    --contato=CAMINHO   grava uma folha de conferencia com todos os recortes")
	print("    --ajuda             isto aqui")


func _le_argumentos() -> Dictionary:
	var opcoes: Dictionary = {}
	for bruto in OS.get_cmdline_user_args():
		var argumento: String = bruto
		while argumento.begins_with("-"):
			argumento = argumento.substr(1)
		if argumento.is_empty():
			continue
		var corte: int = argumento.find("=")
		if corte < 0:
			opcoes[argumento] = true
		else:
			opcoes[argumento.left(corte)] = argumento.substr(corte + 1)
	return opcoes


func _carrega(caminho: String) -> Image:
	var imagem: Image = null
	if caminho.begins_with("res://"):
		var textura: Texture2D = load(caminho) as Texture2D
		if textura != null:
			imagem = textura.get_image()
	else:
		imagem = Image.load_from_file(caminho.simplify_path())

	if imagem == null:
		printerr("erro: nao consegui abrir '%s'" % caminho)
		return null

	print("entrada: %s — %d×%d" % [caminho, imagem.get_width(), imagem.get_height()])
	return imagem


## `--tipo=cultura --slug=trigo` resolve pasta, célula e nomes de uma vez, do
## jeito que o `docs/ARTE.md` manda. É o mesmo seletor da janela: quem decora a
## convenção é `tools/destino_arte.gd`, não o artista.
##
## O que veio na mão sempre ganha do que o tipo sugere — `--saida` e `--nomes`
## explícitos não são sobrescritos.
func _aplica_tipo(opcoes: Dictionary) -> bool:
	if not opcoes.has("tipo"):
		return true

	var nome: String = String(opcoes["tipo"])
	var tipo: DestinoArte.Tipo = DestinoArte.tipo_por_nome(nome)
	if tipo == DestinoArte.Tipo.LIVRE and nome.to_lower() != "outro":
		printerr("erro: --tipo='%s' não existe. Use um de: %s."
			% [nome, DestinoArte.nomes_de_tipo_aceitos()])
		return false

	var slug: String = String(opcoes.get("slug", ""))
	if DestinoArte.precisa_de_slug(tipo) and DestinoArte.normaliza_slug(slug).is_empty():
		printerr("erro: --tipo=%s precisa de --slug=<nome>, que vira a subpasta e o prefixo."
			% nome)
		return false

	if not opcoes.has("saida"):
		var pasta: String = DestinoArte.pasta(tipo, slug)
		if not pasta.is_empty():
			opcoes["saida"] = pasta
			print("tipo: %s → %s" % [nome, pasta])

	if not opcoes.has("celula"):
		var celula: int = DestinoArte.celula(tipo)
		if celula > 0:
			opcoes["celula"] = celula
	return true


## Nome de arquivo que o tipo já sabe de cor — hoje só cultura tem convenção
## fechada o bastante para isso.
func _nomes_do_tipo(opcoes: Dictionary, quantos: int) -> PackedStringArray:
	if not opcoes.has("tipo") or opcoes.has("nomes"):
		return PackedStringArray()
	var tipo: DestinoArte.Tipo = DestinoArte.tipo_por_nome(String(opcoes["tipo"]))
	var aviso: String = DestinoArte.aviso_de_quantidade(tipo, quantos)
	if not aviso.is_empty():
		print("aviso: %s" % aviso)
	return DestinoArte.nomes_sugeridos(tipo, String(opcoes.get("slug", "")), quantos)


## O passo que faz a folha baixada da internet virar arte usável: quase nenhuma
## vem com alpha, todas vêm com o fundo chapado do editor.
func _tira_o_fundo(fatiador: Fatiador, opcoes: Dictionary) -> bool:
	var pedido: String = String(opcoes.get("fundo", "auto"))
	if pedido == "nenhum":
		print("fundo: intacto, a pedido")
		return true

	var cor: Color
	if pedido == "auto":
		cor = fatiador.cor_de_fundo_provavel()
		if cor.a < 0.5:
			print("fundo: a folha ja e transparente, nada a remover")
			return true
		print("fundo: detectado %s pela moldura" % cor.to_html(false))
	elif Color.html_is_valid(pedido):
		cor = Color.html(pedido)
		print("fundo: %s, informado" % cor.to_html(false))
	else:
		printerr("erro: --fundo='%s' nao e uma cor. Use auto, nenhum ou #rrggbb." % pedido)
		return false

	var tolerancia: int = int(opcoes.get("tolerancia", TOLERANCIA_PADRAO))
	var so_das_bordas: bool = not opcoes.has("fundo-em-tudo")
	var apagados: int = fatiador.remove_fundo(cor, tolerancia, so_das_bordas)
	var total: int = fatiador.largura() * fatiador.altura()
	print("       %d pixels viraram transparente (%d%% da folha)%s"
		% [apagados, roundi(100.0 * apagados / total),
			"" if so_das_bordas else ", modo --fundo-em-tudo"])

	if fatiador.pixels_com_desenho() == 0:
		printerr("erro: a folha inteira virou fundo. --tolerancia=%d esta alto demais."
			% tolerancia)
		return false
	return true


func _acha(fatiador: Fatiador, opcoes: Dictionary) -> Array[Rect2i]:
	var grade: int = int(opcoes.get("grade", 0))
	if grade > 0:
		print("corte: grade fixa de %d×%d" % [grade, grade])
		return fatiador.recorta_por_grade(grade)

	var raio: int = int(opcoes.get("raio", RAIO_PADRAO))
	var area_minima: int = int(opcoes.get("area-minima", AREA_MINIMA_PADRAO))
	print("corte: automatico, raio de juncao %dpx, area minima %dpx" % [raio, area_minima])
	return fatiador.acha_sprites(raio, area_minima)


func _relata(recortes: Array[Rect2i], nomes: PackedStringArray) -> Vector2i:
	print("\n%d sprites, em ordem de leitura:" % recortes.size())
	var maior: Vector2i = Vector2i.ZERO
	for i in recortes.size():
		var r: Rect2i = recortes[i]
		maior = maior.max(r.size)
		print("  %2d  %-24s %2d×%-2d  em (%d, %d)"
			% [i, nomes[i] + ".png", r.size.x, r.size.y, r.position.x, r.position.y])
	return maior


func _avisa_sobre_tamanho(maior: Vector2i, celula: int, escala: float) -> void:
	var lado: int = maxi(maior.x, maior.y)
	var depois: int = maxi(1, roundi(lado * escala)) if escala > 0.0 else lado
	print("\nmaior recorte: %d×%d px%s"
		% [maior.x, maior.y, "" if depois == lado else " (%d após --escala=%s)" % [depois, escala]])

	if celula > 0:
		if depois > celula:
			print("aviso: nao cabe em --celula=%d — esses saem no tamanho justo." % celula)
		return

	if depois > CELULA_DO_PROJETO:
		print("aviso: o padrao do projeto e %d×%d (docs/ARTE.md §1)." % [CELULA_DO_PROJETO, CELULA_DO_PROJETO])
		print("       para padronizar: --celula=%d" % depois)
		if depois % CELULA_DO_PROJETO == 0:
			print("       para reduzir ao padrao: --escala=%s --celula=%d"
				% [str(float(CELULA_DO_PROJETO) / depois), CELULA_DO_PROJETO])


func _nomes_dos_recortes(opcoes: Dictionary, quantos: int) -> PackedStringArray:
	var pedidos: PackedStringArray = _nomes_do_tipo(opcoes, quantos)
	if opcoes.has("nomes"):
		pedidos = PackedStringArray()
		for nome in String(opcoes["nomes"]).split(",", false):
			var limpo: String = nome.strip_edges()
			if not limpo.is_empty():
				pedidos.append(limpo)

	if pedidos.size() > quantos:
		print("aviso: %d nomes para %d sprites — os ultimos %d nomes nao serao usados."
			% [pedidos.size(), quantos, pedidos.size() - quantos])
	elif not pedidos.is_empty() and pedidos.size() < quantos:
		print("aviso: %d nomes para %d sprites — o resto sai como %s_NN."
			% [pedidos.size(), quantos, String(opcoes.get("prefixo", PREFIXO_PADRAO))])

	var prefixo: String = String(opcoes.get("prefixo", PREFIXO_PADRAO))
	var nomes: PackedStringArray = PackedStringArray()
	for i in quantos:
		nomes.append(pedidos[i] if i < pedidos.size() else "%s_%02d" % [prefixo, i])
	return nomes


func _grava_contato(fatiador: Fatiador, recortes: Array[Rect2i], destino: String) -> void:
	var folha: Image = fatiador.folha_de_contato(recortes)
	if folha.save_png(destino) == OK:
		print("\nfolha de conferencia: %s" % destino)
		print("  os quadrados estao na mesma ordem da lista acima, 8 por linha.")
	else:
		printerr("erro ao gravar a folha de conferencia em '%s'" % destino)


## `--de-ia` é o atalho para o caso que mais aparece: a imagem veio de um
## gerador, grande e suave, e precisa das quatro etapas de uma vez. Cada uma
## continua disponível solta para quem quiser afinar.
func _monta_acabamento(opcoes: Dictionary, celula: int, escala: float) -> AcabamentoArte:
	var acabamento: AcabamentoArte = (AcabamentoArte.arte_gerada(celula)
		if opcoes.has("de-ia") else AcabamentoArte.pixel_art(celula))

	acabamento.ancora = Fatiador.ancora_por_nome(String(opcoes.get("ancora", "centro")))
	acabamento.escala = escala
	if opcoes.has("encaixar"):
		acabamento.encaixar = true
	if opcoes.has("filtro"):
		acabamento.filtro = (Fatiador.Filtro.SUAVE
			if String(opcoes["filtro"]).to_lower() == "suave" else Fatiador.Filtro.NEAREST)
	if opcoes.has("alfa-corte"):
		acabamento.alfa_corte = int(opcoes["alfa-corte"])
	if opcoes.has("cores"):
		acabamento.cores = int(opcoes["cores"])
	return acabamento


## Devolve quantos gravou, ou -1 se desistiu antes de escrever.
func _salva(fatiador: Fatiador, recortes: Array[Rect2i], nomes: PackedStringArray,
		saida: String, acabamento: AcabamentoArte, sobrescrever: bool) -> int:
	var erro: int = DirAccess.make_dir_recursive_absolute(saida)
	if erro != OK and erro != ERR_ALREADY_EXISTS:
		printerr("erro: nao consegui criar '%s' (codigo %d)" % [saida, erro])
		return -1

	# Arte é trabalho manual: apagar por engano o PNG que o artista já ajustou
	# no editor custa a tarde dele. Só sobrescreve quem pediu.
	if not sobrescrever:
		var existentes: PackedStringArray = PackedStringArray()
		for nome in nomes:
			if FileAccess.file_exists(saida.path_join(nome + ".png")):
				existentes.append(nome + ".png")
		if not existentes.is_empty():
			printerr("erro: %d arquivos ja existem em %s:" % [existentes.size(), saida])
			for nome in existentes:
				printerr("  %s" % nome)
			printerr("passe --sobrescrever se e isso mesmo que voce quer.")
			return -1

	var celula: int = acabamento.celula
	var escritos: int = 0
	for i in recortes.size():
		var pedaco: Image = fatiador.recorte(recortes[i], acabamento)
		if celula > 0 and (pedaco.get_width() > celula or pedaco.get_height() > celula):
			printerr("  %s: %d×%d nao cabe em %d×%d — saiu no tamanho justo. Use --encaixar."
				% [nomes[i], pedaco.get_width(), pedaco.get_height(), celula, celula])

		var destino: String = saida.path_join(nomes[i] + ".png")
		var falha: int = pedaco.save_png(destino)
		if falha != OK:
			printerr("  erro ao gravar %s (codigo %d)" % [destino, falha])
		else:
			escritos += 1
	return escritos
