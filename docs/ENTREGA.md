# Entrega do projeto Biblioteca

Data de referência: **26 de novembro de 2026**.

## Arquivos para avaliação

- **Instalação, setup e uso:** [INSTALACAO_E_USO.md](INSTALACAO_E_USO.md).
- **Arquitetura e Design Patterns:** [ARQUITETURA.md](ARQUITETURA.md).
- **Decisões de arquitetura:** [PDF com quatro ADRs](../output/pdf/Biblioteca_ADRs.pdf), com [fonte editável](ADRS.md).
- **Adaptação da entrega 1:** [cenário de expiração de reservas de exemplares](CENARIO_RESERVAS.md).
- **Evidências de execução:** [relatório de validação](VALIDACAO.md).
- **Requisitos do documento original:** [matriz de correspondência](REQUISITOS.md).
- **Código-fonte:** <https://github.com/An-na021/Biblioteca-master>.

O pacote local `output/entrega/Biblioteca_projeto.zip` reúne código-fonte, recursos, documentação e PDF. É uma fotografia da pasta de trabalho no momento de sua geração. Alterações locais ainda não enviadas ao GitHub estão no ZIP; a URL do repositório, por si só, não comprova sua publicação.

## Funcionalidades da entrega

| Área | Funcionalidades | Evidências no projeto |
| --- | --- | --- |
| Partida | Novo jogo, continuar, pausa, modo tranquilo e salvamentos | `game_menu.gd`, `save_game.gd`, `tests/test_game.gd`, `tests/test_restart_confirmation.gd` |
| Atendimento | Pedidos por pistas, perfis, recomendações, negociação, reputação e erros | `customer.gd`, `shop_world.gd`, `tests/test_world.gd` |
| Estoque e compras | Busca, filtros, quatro condições, carrinho e ofertas de fornecedores | `inventory.gd`, `inventory_screen.gd`, `shop_screen.gd`, `tests/test_shop_list.gd`, `tests/test_order_purchases.gd` |
| Progressão | Dias, bairros, metas, melhorias, eventos, histórias e recompensas únicas | `day_manager.gd`, `progression_manager.gd`, `shop_world.gd`, `tests/test_world.gd` |
| Encomendas do jogo | Reservas de livros dos personagens e proteção de exemplares | `shop_world.gd`, `tests/test_reservations.gd`, `tests/test_workshop.gd` |
| Restauro | Diagnóstico, ferramentas, condições finais, encomendas e entrega agendada | `restoration_*.gd`, `tests/test_restoration_*.gd` |
| Ambiente e consulta | Clima, áudio, expressões, relógio real, janela e jornal ampliados | `shop_atmosphere.gd`, `clock_screen.gd`, `tests/test_atmosphere.gd`, `tests/test_clock.gd`, `tests/test_window.gd`, `tests/test_newspaper.gd` |
| Catálogo administrativo | API REST, CRUD de livros/clientes/fornecedores, validação e SQLite | `api/main.py`, `api/models.py`, `api/database.py`, `api/tests/test_api.py` |
| Integração | Catálogo HTTP, fallback local e catálogo preservado por partida | `catalog_api.gd`, `main_game.gd`, `api/tests/test_game_integration.py` |
| Cenário adaptado | Estoque compartilhado na API e reservas temporárias de exemplares com expiração automática | `api/reservations.py`, `api/tests/test_reservations.py`, `tools/benchmark_reservations.py` |
| Identidade e transações | Contas locais, sessões, autorização administrativa, carteira em moedas, pagamento idempotente e entrega | `api/auth.py`, `api/commerce.py`, `api/portal.html`, `api/tests/test_commerce.py` |
| Configuração | Administração do nome e saldo inicial de contas do portal; limite de clientes consumido e preservado no jogo. Novas partidas Godot começam com zero moedas. | `api/commerce.py`, `scripts/main_game.gd`, `tests/test_game_settings.gd` |

As reservas temporárias da API e as encomendas dos personagens têm ciclos de vida diferentes. A primeira funcionalidade demonstra o cenário de concorrência da entrega 1 na camada de serviço; o estoque da partida individual permanece no salvamento do jogo. O portal permite administrar configurações; o Swagger da API oferece os cadastros e o ajuste de estoque.

## Correspondência com a entrega 1

A referência fornecida descrevia expiração de reservas de assentos em um sistema de ingressos. A adaptação autorizada aplica esse cenário a **exemplares de livros**: assento disponível passa a significar unidade disponível; reserva de ingresso passa a significar retenção temporária de uma quantidade de exemplares.

As táticas são vencimento de oito minutos com pequena dispersão, processamento em lotes, separação entre marcação de expiração e devolução ao estoque, e índice de prazos em memória reconstruível a partir do banco. As metas permanecem: liberar todas as unidades em até cinco segundos após o vencimento, nenhum exemplar preso e aumento de latência das operações concorrentes de no máximo 20%. A medição e seus limites estão no relatório do cenário; uma meta não é tratada como resultado sem execução.

O trecho da entrega 1 não nomeia um estilo arquitetural formal. A implementação é descrita pela organização efetiva: cliente Godot e API de catálogo/estoque, com responsabilidades de apresentação, coordenação, regras e persistência. Os padrões Observer e Simple Factory e os pontos de extensão são relacionados ao código na documentação de arquitetura.

## Reprodução dos artefatos

Na raiz de um clone Git do projeto, com Git e Python disponíveis:

```powershell
.\.venv\Scripts\python.exe -m pip install -r tools/requirements-delivery.txt
.\.venv\Scripts\python.exe tools/build_delivery.py
```

O comando gera o PDF e o ZIP e verifica a integridade do pacote. `--pdf-only` gera somente o PDF; `--package-only` usa o PDF existente e dispensa instalar ReportLab. O ZIP contém os arquivos versionados e os novos arquivos não ignorados pelo Git, além de um manifesto SHA-256 de seu conteúdo. Não inclui `.git/`, `.godot/`, `.venv/`, bancos locais, arquivos de ambiente nem temporários. O hash do próprio ZIP é salvo ao lado dele em `Biblioteca_projeto.zip.sha256`.

A geração do ZIP usa a lista de arquivos do Git e requer o clone; executar o jogo a partir do ZIP não requer Git. O PDF pode ser regenerado separadamente a partir da pasta extraída.

O pacote é de código-fonte: não inclui o executável do Godot nem um jogo exportado. A primeira abertura importa os recursos, conforme o guia de instalação.
