class_name SlotArrastavel
extends Button

## Um quadrado de slot que se arrasta. É o que dá endereço ao item na tela: o
## jogador pega e solta onde quiser, na mochila ou na hotbar.
##
## ## Por que um arquivo só para isso
##
## O arrastar do Godot mora em três métodos virtuais (`_get_drag_data`,
## `_can_drop_data`, `_drop_data`) e virtual não se sobrescreve num `Button`
## criado com `Button.new()`. Ou o painel vira uma cena, ou o quadrado vira uma
## classe — e a classe é o caminho curto: o painel continua montando slots em
## código, só troca o tipo.
##
## ## O que ele NÃO faz
##
## Ele não move item nenhum. Soltar emite `soltou(de, para)` e o painel monta a
## `MoverSlotAction` — quem move é a sim, e a tela só redesenha quando o evento
## volta. É o mesmo contrato de todo clique do playground.
##
## Hotbar e mochila são os **mesmos slots** (a hotbar é a fatia de cima da
## mochila), então arrastar de uma para a outra é mover entre índices. Não
## existem dois inventários, logo não existe um segundo caminho para dar errado.

## Alguém soltou um slot em cima deste. Os dois índices são da mochila.
signal soltou(de: int, para: int)

## Opacidade da prévia que segue o cursor: pálida o bastante para se ver o slot
## de baixo, opaca o bastante para se ler o que está na mão.
const OPACIDADE_PREVIA: float = 0.75

## Endereço deste quadrado na mochila.
var indice: int = -1
## Só slot com item começa um arrasto. Vazio é destino, nunca origem.
var tem_item: bool = false


## Começa o arrasto. Devolver `null` cancela — é assim que o slot vazio recusa
## ser origem sem precisar de um `if` em quem desenha.
func _get_drag_data(_posicao: Vector2) -> Variant:
	if not tem_item or indice < 0:
		return null
	set_drag_preview(_previa())
	return {"slot_de": indice}

## Aceita qualquer slot, inclusive o vazio: soltar num buraco é o gesto mais
## comum de todos. Quem decide se o movimento faz sentido é a sim.
func _can_drop_data(_posicao: Vector2, dado: Variant) -> bool:
	return indice >= 0 and dado is Dictionary and (dado as Dictionary).has("slot_de")

func _drop_data(_posicao: Vector2, dado: Variant) -> void:
	soltou.emit(int((dado as Dictionary)["slot_de"]), indice)

## O que acompanha o cursor: uma cópia pálida do próprio quadrado, centralizada
## no ponteiro. Sem prévia, arrastar fica cego — o jogador não sabe se pegou.
func _previa() -> Control:
	var caixa := PanelContainer.new()
	caixa.theme_type_variation = &"SlotCheio"
	caixa.modulate = Paleta.veu(Paleta.VISIVEL, OPACIDADE_PREVIA)
	caixa.custom_minimum_size = size

	var rotulo := Label.new()
	rotulo.text = text
	rotulo.theme_type_variation = &"Dado"
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caixa.add_child(rotulo)

	# O cursor segura o quadrado pelo meio, e não pelo canto: é onde o olho
	# espera que ele esteja.
	var centro := Control.new()
	centro.add_child(caixa)
	caixa.position = -size * 0.5
	return centro
