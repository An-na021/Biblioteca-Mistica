# Biblioteca

Jogo em Godot 4 sobre administrar uma livraria aconchegante, descobrir as leituras dos clientes e planejar a reposição das estantes.

O projeto também possui uma **API REST com SQLite e CRUD de livros, clientes e fornecedores**. Consulte [o guia da API](api/README.md) para iniciar o servidor, usar o Swagger e testar as requisições. Com o servidor ativo, novos jogos carregam o catálogo da API; partidas existentes preservam o catálogo com que foram salvas.

## Como abrir

1. Importe o arquivo `project.godot` no Godot 4.7 ou compatível.
2. Aperte **F5**.
3. Escolha **Novo jogo** ou **Continuar** no menu inicial.

## Controles e atendimento

- Clique no cliente para consultar a pista do pedido, os temas favoritos e a condição preferida. O tempo fica suspenso enquanto a ficha está aberta.
- Clique na prancheta azul do balcão para abrir o estoque. A pista e a condição preferida aparecem acima da lista.
- Busque por título ou autor, com ou sem acentos. Combine filtros de tema e condição; **Limpar** restaura a lista completa.
- Escolha a condição do exemplar e use **Entregar**, **Negociar** ou **Oferecer**. O tempo continua correndo durante a consulta ao estoque no modo normal.
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
- Três fornecedores com preços, estoques e riscos de avaria diferentes, acessíveis pelo carrinho no fechamento de cada dia.
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
| Luz de leitura | 18 moedas | +10 segundos de paciência |
| Estante de curadoria | 26 moedas | Até 5% extras do preço de balcão no limite de negociação |
| Jardim do balcão | 14 moedas | +6 pontos percentuais no interesse por recomendações compatíveis |

Os benefícios entram nos atendimentos do próximo dia.

## Eventos, histórias e encomendas

A cidade segue uma programação de cinco dias, que se repete: dia de descobertas, viagens, encontro arcano, poesia/natureza e raridades. O tema de hoje aparece na livraria; o próximo é anunciado no fechamento. Nos dias temáticos, pedidos relacionados aparecem com maior frequência quando há livros compatíveis no bairro. Vender o tema ou a condição anunciada acrescenta 20% do preço de balcão, arredondado para moedas, ao valor recebido. Esse bônus também entra no faturamento e no lucro.

Cada um dos oito leitores tem uma história em três compras e lembra a última leitura ou uma saída sem venda. A terceira compra concede um agradecimento e oito moedas uma única vez.

Depois da primeira compra, o leitor deixa uma encomenda para a próxima visita. Consulte o título e a condição em **Livraria → Caderno de leitores**. O Mercador da Praça inclui exemplares das encomendas pendentes em suas ofertas; o risco de avaria do fornecedor continua valendo. Entregar o título na condição combinada concede quatro moedas extras uma única vez. A encomenda permanece pendente se o cliente comprar outra leitura ou sair sem comprar.

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

Execute, usando o caminho do seu executável do Godot:

```text
godot --headless --path . --script tests/test_game.gd --log-file .godot/tests.log
godot --headless --path . --script tests/test_world.gd --log-file .godot/world_tests.log
```

Os testes usam salvamentos temporários dentro de `.godot`, sem modificar o progresso do jogador. Cobrem menus, pausa, modo tranquilo, busca, filtros, contagem de erros, compras, persistência, personalidades, recomendações, negociação, melhorias, eventos, encomendas, recompensas únicas, vários dias completos e leitura de arquivo corrompido.

Para gerar capturas das telas durante a mesma verificação:

```text
godot --path . --script tests/test_game.gd --log-file .godot/visual_tests.log -- --screenshots
godot --path . --script tests/test_world.gd --log-file .godot/world_visual_tests.log -- --screenshots
```

As imagens ficam em `.godot/preview_*.png`.
