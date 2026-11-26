# Resultado do benchmark de reservas

Medição sintética local com SQLite real; os oito minutos iniciais são avançados por relógio injetável.
A janela após o vencimento é medida em tempo real. A latência corresponde ao serviço, sem HTTP/rede.

| Configuração | Liberadas | Todas em até 5 s | p95 consulta (ms) | p95 reservar/cancelar (ms) | Limite de latência (+20%) |
| --- | --- | --- | --- | --- | --- |
| baseline | não expiram | referência | 20.939 | 323.556 | referência |
| batch_1_jitter_0 | 1.0% | não | 23.812 | 327.594 | sim |
| batch_1_jitter_1 | 1.3% | não | 21.980 | 349.159 | sim |
| batch_256_jitter_0 | 100.0% | sim | 21.258 | 301.276 | sim |
| batch_256_jitter_1 | 100.0% | sim | 23.128 | 438.120 | não |
| batch_256_jitter_1_db_fallback | 100.0% | sim | 25.707 | 351.034 | não |

**Configuração proposta (lote 256 + jitter até 1 s + cache): não atingiu todos os critérios nesta execução.**

Os resultados completos, contagens, razões de latência, erros e métricas do serviço estão em [benchmark_reservas_inicial.json](benchmark_reservas_inicial.json).

Uma execução isolada não garante o mesmo comportamento em outros equipamentos ou em produção.
O teste mede milhares de reservas simultaneamente ativas, com tráfego paralelo de serviço, e não milhares de conexões HTTP.
