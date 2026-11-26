# Correspondência com a proposta original

A referência fornecida foi o documento **Documentação do Sistema de Itens Mágicos**, em um PDF de cinco páginas com requisitos e fluxogramas. A entrega adapta os itens para livros. O cenário complementar de expiração de assentos foi adaptado para exemplares por orientação recebida; autenticação e pagamento usam contas locais e moedas fictícias, também conforme orientação recebida.

## Requisitos funcionais

| ID | Requisito da referência | Implementação e demonstração |
| --- | --- | --- |
| RF01 | Validar identidade antes de transações | `AuthService`, login e sessão; reserva e checkout autenticados; verificação de proprietário; mutações administrativas autorizadas por papel. Demonstrar no portal `/portal` e em `api/tests/test_commerce.py`. |
| RF02 | Consulta detalhada de itens no estoque | Catálogo, preço, descrição e disponibilidade do portal; estoque, busca e filtros no Godot; rotas públicas de catálogo e estoque. |
| RF03 | Processar transações financeiras de forma segura | Adaptado para moedas fictícias. `CommerceService.checkout()` verifica preço no servidor, saldo e prazo e realiza débito, baixa e entrega no mesmo commit. Idempotência impede cobrança duplicada. Não há processamento de dinheiro real. |
| RF04 | Registrar encomenda quando não houver pronta entrega | No Godot, **Reservar livro** registra pedido do personagem para próxima visita, exibe necessidade na loja e persiste o compromisso. A reserva temporária da API é uma funcionalidade adicional com prazo real, descrita separadamente. |
| RF05 | Administração das configurações globais | Administrador configura nome da livraria, saldo inicial de novas contas do portal e máximo de clientes. Nome e saldo se aplicam ao portal; o limite de clientes é carregado e preservado pelo Godot junto ao catálogo da partida. Novas partidas Godot começam com zero moedas, independentemente do saldo do portal. CRUD de catálogo e ajuste de estoque também exigem administrador. |

## Requisitos não funcionais

| ID | Requisito da referência | Tratamento e limite |
| --- | --- | --- |
| RNF01 | Autenticação por serviço dedicado | `AuthService` concentra identidade, senhas derivadas com salt e sessões. É um serviço lógico dedicado, executado no mesmo processo da API, sem provedor externo. |
| RNF02 | Consulta do banco durante o atendimento | O portal consulta catálogo e estoque da API em tempo de execução. O jogo usa estoque da partida e snapshot do catálogo para funcionar offline e preservar compromissos. Essa é uma adaptação deliberada, registrada na ADR-002; não há consulta remota por cada venda de personagem. |
| RNF03 | Toda transação paga resultar em entrega ou finalização | Compra do portal debita, entrega em `owned_books` e registra pagamento atomicamente. Sem saldo ou com reserva vencida, nenhuma dessas mudanças é confirmada. A simulação Godot mantém seu fluxo local de moedas e exemplares. |

## Correspondência do fluxograma

O jogo reproduz chegada do cliente, consulta do pedido, descrição e busca do livro, verificação de disponibilidade, alternativa ou encomenda, negociação, entrega e encerramento. O portal demonstra a jornada do usuário autenticado com moedas: catálogo, disponibilidade, reserva, pagamento e entrega na biblioteca da conta.

São duas interfaces do mesmo projeto com estados de compra distintos. Comprar no portal não injeta livros ou moedas no salvamento do Godot. O portal apresenta essa informação, e o guia de instalação explica como demonstrar cada fluxo. A arquitetura conserva as responsabilidades de jogador, administrador, autenticação, pagamento e dados do diagrama original, implementadas em módulos locais.

## Cenário de qualidade

O cenário de expiração foi implementado no serviço de reservas temporárias: oito minutos, dispersão de liberação, lotes, duas fases persistentes e índice em memória reconstruível. Os testes e o benchmark constam em [CENARIO_RESERVAS.md](CENARIO_RESERVAS.md). Metas de desempenho só são declaradas atingidas quando o resultado medido correspondente permite essa conclusão.
