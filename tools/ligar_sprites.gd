extends SceneTree

## Aponta cada `.tres` para o PNG que já está em `assets/`, pela convenção.
##
##     tools\fatiar.bat --ligar --listar    (só mostra o que faria)
##     tools\fatiar.bat --ligar
##
## É o passo que fecha o caminho da arte. Recortar a folha põe os arquivos em
## `assets/`, mas o jogo continua mostrando texto até alguém abrir cada `.tres`
## e digitar o caminho — 44 caminhos, cada um uma chance de errar uma letra e só
## descobrir rodando.
##
## Duas garantias, porque `data/` é conteúdo que o artista edita à mão:
##
## - **só preenche o que está vazio.** Caminho que alguém escolheu a dedo nunca
##   é trocado; para reapontar tudo existe `--forcar`.
## - **só aponta para arquivo que existe.** Um `.tres` apontando para um PNG que
##   não chegou é pior que um `.tres` vazio: o vazio mostra o nome escrito, o
##   quebrado não mostra nada.

const PASTA_ITENS: String = "res://data/items"
const PASTA_CULTURAS: String = "res://data/crops"


func _initialize() -> void:
	var opcoes: Dictionary = _le_argumentos()
	if opcoes.has("ajuda"):
		_ajuda()
		quit(0)
		return

	var so_listar: bool = opcoes.has("listar")
	var forcar: bool = opcoes.has("forcar")

	var mudancas: Array[String] = []
	mudancas.append_array(_liga_itens(so_listar, forcar))
	mudancas.append_array(_liga_culturas(so_listar, forcar))

	if mudancas.is_empty():
		print("\nnada a ligar — ou os .tres ja apontam, ou os PNGs ainda nao chegaram.")
		print("recorte a folha primeiro: tools\\fatiar.bat")
		quit(0)
		return

	print("\n%d caminhos %s:" % [mudancas.size(), "a ligar" if so_listar else "ligados"])
	for linha in mudancas:
		print("  %s" % linha)

	if so_listar:
		print("\n--listar: nenhum .tres foi gravado.")
	else:
		print("\nrode `godot --headless --import` se algum PNG for novo.")
	quit(0)


func _ajuda() -> void:
	print("uso: tools\\fatiar.bat --ligar [opcoes]")
	print("")
	print("  --listar    so mostra o que faria, nao grava .tres nenhum")
	print("  --forcar    reaponta tambem os campos ja preenchidos")
	print("  --ajuda     isto aqui")


func _le_argumentos() -> Dictionary:
	var opcoes: Dictionary = {}
	for bruto in OS.get_cmdline_user_args():
		var argumento: String = bruto
		while argumento.begins_with("-"):
			argumento = argumento.substr(1)
		if not argumento.is_empty():
			opcoes[argumento] = true
	return opcoes


func _liga_itens(so_listar: bool, forcar: bool) -> Array[String]:
	var feitas: Array[String] = []
	for arquivo in _tres_em(PASTA_ITENS):
		var def: ItemDef = load(arquivo) as ItemDef
		if def == null:
			continue
		if not def.sprite.is_empty() and not forcar:
			continue

		var caminho: String = LigadorDeSprites.caminho_do_item(def.id)
		if not ResourceLoader.exists(caminho):
			continue
		if def.sprite == caminho:
			continue

		def.sprite = caminho
		feitas.append("%s → %s" % [def.id, caminho])
		if not so_listar:
			ResourceSaver.save(def, arquivo)
	return feitas


func _liga_culturas(so_listar: bool, forcar: bool) -> Array[String]:
	var feitas: Array[String] = []
	for arquivo in _tres_em(PASTA_CULTURAS):
		var def: CropDef = load(arquivo) as CropDef
		if def == null:
			continue

		# `dias_por_estagio.size() + 1` é a conta do próprio `CropDef`: cultura
		# com três estágios e com cinco existem no mesmo jogo.
		var quantos: int = def.dias_por_estagio.size() + 1
		var caminhos: Dictionary = LigadorDeSprites.caminhos_da_cultura(def.id, quantos)
		var mudou: bool = false

		var estagios: PackedStringArray = caminhos["estagios"]
		var novos: Array[String] = []
		for i in estagios.size():
			var atual: String = def.sprites_estagios[i] if i < def.sprites_estagios.size() else ""
			if not atual.is_empty() and not forcar:
				novos.append(atual)
				continue
			if not ResourceLoader.exists(estagios[i]):
				novos.append(atual)
				continue
			novos.append(estagios[i])
			if atual != estagios[i]:
				feitas.append("%s estágio %d → %s" % [def.id, i, estagios[i]])
				mudou = true

		if mudou or def.sprites_estagios.size() != novos.size():
			var tipado: Array[String] = []
			tipado.assign(novos)
			def.sprites_estagios = tipado
			mudou = true

		for campo in ["semente", "fruto"]:
			var caminho: String = String(caminhos[campo])
			var atual: String = def.sprite_semente if campo == "semente" else def.sprite_fruto
			if (not atual.is_empty() and not forcar) or not ResourceLoader.exists(caminho):
				continue
			if atual == caminho:
				continue
			if campo == "semente":
				def.sprite_semente = caminho
			else:
				def.sprite_fruto = caminho
			feitas.append("%s %s → %s" % [def.id, campo, caminho])
			mudou = true

		if mudou and not so_listar:
			ResourceSaver.save(def, arquivo)
	return feitas


func _tres_em(pasta: String) -> PackedStringArray:
	var arquivos: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(pasta)
	if dir == null:
		printerr("erro: nao consegui abrir %s" % pasta)
		return arquivos
	for nome in dir.get_files():
		if nome.ends_with(".tres"):
			arquivos.append(pasta.path_join(nome))
	return arquivos
