# Registros de decisões arquiteturais

Projeto: **Biblioteca**. Revisão documental: **26 de novembro de 2026**.

Os dois primeiros registros documentam retrospectivamente decisões observadas no código. Os dois seguintes registram a evolução desta entrega: adaptação autorizada do cenário de expiração para exemplares e inclusão de contas locais, pagamentos em moedas fictícias e configuração administrativa conforme o PDF de referência. A correspondência e os limites estão em [ARQUITETURA.md](ARQUITETURA.md) e [REQUISITOS.md](REQUISITOS.md).

## ADR-001 - Separar módulos do jogo e integrar intenções por eventos

**Status:** adotada na implementação atual; documentada retrospectivamente.

### Contexto

O jogo reúne atendimento, estoque por condição, dias, metas, compras, reservas e restauro. Se todas as regras e telas fossem implementadas em uma única cena, novas funcionalidades dependeriam de alterações simultâneas em muitos trechos do mesmo script. A interface também precisa suspender ou retomar certos fluxos, reagir a mudanças e permitir testes do estado sem interação manual.

### Decisão

Usar a composição de cenas do Godot para apresentação e separar regras e estado em objetos dedicados, mantendo `main_game.gd` como coordenador. As intenções da interface e acontecimentos do expediente são publicados por sinais, aplicando o padrão **Observer**. O coordenador conecta esses sinais às operações de atendimento, navegação e persistência.

Os principais módulos são `Inventory`, `DayManager`, `ProgressionManager`, `ShopWorld` e `RestorationJobs`. As telas recebem os objetos necessários em métodos `setup()` e emitem sinais como `deliver_requested` e `closed`. A decomposição é pragmática: algumas regras e partes de interface permanecem no coordenador e no personagem `Customer`.

### Alternativas consideradas nesta análise

1. **Cena monolítica:** simplifica o primeiro protótipo, mas amplia o acoplamento entre interface, atendimento, tempo e salvamento.
2. **Autoload global para cada subsistema:** facilita acesso em qualquer cena, mas torna dependências e isolamento de partidas e testes menos explícitos.
3. **Camadas estritas com interfaces abstratas para todos os módulos:** aumenta a independência em relação ao motor, porém exigiria uma refatoração maior e mais abstrações do que as efetivamente usadas neste jogo.

As alternativas acima explicam os compromissos da organização atual; não são apresentadas como atas de uma discussão histórica que não está registrada.

### Consequências

**Benefícios:** regras de estoque, dias e encomendas têm pontos próprios de manutenção; sinais permitem acrescentar reações sem inserir chamadas diretas no emissor; módulos de regras podem ser exercitados em testes headless; novas telas podem publicar intenções para o coordenador.

**Custos e restrições:** conexões precisam respeitar a vida útil das telas; é necessário inspecionar assinantes para rastrear um evento; o coordenador continua grande; nem toda regra é independente da árvore de cenas. A evolução prevista é extrair fluxos conforme crescem, preservando as interfaces por eventos já utilizadas.

### Evidências no código

- `scripts/inventory.gd`: `signal changed`, emitido em `add()` e `remove()`.
- `scripts/day_manager.gd`: `customer_ready` e `store_closed`.
- `scripts/inventory_screen.gd`: sinais de entrega, oferta, negociação e reserva; `setup()` recebe o estado necessário.
- `scripts/main_game.gd`: `_ready()` conecta os eventos de dias e menu; `_open_inventory()` conecta intenções; `_handle_stock_action()` e `_complete_stock_action()` coordenam o atendimento.
- `scripts/restoration_jobs.gd`: estados e transições de encomendas em módulo próprio.

### Verificação e evolução

`tests/test_game.gd`, `tests/test_world.gd`, `tests/test_reservations.gd` e os testes de restauro exercitam os fluxos correspondentes. Resultados de execução pertencem ao relatório de validação da entrega, não são presumidos por esta ADR. Para uma nova ação, criar a regra no módulo responsável, emitir uma intenção na tela e conectar a ação no coordenador, preservando as regras de pausa e salvamento.

## ADR-002 - Catálogo em API REST com SQLite e continuidade local da partida

**Status:** adotada na implementação atual; documentada retrospectivamente.

### Contexto

Livros, clientes e fornecedores precisam de cadastro e persistência fora da interface de jogo. Ao mesmo tempo, o jogador deve conseguir abrir o aplicativo sem um servidor disponível e continuar uma partida sem que alterações administrativas removam títulos, mudem encomendas ou invalidem seu estoque.

### Decisão

Disponibilizar o catálogo por uma API REST em FastAPI, com modelos Pydantic e persistência SQLite. Construir rotas CRUD comuns por uma **Simple Factory** (`resource_router`) a partir do registro `MODELS`. A função `create_app(database_path)` compõe a aplicação com o banco escolhido e facilita testes isolados.

O Godot consulta `GET /api/catalog` pelo adaptador `catalog_api.gd`, usando `BIBLIOTECA_API_URL` ou o endereço local padrão. Se a resposta não puder ser usada, mantém o catálogo embutido. Para partidas iniciadas com catálogo da API, salva uma cópia em `catalog` no checkpoint JSON. Ao continuar, aplica a cópia salva; partidas antigas sem essa cópia preservam o catálogo local. A API administra o catálogo e os dados do portal, enquanto o salvamento da simulação Godot permanece local.

As gravações SQLite usam transações com commit ou rollback, chaves estrangeiras e validação de jogabilidade: cada bairro precisa de clientes e livros compatíveis com seus gostos e deve existir fornecedor de encomendas especiais. Os valores das consultas são parametrizados. `SaveGame` valida o JSON e escreve primeiro um arquivo temporário antes de substituir o checkpoint.

### Alternativas consideradas nesta análise

1. **Somente constantes no Godot:** mantém o jogo autônomo, mas não fornece o CRUD persistente solicitado nem uma fronteira administrativa.
2. **Jogo acessando SQLite diretamente:** elimina o HTTP, mas acopla o cliente ao esquema e aos detalhes de armazenamento e duplica a validação administrativa.
3. **API obrigatória e catálogo sempre atualizado durante a partida:** simplifica a origem dos dados, mas indisponibilidade impede jogar e exclusões podem tornar estoques ou encomendas incompatíveis.
4. **Banco servidor e serviços separados:** permite outra estratégia operacional, mas adiciona instalação e manutenção sem necessidade demonstrada para a escala local atual.

### Consequências

**Benefícios:** CRUD e documentação OpenAPI têm uma interface única; o jogo funciona com fallback local; uma partida mantém consistência com o catálogo de origem; testes podem criar banco temporário; novos registros usam as mesmas rotas e contratos, favorecendo evolução funcional.

**Custos e restrições:** novos dados da API exigem uma nova partida para uso normal; a cópia do catálogo aumenta o salvamento; há duplicação controlada entre catálogo local e semente da API; novos bairros, cenas e condições exigem alterações nos contratos; SQLite e validação integral do catálogo não comprovam escala distribuída. O setup é local; a autenticação adicionada nesta entrega é descrita na ADR-004.

### Evidências no código

- `api/main.py`: `create_app()`, `resource_router()`, rotas `/api/catalog` e `/api/health`.
- `api/models.py`: `Book`, `Customer`, `Supplier` e `MODELS`, com restrições de entrada.
- `api/database.py`: `connection()`, `initialize()`, operações CRUD e `_validate_playable()`.
- `api/schema.sql`: tabelas, relações por bairro, índices e versão de esquema.
- `scripts/catalog_api.gd`: chamada HTTP assíncrona com timeout de três segundos.
- `scripts/book_catalog.gd`: `use_api_books()`, `reset_catalog()` e fallback de consulta.
- `scripts/main_game.gd`: `_load_api_catalog()`, `_apply_catalog()`, `_save_checkpoint()` e `_continue_game()`.
- `scripts/save_game.gd`: `read_save()` e `write_save()`.

### Verificação e evolução

`api/tests/test_api.py` verifica CRUD e integridade; `api/tests/test_game_integration.py` exercita HTTP, SQLite e Godot com alterações reais de catálogo; `tests/test_catalog_api.gd` confere o consumo no jogo. Executar a integração exige configurar o executável Godot conforme o guia da API. Para escalar funcionalidades, preferir novos registros e módulos com contratos explícitos; para mudar armazenamento ou autenticação, registrar outra ADR e preparar testes e migração.

## ADR-003 - Expirar reservas temporárias de exemplares em lotes recuperáveis

**Status:** adotada nesta entrega, em 26 de novembro de 2026.

### Contexto

A proposta de desempenho descrevia milhares de reservas de assentos vencendo oito minutos após um pico. Foi autorizada sua adaptação à livraria. Cada reserva passa a reter uma quantidade de exemplares. A meta exige devolver todas as unidades em até cinco segundos após o vencimento, sem exemplares presos, e limitar o aumento de latência das outras operações a 20%.

As encomendas dos personagens são compromissos de visitas futuras, sem esse prazo real. Aplicar a elas um vencimento de oito minutos alteraria o jogo e os salvamentos existentes. O serviço de reservas temporárias, por isso, controla um estoque compartilhado da API, consumido pelo portal.

### Decisão

Criar `ReservationService`, com retenção atômica no SQLite, índice reconstruível de prazos em um heap e trabalhador periódico. O prazo de confirmação é de 480 segundos. A liberação automática recebe um deslocamento aleatório entre zero e um segundo, sem antecipar a expiração.

O trabalhador encontra até 1.024 reservas por ciclo e confirma a marcação `expired_pending_release`. Outra transação soma as quantidades por livro, devolve a disponibilidade e conclui o estado `expired`. Se houver interrupção entre os commits, o estado pendente permanece recuperável. As duas etapas são limitadas por lote; cada ciclo libera a trava antes da próxima espera. O tamanho inicial de 256 não atingiu todas as metas; o ajuste para 1.024 reduz de doze para três os ciclos mínimos necessários para 3.000 reservas e foi validado na rodada focada descrita no relatório.

O cache contém somente o índice de descoberta. O banco mantém a verdade sobre estado, prazo e quantidade. A inicialização reconstrói o heap e varreduras indexadas recuperam vencimentos ausentes do cache ou criados por outra instância. Confirmação e compra verificam o prazo no banco, mesmo antes de o trabalhador processá-lo.

### Alternativas consideradas

- Um temporizador por reserva: cria trabalho disperso e dificulta recuperação após reinício.
- Somente uma operação por reserva: simplifica o primeiro código, mas multiplica commits e atualizações do estoque durante a avalanche.
- Redis e fila externos obrigatórios: separam recursos operacionais, mas ampliam o setup. O índice local reconstruível demonstra a tática sem acrescentar infraestrutura à entrega.
- Expirar somente quando o cliente consulta: reduz trabalho de fundo, mas pode manter unidades retidas indefinidamente sem uma visita posterior.

### Consequências

O serviço oferece concorrência consistente, liberação idempotente e recuperação de falhas sem perder reservas. Novas políticas de vencimento ou outra implementação do índice podem evoluir nesse módulo. Os custos são o trabalhador de fundo, duas fases persistentes e a necessidade de observar filas e atrasos. O índice compartilha o processo, embora seja separado da persistência; não comprova distribuição física do cache nem disponibilidade de múltiplos servidores.

As metas de cinco segundos e 20% são critérios de teste, sem garantia universal. As rodadas iniciais comparam lotes de um e 256, jitter ligado e desligado e perda de cache, usando SQLite real e relógio injetável. O lote final de 1.024 foi medido contra uma referência sem expiração, mantendo a carga e as metas. Os controles de jitter desligado e perda de cache não foram repetidos para esse lote. Resultados e limites constam em `docs/VALIDACAO.md` e `output/validacao/benchmark_reservas.json`.

### Evidências e verificação

- `api/reservations.py`: retenção, cancelamento, confirmação, heap, processamento em duas fases e métricas.
- `api/schema.sql`: estoque compartilhado, reservas, estados e índices de vencimento.
- `api/main.py`: início e encerramento do trabalhador no ciclo de vida da API.
- `api/tests/test_reservations.py`: concorrência, prazo, lotes, recuperação e idempotência.
- `tools/benchmark_reservations.py`: cenário de carga e comparação das táticas.

## ADR-004 - Isolar identidade e concluir pagamento e entrega na mesma transação

**Status:** adotada nesta entrega, em 26 de novembro de 2026.

### Contexto

O PDF de referência exige validar usuários antes de transações, permitir administração e assegurar a entrega de toda compra paga. Foi definido que a entrega utiliza contas locais e moedas fictícias. É necessário evitar acesso à reserva de outra conta, cobrança duplicada e débito sem entrega.

### Decisão

Separar identidade em `AuthService`, comércio em `CommerceService` e autorização HTTP em `commerce_router.py`. Os componentes executam no mesmo processo da API, com responsabilidades e contratos próprios. O cadastro público cria apenas jogadores; administradores são criados por comando local com senha solicitada no terminal.

As senhas são armazenadas com salt e função de derivação, usando scrypt e alternativa PBKDF2-HMAC-SHA256 quando necessário. As sessões usam tokens aleatórios, dos quais somente o hash é persistido, com vencimento e revogação. Rotas de compra exigem identidade; mutações de catálogo, estoque e configurações exigem papel administrativo. A reserva fica associada ao proprietário no mesmo commit de sua criação.

O checkout obtém o preço no servidor e, em uma única transação, verifica proprietário, prazo e saldo, debita a carteira, confirma a reserva, baixa o estoque, entrega em `owned_books` e registra o pagamento. A chave de idempotência, vinculada ao usuário e à reserva, permite repetir uma tentativa sem cobrar novamente. Falhas desfazem todos esses efeitos.

Configurações globais persistidas acompanham o catálogo, permitindo ao administrador alterar parâmetros consumidos pelo jogo sem editar scripts. As configurações são preservadas no snapshot de cada partida.

### Alternativas consideradas

- Senha ou token fixo compartilhado: não identifica proprietários nem permite revogação individual.
- Identidade, débito e entrega realizados somente no navegador: permite adulteração do preço e do saldo.
- Debitar e entregar em commits independentes: cria uma janela de cobrança sem entrega.
- Provedores externos de identidade e dinheiro real: exigem contas, segredos e operação adicionais, fora do escopo local escolhido.

### Consequências

A jornada é demonstrável no portal: entrar, reservar, pagar e consultar a biblioteca. O cadastro, a autorização e as transações podem evoluir em módulos próprios. Um adaptador de pagamentos real exigiria outra ADR, contrato com provedor e tratamento de confirmação assíncrona; não é simulado como se existisse.

Carteira e biblioteca do portal são persistidas pela API; moedas e estoque da simulação Godot pertencem ao progresso local. A separação é explícita. O setup usa HTTP em loopback, sem afirmar prontidão para exposição pública ou processamento de valores reais.

### Evidências e verificação

- `api/auth.py` e `api/auth_schema.sql`: identidade, sessão, carteira e esquema dos registros comerciais.
- `api/commerce.py`: pagamento atômico, entrega, histórico e configuração.
- `api/commerce_router.py`: autenticação, autorização e contratos HTTP.
- `api/portal.html`: interface de conta, reservas, pagamento, biblioteca e administração.
- `api/tests/test_commerce.py`: papéis, propriedade, senha, sessão, saldo, rollback e idempotência concorrente.
- `tests/test_game_settings.gd`: configuração administrativa e continuidade offline da partida.

