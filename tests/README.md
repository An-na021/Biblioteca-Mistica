# Verificação

Execute os comandos abaixo na raiz do projeto, onde está o arquivo `project.godot`, usando o caminho do seu executável do Godot.

Para verificar a interação do relógio, o horário real, os ponteiros, o retorno e o redimensionamento:

```text
godot --headless --path . --script tests/test_clock.gd --log-file .godot/clock_tests.log
```

Acrescente `-- --screenshots` e execute sem `--headless` para salvar as prévias em `.godot/preview_clock*.png`. A cena `scenes/clock_screen.tscn` também pode ser aberta diretamente no editor com **F6**.

Execute, usando o caminho do seu executável do Godot:

```text
godot --headless --path . --script tests/test_game.gd --log-file .godot/tests.log
godot --headless --path . --script tests/test_world.gd --log-file .godot/world_tests.log
godot --headless --path . --script tests/test_reservations.gd --log-file .godot/reservations_tests.log
godot --headless --path . --script tests/test_shop_list.gd --log-file .godot/shop_list_tests.log
```

Os testes usam salvamentos temporários dentro de `.godot`, sem modificar o progresso do jogador. Cobrem menus, pausa, modo tranquilo, busca, filtros, contagem de erros, compras, persistência, personalidades, recomendações, negociação, melhorias, eventos, encomendas, recompensas únicas, vários dias completos e leitura de arquivo corrompido.

Para gerar capturas das telas durante a mesma verificação:

```text
godot --path . --script tests/test_game.gd --log-file .godot/visual_tests.log -- --screenshots
godot --path . --script tests/test_world.gd --log-file .godot/world_visual_tests.log -- --screenshots
godot --path . --script tests/test_reservations.gd --log-file .godot/reservations_visual_tests.log -- --screenshots
godot --path . --script tests/test_book_cover_art.gd --log-file .godot/book_cover_tests.log -- --screenshots
godot --path . --script tests/test_restoration_expansion.gd --log-file .godot/restoration_expansion.log -- --screenshots
```

As imagens ficam em `.godot/preview_*.png`.

O teste de capas também grava `.godot/cover_*.png`: confere os quatro acabamentos nos oito títulos, a troca por condição no estoque e na loja e o resultado visual da restauração. Execute sem `--headless` para validar os pixels renderizados e gerar as capturas.

