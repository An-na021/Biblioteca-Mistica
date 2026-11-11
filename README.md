# Biblioteca

Jogo em Godot 4 sobre administrar uma livraria aconchegante, descobrir as leituras dos clientes e planejar a reposição das estantes.

O projeto também possui uma **API REST com SQLite e CRUD de livros, clientes e fornecedores**. Consulte [o guia da API](api/README.md) para iniciar o servidor, usar o Swagger e testar as requisições. Com o servidor ativo, novos jogos carregam o catálogo da API; partidas existentes preservam o catálogo com que foram salvas.

## Como abrir

1. Importe o arquivo `project.godot` no Godot 4.7 ou compatível.
2. Aperte **F5**.
3. Escolha **Novo jogo** ou **Continuar** no menu inicial.

## Controles e atendimento

- Clique no relógio da parede para abrir uma cena exclusiva com o relógio ampliado. Os três ponteiros acompanham o horário local do computador, com movimento contínuo e avanço proporcional das horas e minutos. **Voltar** ou **Esc** retorna à livraria. O atendimento, a chegada de clientes e o fechamento ficam suspensos durante a consulta. O relógio da parede também funciona no modo tranquilo.
- Clique no jornal **Curator's Picks** sobre o balcão para abri-lo em tela ampliada. **Voltar** ou **Esc** retorna à livraria, com o atendimento suspenso durante a leitura.

- Clique no cliente para consultar a pista do pedido, os temas favoritos e a condição preferida. O tempo fica suspenso enquanto a ficha está aberta.
- Clique na prancheta azul do balcão para abrir o estoque. A pista e a condição preferida aparecem acima da lista.
- Busque por título ou autor, com ou sem acentos. Combine filtros de tema e condição; **Limpar** restaura a lista completa.
- Escolha a condição do exemplar e use **Entregar**, **Negociar** ou **Oferecer**. O tempo continua correndo durante a consulta ao estoque no modo normal.
- Quando não houver exemplares que atendam ao pedido na condição solicitada, use **Reservar livro** no estoque. O atendimento termina sem perda de reputação e o leitor volta para buscar o pedido em outra visita.
- Clique na porta para encerrar o expediente. Se houver um cliente na loja, será preciso confirmar a saída, com perda de reputação.
- Use **Esc** ou **Pausa** para suspender o jogo, inclusive a paciência e os intervalos entre clientes. Esc também retoma a partida; feche a ficha pelo botão ×.

## Modo tranquilo

Pode ser ativado no menu inicial ou durante a pausa. Remove o limite de tempo dos atendimentos e oculta o relógio. As demais regras de venda, estoque e reputação permanecem ativas. Ao desativá-lo, a contagem retoma o tempo restante.

## Progresso salvo

O salvamento automático usa `user://biblioteca_save.json`, na pasta de dados do aplicativo gerenciada pelo Godot.

- Ao abrir um dia, salva dinheiro, estoque, custos dos exemplares, reputação, bairro, conquistas e metas.
- Ao fechar o dia, salva o resultado e as recompensas já recebidas.
- Compras, ofertas dos fornecedores e mudanças de bairro durante o fechamento também são salvas.
- **Continuar** durante um dia em andamento reinicia esse dia com os recursos da abertura. Atendimentos parciais não são salvos.
- **Continuar** após o fechamento reabre o resumo e permite comprar ou abrir o próximo dia, sem receber recompensas novamente.
- A preferência do modo tranquilo é salva separadamente, preservando o ponto de abertura do dia.
- **Novo jogo** pede confirmação quando existe progresso válido e o substitui ao iniciar.

## Sistemas disponíveis

- Oito personagens com retratos, gostos, histórias e preferências de condição.
- Pedidos por título, autor ou pistas de temas.
- Oito livros, com exemplares novos, usados, danificados ou raros.
- Três a quatro clientes por dia, conforme o bairro, sem repetição no mesmo dia. Intervalos de três a seis segundos e aviso final de cinco segundos.
- Uma lista única de livros para comprar pelo carrinho no fechamento de cada dia. A loja reúne as ofertas dos três fornecedores e usa o menor preço disponível para cada condição.
- Três bairros com catálogos e clientes diferentes, desbloqueados por dia ou reputação.
- Metas diárias e semanais, conquistas e resumo de vendas, lucro e reputação.

## Personalidades e recomendações

| Perfil | Paciência inicial | Sugestões recusadas antes de sair |
| --- | --- | --- |
| Apressado | 45 segundos | 2 |
| Indeciso | 90 segundos | 6 |
| Colecionador | 75 segundos | 4 |
| Negociador | 65 segundos | 4 |
| Exigente | 55 segundos | 3 |

O modo tranquilo remove a pressão do tempo para todos esses perfis. A luminária acrescenta dez segundos no modo normal.

Ao selecionar um exemplar no estoque, a linha **Afinidade com os gostos** indica interesse alto, moderado, baixo ou nenhum e explica os temas em comum, sem revelar a solução da pista. Temas, personalidade, condição, reputação, compras anteriores e decoração influenciam a aceitação de alternativas. Livros sem temas compatíveis ou na condição errada são recusados como alternativas. Repetir a mesma alternativa recusada não sorteia uma nova decisão naquele atendimento.

## Negociação

**Negociar** abre uma tela para definir o preço em moedas. O cliente considera o exemplar, seu perfil e a curadoria da loja. Você pode aceitar a contraproposta ou voltar ao estoque. A terceira proposta acima do limite encerra o atendimento com perda de reputação. Contrapropostas intermediárias não contam como erros. O tempo continua correndo no modo normal; pausa e modo tranquilo continuam disponíveis.

## Melhorias da livraria

No fechamento, abra **Livraria → Melhorias**. Cada melhoria é permanente, comprada uma única vez, aparece no cenário e fica salva:

| Melhoria | Preço | Benefício |
| --- | --- | --- |
| Luz de leitura | 18 moedas | Instala a luminária e acrescenta automaticamente 10 segundos à paciência de cada próximo cliente. No modo sem limite, o tempo permanece ilimitado. |
| Estante de curadoria | 26 moedas | Ao usar **NEGOCIAR** no estoque, soma 5% do preço de balcão ao limite aceito pelo cliente, com o valor final arredondado para baixo. O preço normal não muda, e a venda não é garantida. |
| Jardim do balcão | 14 moedas | Ao usar **OFERECER** para sugerir outra leitura, acrescenta 6 pontos percentuais à chance de aceitação de um livro com tema e condição adequados ao leitor. Não torna um livro incompatível aceitável nem garante a venda. |

Os benefícios entram nos atendimentos do próximo dia.

## Ateliê da livraria

O botão **ATELIÊ**, no canto inferior esquerdo do balcão, leva a outro cômodo da livraria. Os três móveis fazem parte do cenário: passe o mouse sobre eles para identificar e destacar, e clique diretamente no armário, na mesa ou na vitrine para instalar ou usar. As ações abrem numa ficha ao lado do móvel escolhido. **Voltar ao ateliê**, um clique fora da ficha ou **Esc** fecha a ficha; **Voltar à livraria**, ou outro **Esc** no cômodo, retoma o expediente. O atendimento, a paciência e a fila ficam suspensos durante toda a visita.

| Peça | Preço | Função |
| --- | --- | --- |
| Armário de encomendas | 30 moedas | Compre na loja o título e a condição encomendados. O armário protege automaticamente as cópias necessárias contra entrega, oferta e negociação para outros leitores; clique nele para conferir. O titular pode retirar sua encomenda. |
| Mesa de restauração | 10 moedas | Clique na mesa, escolha um livro danificado e a condição final: **Usado, Novo ou Raro**. Confira o preço e use **ABRIR BANCADA**. Complete a limpeza, colagem, costura e prensagem para receber a condição escolhida. Limite de um restauro por dia; materiais cobrados somente ao concluir e incorporados ao custo do exemplar. Respeita as cópias protegidas pelo armário. |
| Vitrine temática | 32 moedas | Clique na vitrine, escolha um tema e use **EXPOR ESTE TEMA**. Para cada próximo cliente, há 65% de chance de priorizar esse tema quando existem títulos compatíveis com seus gostos e bairro. Vale até trocar ou desativar; não cria livros nem garante vendas. Encomendas continuam pedindo o título e a condição combinados. |

Cada peça é comprada uma única vez. O tema permanece até ser trocado ou desativado, e o restauro volta a ficar disponível no próximo dia. Compras e ações do ateliê salvam um ponto do expediente atual: ao continuar, o mesmo atendimento ou a espera pelo próximo leitor é recuperado, com estoque, moedas, vendas anteriores e paciência preservados. Partidas sem ações no ateliê mantêm o checkpoint de abertura do dia.

Antes de abrir a bancada, o seletor de condição mostra o resultado e o orçamento de cada conserto:

| Condição final | Materiais |
| --- | --- |
| Usado | 2 moedas |
| Novo | A partir de 4 moedas |
| Raro | A partir de 7 moedas |

Os consertos superiores custam mais conforme o valor do livro. O preço mostrado na seleção, no cabeçalho e na conclusão é o valor total do conserto. **Abrir a bancada é gratuito**, inclusive com saldo zero; todas as condições continuam disponíveis para escolha. Se faltar saldo, a ficha informa quanto falta para concluir. O valor é cobrado uma única vez, somente quando a prensa termina e é aberta, e apenas se houver saldo para o conserto escolhido. A condição escolhida vale para aquele trabalho; cancelar preserva livro, moedas e limite diário. Um exemplar restaurado como Raro passa a atender os filtros e encomendas dessa condição normalmente.

A bancada é uma atividade com ferramentas e ações sobre o livro:

O pote de cola permanece visível durante todo o restauro. O pincel acompanha o cursor por toda a bancada quando selecionado e fica apoiado ao lado do pote ao usar outra ferramenta. A cola forma uma camada de tom marfim sobre as cerdas, com volume e pequenos reflexos; essa camada diminui conforme a cola é aplicada.

1. **Pincel:** segure o botão do mouse e varra as três áreas empoeiradas do livro. Acompanhe a porcentagem de limpeza e a quantidade de áreas concluídas somente no painel lateral; não há círculos ou barras sobre as páginas. A limpeza exige passadas repetidas, inclusive nas laterais da poeira. Movimentos curtos e lentos também limpam; somente passar o cursor não remove poeira. O progresso tolera resíduos muito tênues, evitando que grãos quase invisíveis impeçam avançar para a cola. Pequenas partículas acompanham a pincelada e se dissipam no ar.
2. **Cola:** clique na abertura do pote ou entre nela arrastando o pincel com o botão pressionado. Aguarde a animação curta: as cerdas descem na cola, fazem uma leve mexida e levantam com uma camada úmida; pequenas ondulações e um fio de cola acompanham a retirada. Só ao terminar o pincel fica carregado. Faça uma nova pincelada para contornar a borda de cada rasgo. A camada cresce mais devagar e exige passadas repetidas para cobrir a borda. Trocar de ferramenta ou perder o foco interrompe o mergulho sem conceder uma carga. A cola aparece somente onde o pincel passou; trechos secos impedem avançar. Cada carga cobre a borda inteira de um rasgo; recarregue para o próximo. Pincel seco não aplica cola, e apenas passar o cursor sobre o pote não o carrega.
3. **Papel / rolete:** primeiro arraste os três remendos fibrosos da bandeja até os encaixes com o mesmo formato. Um encaixe errado faz o papel voltar suavemente. O rolete fica guardado até todos os papéis estarem no lugar; nesse momento ele é equipado automaticamente, e a instrução muda para assentar os remendos. Durante o assentamento, o rolete acompanha o cursor mesmo fora dos papéis. Mantenha o botão pressionado sobre cada remendo por cerca de 5 segundos, acompanhando o progresso apenas no painel lateral. Também pode passar o rolete em qualquer direção para acelerar o assentamento; o cilindro gira conforme o movimento e muda de sentido ao voltar. Mesmo com movimentos rápidos, cada remendo exige ao menos 3 segundos acumulados de pressão. A área de contato tem margem de tolerância e o progresso é preservado ao soltar ou sair do papel. Só encaixar ou passar o cursor sem pressionar não conclui o reparo. A costura é liberada após os três remendos estarem assentados.
4. **Agulha e linha:** segure a agulha no furo dourado por um instante para atravessar o papel; depois arraste para fora da lombada, seguindo a seta, até puxar toda a linha e firmar o ponto. A linha atravessa o olho da agulha, forma uma alça e se acomoda sobre o papel. Um clique rápido ou uma puxada incompleta não conclui a passagem. Se soltar no meio, pegue a haste da agulha para continuar. Complete as oito passagens em ordem para formar quatro pontos e o nó final; a prensa abre somente com toda a costura firme.
5. **Prensa:** clique no manípulo e arraste para a direita para girar o parafuso e baixar a placa sobre o livro. Pode soltar e pegar novamente o manípulo: o aperto fica na posição. Com o aperto completo, aguarde 3,5 segundos de secagem. Depois arraste para a esquerda até levantar completamente a placa e liberar o livro. Só então o exemplar volta ao estoque na condição escolhida, os materiais são cobrados pelo orçamento exibido e o restauro do dia é consumido. Girar de volta antes da secagem completa interrompe e reinicia a secagem; apenas segurar o mouse não gira a prensa.

Ao concluir cada etapa, a bancada avança e seleciona automaticamente a próxima ferramenta. A cola nas bordas dos três rasgos seleciona **PAPEL**; o terceiro remendo alisado seleciona **AGULHA E LINHA**; o último ponto abre a **PRENSA**. A prensa acompanha os gestos com movimento suave e só inicia a secagem quando a placa encosta completamente. As ações sobre o livro continuam sendo feitas pelo jogador.

**Voltar à mesa** ou **Esc** encerra a atividade. Sair antes de concluir preserva o exemplar, as moedas e o uso diário; o trabalho parcial recomeça na próxima tentativa. O atendimento continua suspenso durante a atividade. As artes e os prompts da bancada estão em [IMG/workshop/restoration_bench.md](IMG/workshop/restoration_bench.md).

Exemplos: o armário evita vender a outro cliente a cópia rara que Mestre Elian encomendou; a mesa permite consertar um exemplar danificado do estoque; ao destacar **Magia** na vitrine, os próximos leitores têm mais chance de pedir livros desse tema. O armário não compra encomendas sozinho, e a vitrine não cria livros nem garante vendas. O cenário usa sombras e cores alinhadas à sala principal e acompanha a tonalidade do horário do jogo, preservando a legibilidade dos controles. A arte e o prompt atuais estão em [IMG/workshop/atelier_room_warm.md](IMG/workshop/atelier_room_warm.md).

## Eventos, histórias e encomendas

A cidade segue uma programação de cinco dias, que se repete: dia de descobertas, viagens, encontro arcano, poesia/natureza e raridades. O tema de hoje aparece na livraria; o próximo é anunciado no fechamento. Nos dias temáticos, pedidos relacionados aparecem com maior frequência quando há livros compatíveis no bairro. Vender o tema ou a condição anunciada acrescenta 20% do preço de balcão, arredondado para moedas, ao valor recebido. Esse bônus também entra no faturamento e no lucro.

Cada um dos oito leitores tem uma história em três compras e lembra a última leitura ou uma saída sem venda. A terceira compra concede um agradecimento e oito moedas uma única vez.

Depois da primeira compra, o leitor deixa uma encomenda para a próxima visita. Consulte o título e a condição em **Livraria → Caderno de leitores**. O Mercador da Praça inclui exemplares das encomendas pendentes em suas ofertas; o risco de avaria do fornecedor continua valendo. Entregar o título na condição combinada concede quatro moedas extras uma única vez. A encomenda permanece pendente se o cliente comprar outra leitura ou sair sem comprar.

Clientes também podem reservar um pedido sem estoque antes da primeira compra. No fechamento, a loja mostra todos os livros em uma única lista, sem abas ou seleção de fornecedor. Cada linha traz capa, título, autor, estoque, condição e botão de compra com o preço. Uma indicação junto ao livro informa quem reservou, a condição e quantos exemplares faltam; após a compra, aparece **Pronto para entregar**. A reserva só é concluída ao entregar o exemplar ao leitor. As ofertas de todos os fornecedores são reunidas automaticamente, usando o menor preço disponível para a condição escolhida; em caso de empate, vale o menor risco de avaria. Livros sem ofertas continuam visíveis como **Indisponível hoje**. O fornecedor de encomendas consegue as reservas mesmo fora do bairro. Reservas são salvas na abertura e no fechamento, junto às demais encomendas.

Memórias, encomendas e melhorias são salvas nos mesmos pontos de abertura e fechamento dos dias. Salvamentos anteriores a esses sistemas continuam compatíveis. Os presentes das histórias e encomendas aumentam o saldo, separados do lucro das vendas de livros.

O resumo distingue **erros de atendimento** (tentativas recusadas e saídas sem compra) de **clientes sem venda**. A meta de dia sem erros usa o primeiro indicador.

## Organização

- `scenes/main.tscn`: livraria e elementos interativos.
- `scenes/characters/`: cenas independentes dos clientes.
- `scripts/main_game.gd`: fluxo dos atendimentos, dias e salvamento.
- `scripts/game_menu.gd` e `scripts/save_game.gd`: menus, pausa e persistência.
- `scripts/inventory_screen.gd`: estoque, busca e filtros.
- `scripts/customer.gd`, `book_catalog.gd` e `progression_manager.gd`: regras de atendimento, catálogo e metas.
- `scripts/shop_world.gd`: personalidades, melhorias, programação de eventos e memórias.
- `scripts/negotiation_screen.gd` e `livraria_screen.gd`: propostas de preço, compras de melhorias e caderno de leitores.
- `scripts/shop_decor.gd`: alterações visuais da livraria.
- `IMG/`, `bookimg/` e `shaders/`: arte e tratamento visual.

## Verificação

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
```

As imagens ficam em `.godot/preview_*.png`.
