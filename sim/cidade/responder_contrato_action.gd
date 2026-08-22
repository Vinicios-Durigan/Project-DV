class_name ResponderContratoAction
extends SimAction

## O jogador responde à encomenda que o dono deixou na mesa.
##
## Ação pura de decisão: não tira item nem dinheiro, então não estende nada do
## inventário e passa reto pelos sistemas anteriores na fila.
##
## **Recusar é grátis** e por isso cabe na mesma ação de aceitar. Quem falta com
## um dono não perde relação (PRINCIPIOS §6, a mesma filosofia da planta não
## regada); o que custa é aceitar e não cumprir. Sem essa saída, a oferta viraria
## armadilha e o jogador prudente simplesmente pararia de ir à cidade.

## Id do estabelecimento, como em `data/cidade/*.tres`.
var estabelecimento: String = ""
## `true` topa o compromisso; `false` devolve a oferta sem custo.
var aceita: bool = false
