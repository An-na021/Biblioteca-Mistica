# Livro fechado da prensa

Arte ativa: [restoration_closed_book.png](restoration_closed_book.png). Criada com ImageGen integrada, em fundo transparente, usando o livro do atlas [restoration_press_parts.png](restoration_press_parts.png) como referência.

A face longa voltada para o jogador é uma única lombada de couro, com nervuras de encadernação. As páginas ficam ocultas nesse ângulo, corrigindo a mistura impossível de lombada e páginas na mesma face. O desenho da capa escolhida continua aplicado sobre a face superior pelo jogo. A arte é posicionada pela região com conteúdo alfa, preservando a transparência original e o alinhamento com a placa da prensa.

Prompt final:

```text
Use case: precise-object-edit.
Input image role: reference sprite atlas. Edit target is ONLY the closed brown leather book in the bottom right quadrant. Output ONE isolated corrected book sprite, NOT the atlas and NOT the other press parts.
Primary request: Correct the impossible binding: replace the entire exposed ivory page block on the RIGHT HALF of the FRONT face with continuous brown leather spine matching the left half. The WHOLE long front-facing vertical side must be a single uninterrupted convex leather spine, with four evenly spaced subtle raised binding bands across its full width. NO cream pages visible anywhere in this camera view. Do not split a spine and page block along the same side.
Preserve the book's horizontal lying-flat rectangular silhouette, rich aged dark brown leather, warm upper-left amber highlights, dark ink contours, fine crosshatching and realistic subtle leather grain, slight top-down frontal camera. The top closed cover is plain brown leather with no text, no ornaments. Distinct top cover edge and lower cover edge. Natural plausible antique closed hardbound book seen from the spine side. The long side faces the camera, the broad top cover is visible as a shallow trapezoid. Match original sprite proportions: book silhouette width about three times its total height, top cover face approximately upper 48% of silhouette height and long leather spine lower 52%.
Composition: one book only, centered with clear transparent safe margin, all edges visible, true alpha transparency outside silhouette. No press, no tabletop, no hands, no background, no glow, no external shadow, no labels, no text, no watermark. The selected game's decorative cover will be applied in code to the TOP face, so leave it uniformly plain brown.
```
