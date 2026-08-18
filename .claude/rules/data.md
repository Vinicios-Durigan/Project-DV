---
paths:
  - "data/**/*"
---

# Regras — data/ (recursos editados por artista)

Os `.tres` daqui são abertos e editados no inspector do Godot por um artista
**sem conhecimento de código**. A usabilidade no inspector é o requisito.

## Só dados

Nenhuma lógica. Sem `func` com cálculo, sem condicional, sem estado derivado.
Um `Resource` daqui guarda valores — quem interpreta é `sim/`.

## Nomes autoexplicativos

O nome da propriedade precisa fazer sentido para quem nunca viu o código.

```gdscript
@export var dias_para_colher: int          # bom
@export var gt: int                        # ruim
@export var preco_de_venda_moedas: int     # bom
@export var val: int                       # ruim
```

Inclua a unidade no nome quando houver ambiguidade (`_segundos`, `_moedas`,
`_porcento`).

## @export com hints sempre que possível

Toda propriedade exportada usa o hint mais restritivo que couber, para o
inspector virar um formulário à prova de erro:

```gdscript
@export_range(1, 30, 1) var dias_para_colher: int = 3
@export_range(0.0, 1.0, 0.05) var chance_de_bonus: float = 0.1
@export_enum("Primavera", "Verão", "Outono", "Inverno") var estacao: int = 0
@export_file("*.png") var icone_caminho: String
@export_multiline var descricao: String
@export_group("Economia")
@export var preco_de_compra_moedas: int = 10
```

Use `@export_group` / `@export_subgroup` para organizar fichas longas.
Todo campo tem valor padrão válido — o artista nunca deve começar de um estado
quebrado.
