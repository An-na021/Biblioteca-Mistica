# Biblioteca

Prototipo inicial em Godot 4 de uma livraria aconchegante com atendimento inspirado em jogos de inspecao.

## Como abrir

1. Abra o Godot 4.
2. Clique em **Importar**.
3. Selecione a pasta `Biblioteca`.
4. Abra o arquivo `project.godot`.
5. Aperte **F5** para rodar.

## O que ja funciona

- Cena principal da livraria em primeira pessoa atras do balcao.
- Porta, janela, luminaria e prancheta de estoque clicaveis.
- Feedback visual ao passar o mouse.
- Clientes com pedidos de titulos do catalogo.
- Consultar os livros disponiveis pela prancheta de estoque.
- Entregar, negociar ou oferecer um livro diretamente pelo catalogo de estoque.
- Recompensa em moedas e reputacao quando a entrega esta correta.

## Como atender um pedido

Quando um cliente chegar, clique nele para ver o pedido. Clique na prancheta para abrir o estoque e use **Entregar**, **Negociar** ou **Oferecer** em um dos livros disponiveis.

## Sistemas adicionados

- A prancheta azul no balcao abre o estoque atual, com quantidade e precos de cada titulo.
- O catalogo contem todos os livros do jogo; os pedidos podem incluir titulos esgotados.
- Cada dia tem de 3 a 5 clientes, escolhidos entre varios perfis, com intervalos aleatorios de 10 a 15 segundos entre atendimentos.
- Ao encerrar os dias 4, 8, 12 e seguintes, o mercador oferece livros para compra usando as moedas acumuladas.

## Clientes e retratos

Cada cliente tem uma cena independente em `scenes/characters/`, com um `Area2D`, o script `Customer`, seu `Sprite2D` e a área de clique. As ilustrações vetoriais transparentes usadas como textura ficam em `IMG/characters/`. A cena principal sorteia uma dessas quatro cenas quando um cliente chega.
