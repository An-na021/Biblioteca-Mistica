# Reservas temporárias de exemplares

## Adaptação do domínio

O cenário de expiração apresentado na entrega 1 foi adaptado para uma livraria: cada reserva bloqueia uma quantidade de exemplares de um título por **oito minutos**. Uma confirmação consome os exemplares; cancelamento ou expiração devolvem sua disponibilidade.

Esse serviço é executado pela API. Seu estoque é independente do estoque de uma partida salva no Godot: as reservas de livros para visitas futuras do jogo mantêm suas regras próprias. Uma reserva temporária da API não altera o JSON do jogador, nem uma compra na partida confirma uma reserva HTTP.

## Comportamento e API

Inicie o serviço conforme o [guia de instalação](INSTALACAO_E_USO.md). As rotas podem ser exercitadas em `http://127.0.0.1:8000/docs`. Crie uma conta em `POST /api/auth/register`, faça login em `POST /api/auth/login` e use o token retornado como `Authorization: Bearer <token>`. No Swagger, use **Authorize**. O cadastro público sempre cria um jogador; administração exige uma conta com papel `admin`.

| Operação | Rota e corpo |
| --- | --- |
| Consultar disponibilidade | `GET /api/stock` |
| Definir quantidade total (admin) | `PUT /api/stock/jardim_horas`, corpo `{"total": 20}` |
| Reservar dois exemplares | `POST /api/reservations`, corpo `{"book_id": "jardim_horas", "quantity": 2}` |
| Consultar reserva | `GET /api/reservations/{id}` |
| Pagar e adquirir com moedas simuladas | `POST /api/checkout`, corpo `{"reservation_id": "<id>", "idempotency_key": "compra-001"}` |
| Confirmar manualmente (admin) | `POST /api/reservations/{id}/confirm` |
| Cancelar | `DELETE /api/reservations/{id}` |
| Consultar estado do processamento (admin) | `GET /api/reservations/metrics` |

O retorno da criação inclui `id`, `book_id`, `quantity`, `status`, `created_at` e `expires_at`. Os horários são segundos desde a época Unix. A reserva começa em `active`. Depois, pode ficar `confirmed`, `cancelled` ou `expired`.

Criar uma reserva exige login. Consulta e cancelamento exigem seu titular ou um administrador; o pagamento exige seu titular. A consulta pública de estoque não fornece dados de contas. O checkout calcula o preço no servidor, debita a carteira, confirma a reserva e registra os exemplares adquiridos numa mesma transação. O saldo e a coleção podem ser consultados em `GET /api/me` e `GET /api/library`; `GET /api/payments` mostra o histórico do titular. São moedas do projeto, sem cartão, dinheiro real ou processamento por provedor externo.

Quando um livro não tem estoque desse serviço configurado, o total inicial é dez exemplares. Defina explicitamente o estoque para demonstrações ou cenários com quantidades diferentes.

A confirmação repetida de uma reserva já confirmada não consome exemplares novamente. Cancelar uma reserva cancelada ou expirada é idempotente; cancelar uma confirmada retorna `409`. Não é possível confirmar uma reserva após seu prazo, mesmo se o trabalhador ainda não tiver processado a fila.

A disponibilidade nunca fica negativa: a verificação de saldo e o incremento da quantidade reservada ocorrem na mesma transação SQLite. A API também impede reduzir o total abaixo da quantidade já reservada e excluir um livro com exemplares ainda bloqueados.

## Separação entre marcação e liberação

O trabalhador executa ciclos a cada `0,1 s`, por padrão. A configuração final usa lotes de 1.024 reservas. Cada ciclo:

1. Encontra até 1.024 reservas vencidas e as marca como `expired_pending_release` em uma transação.
2. Em outra transação, libera até 1.024 reservas pendentes, somando as quantidades por livro antes de atualizar o estoque.

O estado intermediário é durável. Uma interrupção depois da marcação permite que outra execução conclua a liberação. A atualização condicional de estado e a transação evitam devolver o mesmo exemplar duas vezes. A resposta pública apresenta esse estado intermediário como `expired`.

Cada reserva recebe uma liberação agendada para `expires_at + jitter`, com jitter entre zero e um segundo. O prazo de oito minutos nunca é reduzido; a confirmação deixa de ser permitida em `expires_at`. O espalhamento afeta apenas a devolução automática da disponibilidade. Consultar uma reserva vencida também detecta sua expiração, sem permitir confirmação tardia.

O índice em memória é um heap de prazos, usado para acelerar a descoberta. O SQLite é a fonte de verdade: na inicialização, o índice é reconstruído; consultas indexadas ao banco recuperam trabalho criado por outra instância ou ausente do cache. `invalidate_cache()` força a busca no banco até `rebuild_schedule()` ou uma reinicialização. A perda desse cache não elimina reservas.

## Testes de correção

Na raiz do projeto, depois de instalar `api/requirements-dev.txt`:

```powershell
.\.venv\Scripts\python.exe -m unittest api.tests.test_reservations -v
```

A suíte verifica concorrência entre threads e entre instâncias do serviço, impossibilidade de reservar além do estoque, TTL sem liberação antecipada, jitter limitado, liberação em lotes, idempotência, confirmação tardia, recuperação após reinício, descarte/reconstrução de cache, interrupção entre marcação e liberação, proteção contra exclusão e o contrato HTTP.

Cada teste cria um banco temporário. O relógio injetável torna os limites do prazo verificáveis sem esperar oito minutos.

## Benchmark reproduzível

Na raiz, repita a configuração final validada sem outros testes pesados em paralelo:

```powershell
.\.venv\Scripts\python.exe -m tools.benchmark_reservations --count 3000 --batch-size 1024 --focus --strict
```

`--batch-size` controla o tamanho do lote e tem padrão 1.024, igual ao serviço. `--focus` mede somente a referência e a proposta com jitter de até um segundo. `--strict` retorna código diferente de zero quando a configuração proposta não atinge todos os critérios. Para executar também os controles, retire `--focus`; o modo completo continua sendo o padrão da ferramenta.

As saídas ficam em:

- [`output/validacao/benchmark_reservas.json`](../output/validacao/benchmark_reservas.json): parâmetros, ambiente, contagens, latências, erros e resultados por configuração.
- [`output/validacao/benchmark_reservas.md`](../output/validacao/benchmark_reservas.md): tabela de resultados para leitura.

### Método

Cada configuração recebe um banco SQLite novo e 3.000 reservas criadas com o mesmo horário de origem. A preparação usa transações reais do serviço e é medida separadamente. Em seguida, o relógio avança 480 segundos de forma controlada e passa a acompanhar o tempo real decorrido. A janela de observação após o vencimento dura cinco segundos.

Durante essa janela, quatro threads oferecem até 100 operações por segundo cada uma, alternando consultas de disponibilidade com operações de reservar e cancelar. Esse tráfego usa outro título, para não alterar as 3.000 reservas acompanhadas. As durações registram a operação completa do serviço; a operação de escrita medida inclui tanto a reserva quanto seu cancelamento.

As duas rodadas iniciais completas usaram seis configurações com lote de 256 para a proposta e seus controles:

| Configuração | Lote | Jitter máximo | Índice de prazos | Reservas vencem durante a janela? |
| --- | --- | --- | --- | --- |
| Referência | 256 | 1 s | Heap | Não |
| Lote unitário sem jitter | 1 | 0 s | Heap | Sim |
| Lote unitário com jitter | 1 | 1 s | Heap | Sim |
| Lote 256 sem jitter | 256 | 0 s | Heap | Sim |
| Proposta inicial | 256 | 1 s | Heap | Sim |
| Cache indisponível | 256 | 1 s | Busca indexada no SQLite | Sim |

Na rodada final, foram repetidas somente a referência e a proposta com lote 1.024, ambas com jitter de até um segundo. Os controles de lote unitário, jitter zero e cache indisponível não foram repetidos com lote 1.024. Para reproduzir as seis configurações originais, use `--batch-size 256` sem `--focus`; no modo completo atual, `--batch-size 1024` aplica esse lote às linhas correspondentes da proposta e dos controles.

O intervalo entre ciclos é mantido em `0,1 s`. A comparação com lote unitário mostra o custo de devolver poucas reservas por ciclo, mantendo o restante da configuração constante. A referência tem a mesma população de reservas e o mesmo tráfego, mas não provoca expiração na janela. Seus percentis servem de base para medir a interferência do processamento.

O benchmark chama `process_due()` com coleta de métricas a cada ciclo. O trabalhador da API evita essa consulta de telemetria em seus ciclos comuns e disponibiliza os indicadores sob demanda. Assim, a carga medida inclui essa consulta adicional. O jitter é sorteado por reserva; uma repetição pode produzir prazos e latências ligeiramente diferentes.

### Critérios calculados

- **Liberação:** 100% das 3.000 reservas devolvidas à disponibilidade até cinco segundos depois do vencimento, medidos em tempo real após o salto inicial do relógio.
- **Interferência:** p95 da consulta de estoque e p95 de reservar/cancelar de no máximo `1,20 ×` o p95 da referência para cada operação.
- **Correção do tráfego:** nenhuma exceção nas operações oferecidas durante a janela.

O JSON registra o resultado de cada condição e os parâmetros, incluindo `focus`; o script não fixa a aprovação. O modo `--strict` considera a configuração proposta com o lote informado em `--batch-size`, jitter de até um segundo e heap disponível. As configurações comparativas podem falhar sem impedir a produção do relatório. A emissão de JSON com código de saída zero, sem `--strict`, não significa aprovação das metas.

### Alcance da evidência

O benchmark mede um processo local do serviço com SQLite real. O relógio é acelerado somente para o período inicial de oito minutos; processamento e latências após o prazo são cronometrados. Não há espera real de oito minutos, rede, navegador, Godot, autenticação ou transporte HTTP nessa medição.

São milhares de reservas simultaneamente ativas, com operações concorrentes de serviço. Esse experimento **não demonstra milhares de usuários ou conexões HTTP simultâneos**. Também não demonstra comportamento distribuído entre máquinas. Os valores são sensíveis ao equipamento, à carga concorrente e ao estado do sistema. Uma rodada por configuração dá uma comparação local; para conclusões de produção, repita o ensaio e acrescente carga HTTP representativa.

Consulte os números efetivamente obtidos no relatório gerado e a [validação geral](VALIDACAO.md). Nenhuma meta deve ser declarada cumprida se os resultados dessa execução mostrarem falha.

## Resultados registrados nesta entrega

Foram realizadas duas rodadas completas com lote 256 e os mesmos parâmetros: 3.000 reservas por caso, quatro threads de tráfego a até 100 operações por segundo por thread, ciclos de `0,1 s` e janela de cinco segundos. As metas e o tráfego não foram reduzidos entre as rodadas. A rodada final focada alterou somente o lote da referência e da proposta para 1.024, conforme detalhado abaixo.

Na primeira, a configuração proposta liberou todos os exemplares em `2,703 s`, mas o p95 de reservar/cancelar aumentou `35,4%`, ultrapassando o limite de 20%. O resultado original foi preservado em [benchmark_reservas_inicial.json](../output/validacao/benchmark_reservas_inicial.json) e na [tabela inicial](../output/validacao/benchmark_reservas_inicial.md).

Foi então feito um ajuste para reduzir a contenção: o mutex passou a proteger somente heap e contadores em memória, as transações SQLite continuaram garantindo atomicidade, o cancelamento comum passou a usar uma única transação e ciclos sem trabalho passaram a evitar transações de escrita. O trabalhador também passou a consultar a telemetria somente quando necessário. O benchmark manteve sua coleta de métricas por ciclo.

A repetição com lote 256 não atingiu as metas. Seu resultado foi preservado em [benchmark_reservas_intermediario.json](../output/validacao/benchmark_reservas_intermediario.json) e na [tabela intermediária](../output/validacao/benchmark_reservas_intermediario.md):

| Indicador da configuração proposta | Rodada inicial | Após os ajustes |
| --- | --- | --- |
| Reservas liberadas na janela de 5 s | 100% | 93,9% |
| Tempo até a liberação de todas | 2,703 s | Não observado dentro da janela |
| p95 consulta de estoque: referência / expiração | 20,939 / 23,128 ms | 108,193 / 154,112 ms |
| Variação do p95 de consulta | +10,5% | +42,4% |
| p95 reservar/cancelar: referência / expiração | 323,556 / 438,120 ms | 225,885 / 320,547 ms |
| Variação do p95 de reservar/cancelar | +35,4% | +41,9% |
| Exceções no tráfego da janela | 0 | 0 |
| Resultado conjunto das metas | Reprovado | Reprovado |

Na segunda rodada, o caso com lote 256 e jitter zero liberou 100% em `4,740 s`, mas ainda excedeu a meta de latência de escrita em `23,9%`. O fallback sem cache liberou `76,8%` das reservas na janela. Esses casos comparativos também não demonstram atendimento completo dos critérios.

Os 33 testes de correção da API, reservas e comércio passaram depois dos ajustes, em `18,697 s`. Isso comprova os comportamentos exercitados pela suíte, incluindo concorrência e recuperação, mas não substitui a validação de desempenho.

O ambiente não foi completamente isolado. A preparação de cada caso levou de 20 a 22 segundos na primeira rodada e de 61 a 70 segundos na segunda, indicando uma diferença relevante nas condições de execução. Esses valores e a única amostra por configuração não permitem atribuir a diferença de desempenho somente ao código alterado.

As duas rodadas com lote 256 foram reprovadas; o comando com `--strict` retornou código 1 na segunda. Esses resultados permanecem disponíveis e não foram substituídos por uma alegação de aprovação do lote original.

### Ajuste final para lote 1.024

Para 3.000 reservas, um lote de 256 requer ao menos 12 ciclos para esvaziar a fila, enquanto um lote de 1.024 requer ao menos três. Foi feita uma última rodada focada para avaliar esse ajuste, mantendo as mesmas 3.000 reservas, quatro threads, oferta de até 100 operações por segundo por thread, TTL de 480 segundos, jitter máximo de um segundo, ciclos de `0,1 s` e metas originais. Não houve redução de tráfego, flexibilização das metas nem alteração da durabilidade SQLite.

| Indicador | Resultado da rodada focada com lote 1.024 |
| --- | --- |
| Reservas liberadas | 100% das 3.000 |
| Tempo até liberar todas | 1,449 s após o vencimento |
| p95 consulta: referência / expiração | 140,250 / 115,389 ms |
| Variação do p95 de consulta | -17,73% |
| p95 reservar/cancelar: referência / expiração | 271,223 / 320,179 ms |
| Variação do p95 de reservar/cancelar | +18,05% |
| Exceções no tráfego | 0 |
| Código de saída com `--strict` | 0 |

**As duas metas foram atingidas nessa execução local focada, com lote 1.024 e cache disponível.** Essa configuração foi adotada como padrão do serviço. O resultado final está em [benchmark_reservas.json](../output/validacao/benchmark_reservas.json), também preservado com nome específico em [benchmark_reservas_lote1024.json](../output/validacao/benchmark_reservas_lote1024.json).

Trata-se de uma única amostra, e o aumento de p95 de escrita de 18,05% fica próximo do limite de 20%. O resultado não é uma garantia de produção, de milhares de usuários HTTP ou de comportamento sob perda de cache com o lote novo. Os controles com lote unitário, jitter zero e fallback não foram repetidos com 1.024. A correção da recuperação de cache é avaliada pela suíte funcional; seu desempenho com o novo lote não foi medido.
