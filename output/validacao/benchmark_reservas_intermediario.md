# Resultado do benchmark de reservas

Medição sintética local com SQLite real; os oito minutos iniciais são avançados por relógio injetável.
A janela após o vencimento é medida em tempo real. A latência corresponde ao serviço, sem HTTP/rede.

| Configuração | Liberadas | Todas em até 5 s | p95 consulta (ms) | p95 reservar/cancelar (ms) | Limite de latência (+20%) |
| --- | --- | --- | --- | --- | --- |
| baseline | não expiram | referência | 108.193 | 225.885 | referência |
| batch_1_jitter_0 | 0.4% | não | 184.012 | 286.645 | não |
| batch_1_jitter_1 | 0.4% | não | 106.881 | 278.643 | não |
| batch_256_jitter_0 | 100.0% | sim | 110.119 | 279.932 | não |
| batch_256_jitter_1 | 93.9% | não | 154.112 | 320.547 | não |
| batch_256_jitter_1_db_fallback | 76.8% | não | 143.765 | 288.467 | não |

**Configuração proposta (lote 256 + jitter até 1 s + cache): não atingiu todos os critérios nesta execução.**

Os resultados completos, contagens, razões de latência, erros e métricas do serviço estão em [benchmark_reservas_intermediario.json](benchmark_reservas_intermediario.json).

Uma execução isolada não garante o mesmo comportamento em outros equipamentos ou em produção.
O teste mede milhares de reservas simultaneamente ativas, com tráfego paralelo de serviço, e não milhares de conexões HTTP.
