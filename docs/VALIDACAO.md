# Validação da entrega

Data de referência: **26 de novembro de 2026**. Os resultados descrevem execuções locais; não são certificação de produção ou de compatibilidade com qualquer equipamento.

## Ambiente verificado

- Windows, Python **3.13.7** e Godot **4.7.2.stable.official.ed1daf0bf**.
- API: FastAPI `0.162.0`, Uvicorn `0.54.0`, Pydantic `2.14.1`, Starlette `1.10.0` e HTTPX `0.28.1`.
- SQLite real em bancos temporários. Testes Godot usam salvamentos temporários em `.godot/`.
- O teste de integração recebe `GODOT_BIN` com o caminho completo do executável. O projeto foi testado com o renderizador configurado em `project.godot`, no modo headless para automação.

## Testes do jogo

**21 scripts e 685 verificações aprovadas**, sem falhas de script ou código de saída diferente de zero. O [resumo por script](../output/validacao/testes_godot.json) registra nomes, duração e contagens. O catálogo HTTP é verificado adicionalmente na integração Python.

Foram exercitados partida e persistência, pausa, modo tranquilo, estoque, compra, condições, reservas, negociação, mundo, progressão, personagens, relógio, jornal, janela, clima, ateliê e as etapas de restauro. O novo `test_game_settings.gd` verifica a configuração administrativa e sua recuperação offline.

Após o ajuste de balanceamento solicitado, novas partidas voltaram a iniciar com zero moedas, inclusive com a API ativa. `test_game_settings.gd` e `test_game.gd` foram reexecutados para verificar saldo inicial, salvamento e fluxo da partida. O [resultado do ajuste](../output/validacao/testes_saldo_zero.json) e o resumo por script registram essa execução. O saldo inicial configurável do portal é independente da partida.

O teste de expansão do restauro ultrapassou o limite inicial de 120 segundos durante execução concorrente. Reexecutado com limite de 300 segundos, concluiu em cerca de 111 segundos, com 100 verificações aprovadas. Esse resultado substitui o timeout inicial no resumo.

O Godot emitiu aviso sobre leitura do repositório de certificados do Windows no ambiente restrito. Os testes em questão usam recursos locais ou HTTP de loopback; não houve erro de script associado. A execução headless não comprova os pixels e as capturas que exigem renderização com janela. Os comandos dessas verificações estão no [guia de testes](../tests/README.md).

## Correção da consulta HTTP na inicialização

A verificação inicial revelou que a construção da cena podia produzir um primeiro frame longo. O temporizador baseado no delta do `HTTPRequest` expirava antes de a conexão local completar, embora o servidor estivesse disponível. O cliente passou a medir os três segundos de rede com `Time.get_ticks_msec()`, após a estabilização inicial da árvore.

A integração existente ganhou `--slow-start`, que introduz um bloqueio de cinco segundos após a construção da cena. O teste continua verificando catálogo editado, venda de livro da API, fornecedores, salvamento e continuação offline. Assim, a correção é exercitada pelo comportamento observável, sem apenas aumentar o timeout.

## API, identidade e transações

**34 testes aprovados em 55,625 segundos**, incluindo a integração HTTP, SQLite e Godot com autenticação e inicialização lenta. Nenhum teste foi ignorado nessa execução. O [resumo](../output/validacao/testes_api.json) registra comando, contagem e código zero; a [saída completa](../output/validacao/testes_api.txt) identifica os casos executados.

Os testes verificam CRUD, validação, integridade por bairro, recuperação do banco, concorrência, estoque temporário, prazo, jitter, lotes, perda de cache, interrupção entre marcação e liberação, proprietário, senha, sessão, papéis, configurações, saldo, entrega e idempotência do pagamento. O checkout insuficiente ou vencido é verificado sem débito ou entrega parcial.

O comando reproduzível para incluir a integração com Godot é:

```powershell
$env:GODOT_BIN = 'C:\caminho\Godot.exe'
.\.venv\Scripts\python.exe -m unittest discover -s api/tests -v
```

O Starlette apresenta aviso de depreciação do adaptador HTTPX utilizado pelo TestClient. A dependência fixada continua executando os testes; o aviso é registrado sem ser tratado como uma aprovação de compatibilidade futura.

## Expiração em massa

O [cenário de reservas](CENARIO_RESERVAS.md) especifica a adaptação, a carga, os critérios e os comandos. O benchmark usa seis bancos novos, 3.000 reservas por configuração, quatro threads de tráfego, a mesma oferta de operações e janela de cinco segundos. A passagem inicial de oito minutos é avançada por relógio injetável; o processamento e o tráfego posterior usam tempo real e SQLite real.

O [resultado inicial](../output/validacao/benchmark_reservas_inicial.md) foi preservado: a versão com lote 256 e jitter até um segundo liberou tudo no prazo, mas ultrapassou o aumento permitido da latência de escrita. A correção reduziu o escopo do mutex aos dados em memória, removeu bloqueios de escrita de ciclos ociosos e consultas de leitura e retirou agregações completas de métricas do trabalhador. A repetição mantém a mesma carga e metas.

Uma segunda rodada com lote 256 também reprovou: 93,9% das reservas foram liberadas em cinco segundos e as latências p95 subiram aproximadamente 42%. Ela foi preservada como [resultado intermediário](../output/validacao/benchmark_reservas_intermediario.md). O custo de preparação variou entre rodadas, portanto não se atribui a diferença de tempo exclusivamente à alteração de código.

O ajuste final aumentou o lote para **1.024**, reduzindo de doze para três o número mínimo de ciclos necessários para 3.000 reservas. A rodada focada manteve 3.000 reservas, quatro threads, oferta de 100 operações por segundo por thread, intervalo de processamento de 0,1 segundo, jitter até um segundo e janela de cinco segundos. Comparou somente a referência sem expiração com a configuração proposta:

| Medida | Referência | Expiração com lote 1.024 | Critério |
| --- | --- | --- | --- |
| Reservas liberadas | Sem expiração | 3.000 de 3.000 em **1,449 s** | 100% em até 5 s: atingido |
| p95 de consulta de estoque | 140,250 ms | 115,389 ms (-17,73%) | Aumento máximo de 20%: atingido |
| p95 de reservar e cancelar | 271,223 ms | 320,179 ms (+18,05%) | Aumento máximo de 20%: atingido |
| Exceções de tráfego | 0 | 0 | Nenhuma exceção |

O comando dessa rodada foi:

```powershell
.\.venv\Scripts\python.exe -m tools.benchmark_reservations --count 3000 --batch-size 1024 --focus --strict --output output/validacao/benchmark_reservas_lote1024.json
```

Retornou código zero. O lote validado foi adotado como padrão do serviço e da ferramenta. O [resultado final](../output/validacao/benchmark_reservas.md) e os [dados completos](../output/validacao/benchmark_reservas.json) reproduzem essa rodada focada. Os controles com jitter desligado e cache indisponível não foram repetidos para o novo lote; suas medições de lote 256 permanecem no histórico.

O teste mede milhares de reservas ativas e operações concorrentes do serviço; não mede milhares de conexões HTTP nem latência de rede. Uma execução isolada não garante que as hipóteses sejam verdadeiras em outro ambiente. A margem de escrita observada é pequena em relação ao limite de 20%; uma submissão com pretensão de produção precisa de repetições e teste no ambiente alvo.

## Portal em ambiente isolado

**15 verificações aprovadas**, com Node.js 22.21.0 e jsdom 29.1.1, sem erros de JavaScript. O [resumo](../output/validacao/testes_portal.json) registra login, cadastro, papéis, configurações, reserva e contagem de prazo, preservação de reserva após HTTP 503, pagamento, entrega, histórico e logout. A ferramenta executa o código real do portal em um DOM isolado, acessando uma API com banco e credenciais temporários. Não acessa o navegador ou contas do usuário.

## Documento e pacote

O PDF das ADRs é gerado a partir de `docs/ADRS.md`, com texto extraível e fontes incorporadas, e revisado por renderização de suas páginas. O ZIP passa por verificação de integridade e inclui manifesto SHA-256 dos arquivos. A instalação usa fontes e dependências declaradas; caches, banco local e progresso do jogador ficam fora do pacote.

A revisão visual do portal no navegador não foi executada: o host de automação de abas estava indisponível e a seleção da janela existente do Chrome foi rejeitada por expor uma sessão universitária fora do escopo. Os testes de serviços e a revisão de código não equivalem a uma validação visual de navegador.
