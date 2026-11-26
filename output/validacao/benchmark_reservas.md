# Resultado do benchmark de reservas

Medição sintética local com SQLite real; os oito minutos iniciais são avançados por relógio injetável.
A janela após o vencimento é medida em tempo real. A latência corresponde ao serviço, sem HTTP/rede.

| Configuração | Liberadas | Todas em até 5 s | p95 consulta (ms) | p95 reservar/cancelar (ms) | Limite de latência (+20%) |
| --- | --- | --- | --- | --- | --- |
| baseline | não expiram | referência | 140.250 | 271.223 | referência |
| batch_1024_jitter_1 | 100.0% | sim | 115.389 | 320.179 | sim |

Rodada focada: somente referência e proposta; os controles com lote unitário, jitter zero e fallback sem cache não foram repetidos.

**Configuração proposta (lote 1024 + jitter até 1 s + cache): atingiu todos os critérios nesta execução.**

Os resultados completos, contagens, razões de latência, erros e métricas do serviço estão em [benchmark_reservas.json](benchmark_reservas.json).

Uma execução isolada não garante o mesmo comportamento em outros equipamentos ou em produção.
O teste mede milhares de reservas simultaneamente ativas, com tráfego paralelo de serviço, e não milhares de conexões HTTP.
