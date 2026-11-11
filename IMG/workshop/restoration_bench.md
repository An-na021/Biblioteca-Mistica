# Artes da bancada de restauração

Criadas com a ferramenta integrada ImageGen. O fundo usa `atelier_room_warm.png` como referência de estilo e luz; o livro aberto tem fundo transparente para receber danos e reparos interativos. Os controles, os pedaços de papel e a costura são desenhados pelo jogo. A prensa usa uma arte própria detalhada; seu prompt está em [restoration_press.md](restoration_press.md).

- [restoration_desk.png](restoration_desk.png): bancada e tapete de trabalho.
- [restoration_open_book.png](restoration_open_book.png): livro aberto.

## Materiais e gestos interativos

`scripts/restoration_materials.gd` desenha e simula os materiais sobre as artes originais. A poeira é composta por grãos e fibras independentes: a faixa tocada pelas cerdas é limpa, enquanto as laterais permanecem intactas. As partículas retiradas se deslocam na direção da pincelada e se dissipam. O pincel inclina e flexiona as cerdas durante o contato.

Os rasgos revelam a página inferior sombreada e têm fibras na borda. A cola é aplicada por trechos desse contorno, consome apenas a quantidade depositada e mostra uma camada clara somente nas partes molhadas. Cada carga do pote cobre um contorno inteiro.

Os remendos usam a textura do livro, fibras finas e bordas desfiadas, com sombra e pequena inclinação ao serem levantados. Encaixes incorretos voltam suavemente para a bandeja. Após encaixar, basta segurar sobre o remendo por cerca de um segundo; passadas em qualquer direção também ajudam. A área de contato é generosa, cada remendo tem barra de progresso e o alisamento parcial é preservado ao soltar. Não há exigência de acertar regiões escondidas ou direções específicas. Um sinal verde marca cada remendo pronto. Só os três remendos alisados liberam a costura.

A costura mantém os gestos de atravessar e puxar a linha, descritos no README. A prensa usa as peças de [restoration_press_parts.md](restoration_press_parts.md), o livro corrigido de [restoration_closed_book.md](restoration_closed_book.md) e movimento amortecido: a placa precisa terminar de descer antes de iniciar a secagem e terminar de subir antes de liberar o exemplar. A cobrança continua restrita à conclusão do restauro.

Prompt da bancada:

```text
Use case: stylized-concept.
Asset type: production background illustration for an interactive bookbinding restoration workbench in a fantasy bookstore game, landscape 16:9.
Reference image: use the attached atelier only for the same dark walnut, warm amber left light, olive shadows, precise black ink contours, worn material texture and atmospheric antique storybook illustration style.
Primary request: A close overhead view of the TOP SURFACE of that wooden restoration table. Camera almost straight down, enough gentle depth to see the thick wooden front edge across the bottom. The large central working area, from x 18% to 76% and y 17% to 83%, is an EMPTY faded dark olive bookbinding cloth mat on the worn walnut surface, with quiet detailed natural weave, no object on it: a movable book will be drawn there by the game. Around far upper edge only: two softly lit paper rolls, string and small closed books, subtle and secondary. Left and right side margins are open aged wooden work surface to place game tool controls and paper fragments. NO book, NO press, NO tools in the central empty mat. No baked-in interface, captions, text, arrows, border or watermark.
Lighting: intimate dim antique room, directional warm amber light from upper left, rich brown shadows to right, no bright orange wash. Maintain useful detail in the central work mat so an old parchment book is readable against it. Beautiful hand-inked worn wood and fabric, fully illustrated, NOT photorealistic. Complete frame filled, no white empty outside borders.
```

Prompt do livro:

```text
Use case: stylized-concept.
Asset type: ONE transparent-background game sprite: an antique open book seen directly from above, landscape 4:3 proportions, isolated and fully visible with safe margin.
Primary request: A beautiful open weathered book for an interactive bookbinding restoration minigame. Front view looking straight down at two flat facing pages, spine vertical exactly down the center. Rich dark brown leather cover and page block visible around the edges. Warm aged ivory parchment pages, smooth usable surfaces for interactive paper patches, only a few faint small illegible old ink lines in upper and lower thirds of each page. The center binding seam must be clear, slightly loosened, straight and visible for sewing gameplay. Pages occupy most of the sprite. Edges worn and slightly ragged but NO missing large sections, NO huge holes and NO loose scraps; game draws damage and repairs as dynamic overlays. Symmetric left and right page spread, low curvature near central gutter, no strong perspective or angled rotation. Fine dark ink contours, delicate crosshatching, hand-painted fantasy storybook game illustration, realistic warm material shading, warm amber light from upper left and muted shadow at lower right. Not a photo, not flat vector clipart.
Constraints: book ONLY, NO hands, NO background, NO tabletop, NO brushes, NO pens, NO props, NO text labels, NO readable words, NO surrounding glow. True alpha transparency around entire silhouette and minimal natural contact shadow. Preserve detail at game sprite size.
```
