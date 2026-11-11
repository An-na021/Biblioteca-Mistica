# Artes do ateliê

As três imagens desta pasta são cópias das artes geradas com a ferramenta integrada `image_gen` e apresentadas ao usuário antes da integração. A entrada do ateliê foi definida pelo usuário no canto inferior esquerdo do balcão.

- `armario_encomendas.png`: armário com nichos, livros embrulhados e etiquetas.
- `mesa_restauracao.png`: mesa de encadernação com prensa e materiais de reparo.
- `vitrine_tematica.png`: vitrine de madeira, vidro e latão com um livro exposto.
- `restoration_desk.png` e `restoration_open_book.png`: vista próxima da bancada e livro aberto para limpeza, colagem, costura e prensagem interativas. Prompts em [restoration_bench.md](restoration_bench.md).
- `restoration_brush.png`: pincel com cabo de madeira, virola de latão e cerdas detalhadas, com a ponta alinhada ao cursor. Arte e prompt em [restoration_brush.md](restoration_brush.md).
- `restoration_glue_pot.png`: pote aberto de cola, usado para carregar as cerdas antes de aplicar cola no livro. Arte e prompt em [restoration_glue_pot.md](restoration_glue_pot.md).
- `restoration_press_parts.png`: atlas ativo com estrutura, placa, manípulo e livro separados para a prensa funcional. A capa do exemplar selecionado é aplicada sobre o volume deitado. Arte, montagem e prompt em [restoration_press_parts.md](restoration_press_parts.md). `restoration_press.png` é a referência anterior, de peça única.
- `restoration_closed_book.png`: substitui o livro do atlas na prensa. A face voltada para o jogador é uma lombada contínua de couro, sem páginas expostas nessa mesma face. Arte e prompt em [restoration_closed_book.md](restoration_closed_book.md).

As peças serviram de referência para o cenário integrado `atelier_room.png`. A versão ativa é `atelier_room_warm.png`, editada com ImageGen para combinar a iluminação, as sombras e os tons de madeira com `IMG/Backgroud.png`, da tela principal. A cena `scenes/workshop_screen.tscn` também recebe a tonalidade do horário atual da livraria, aplicada apenas ao fundo. O jogador clica nos próprios móveis do ambiente; as antigas abas do catálogo foram substituídas pelas áreas interativas do cenário.

O prompt final da edição de iluminação está em [atelier_room_warm.md](atelier_room_warm.md); o da composição inicial, em [atelier_room.md](atelier_room.md). Os prompts originais das peças e a apresentação prévia estão em `art/propostas_melhorias/prompts.json` e `previa.html`.
