# Instalação e uso

Este guia explica como executar o código-fonte do **Biblioteca**, um jogo de administração de livraria em Godot, e sua API com portal de contas, catálogo, reservas e compras em moedas simuladas. Os comandos devem ser executados na raiz do projeto, na pasta que contém `project.godot` e `api/`.

## 1. Requisitos

| Componente | Requisito declarado no projeto | Finalidade |
| --- | --- | --- |
| Godot | 4.7, edição padrão com GDScript | Abrir o projeto e executar o jogo. `project.godot` declara a versão 4.7 e o renderizador Compatibility (`gl_compatibility`). |
| Python | 3.13 | Executar a API, conforme o guia em `api/README.md`. Dispensável para jogar com o catálogo local. |
| pip e venv | Disponíveis na instalação do Python | Instalar as dependências da API em ambiente isolado. |
| Git | Opcional | Clonar o repositório. Também é possível usar o arquivo `.zip`. |

As versões acima são as declaradas pelos arquivos do projeto. Consulte o [relatório de validação](VALIDACAO.md) para os ambientes efetivamente verificados nesta entrega.

Dependências da API, fixadas em [`api/requirements.txt`](../api/requirements.txt): FastAPI `0.162.0`, Uvicorn `0.54.0`, Pydantic `2.14.1` e Starlette `1.10.0`. Os testes HTTP usam adicionalmente HTTPX `0.28.1`, listado em [`api/requirements-dev.txt`](../api/requirements-dev.txt). SQLite faz parte da biblioteca padrão do Python; não exige servidor separado.

## 2. Obter o projeto

Repositório: <https://github.com/An-na021/Biblioteca-master>.

Com Git:

```powershell
git clone https://github.com/An-na021/Biblioteca-master.git
cd Biblioteca-master
```

Ao receber o `.zip`, extraia todo o conteúdo e abra a pasta que contém `project.godot`. Preserve a estrutura das pastas: cenas e scripts usam caminhos relativos para imagens, shaders e outros recursos.

O pacote é uma entrega do código-fonte. Para executá-lo, use o Godot conforme o passo seguinte.

## 3. Abrir e jogar com o catálogo local

1. Abra o gerenciador de projetos do Godot.
2. Selecione **Importar** e escolha `project.godot`.
3. Aguarde a importação das imagens e dos demais recursos. A pasta `.godot/` será criada automaticamente.
4. Com o projeto aberto, pressione **F5** para executar a cena principal.
5. Aguarde a consulta inicial ao catálogo e escolha **Novo jogo** ou **Continuar**.

A API é opcional para jogar: se o serviço não responder ou o catálogo recebido for inválido, o jogo usa os dados locais e informa **Usando o catálogo local** no menu. A requisição HTTP tem limite de três segundos. A opção **Continuar** é habilitada somente quando existe um salvamento válido.

Também é possível iniciar pela linha de comando. No PowerShell, substitua o caminho abaixo pelo executável instalado:

```powershell
$godot = 'C:\caminho\Godot.exe'
& $godot --editor --path .
```

Para executar diretamente o jogo, sem abrir o editor:

```powershell
& $godot --path .
```

## 4. Instalar e iniciar a API

No PowerShell, na raiz do projeto:

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r api/requirements.txt
.\.venv\Scripts\python.exe -m api
```

Os comandos usam diretamente o Python do ambiente virtual; não é preciso ativá-lo nem alterar a política de execução de scripts do PowerShell. Nas próximas execuções, basta usar o último comando. Mantenha esse terminal aberto enquanto usa a API; **Ctrl+C** encerra o servidor.

Em Linux/macOS, com o Python correspondente instalado:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r api/requirements.txt
.venv/bin/python -m api
```

A inicialização cria automaticamente o banco `api/data/biblioteca.sqlite3`, aplica [`schema.sql`](../api/schema.sql) e carrega [`seed.json`](../api/seed.json) na primeira execução. O catálogo inicial tem oito livros, oito clientes e três fornecedores. Nas execuções seguintes, os cadastros do banco são preservados.

### Verificar o serviço

Abra no navegador:

- Saúde da API: <http://127.0.0.1:8000/api/health>. A resposta deve conter `"status": "ok"`.
- Portal da livraria: <http://127.0.0.1:8000/portal>.
- Swagger: <http://127.0.0.1:8000/docs>.
- Catálogo consumido pelo jogo: <http://127.0.0.1:8000/api/catalog>.

No PowerShell, a verificação de saúde também pode ser feita com:

```powershell
Invoke-RestMethod 'http://127.0.0.1:8000/api/health'
```

### Executar o jogo com a API

1. Inicie a API e confira a resposta de saúde.
2. Inicie o jogo pelo Godot.
3. Aguarde a mensagem **Catálogo atualizado** no menu.
4. Escolha **Novo jogo** para começar com os cadastros atuais.

Uma partida existente restaura o catálogo armazenado em seu salvamento. Portanto, editar a API e escolher **Continuar** preserva os dados daquela partida. Para observar uma alteração de catálogo em outro jogo, inicie **Novo jogo**, lembrando que a confirmação substitui o progresso anterior.

### Configurações opcionais

Para usar outra porta, inicie a API assim:

```powershell
.\.venv\Scripts\python.exe -m api --port 8001
```

Em outro terminal PowerShell, informe ao jogo o endereço correspondente e inicie o Godot a partir desse mesmo terminal:

```powershell
$env:BIBLIOTECA_API_URL = 'http://127.0.0.1:8001'
& 'C:\caminho\Godot.exe' --path .
```

O endereço padrão é `http://127.0.0.1:8000`. Para alterar o arquivo SQLite, defina `BIBLIOTECA_DB_PATH` antes de iniciar a API:

```powershell
$env:BIBLIOTECA_DB_PATH = 'C:\caminho\biblioteca.sqlite3'
.\.venv\Scripts\python.exe -m api
```

Sem essa variável, a API usa `api/data/biblioteca.sqlite3`.

### Contas, reservas e compras no portal

1. Abra `http://127.0.0.1:8000/portal`.
2. Cadastre uma conta local com nome de usuário e senha de pelo menos oito caracteres, ou entre em uma conta existente.
3. Consulte os livros, a disponibilidade e seu saldo de moedas.
4. Reserve o título e a quantidade desejada. A reserva vale por oito minutos.
5. Confirme a compra com as moedas da carteira antes do prazo. O servidor calcula o preço, debita o saldo e acrescenta os exemplares à sua biblioteca.
6. Consulte a biblioteca e o histórico de pagamentos. Use **Sair** para encerrar a sessão.

O cadastro cria uma conta com papel `player` e o saldo inicial configurado pelo administrador, por padrão 100 moedas. As sessões expiram após 12 horas e podem ser revogadas ao sair. Não existe senha compartilhada nem administrador automático.

O pagamento usa **moedas simuladas do projeto**. Não há cartão, cobrança em dinheiro real ou provedor de pagamentos. A carteira e a coleção do portal pertencem à conta local; são separadas das moedas e do estoque de uma partida Godot. **Toda nova partida Godot começa com zero moedas**, com ou sem API. O jogo obtém o catálogo público sem exigir login no portal.

As reservas temporárias, a expiração e o benchmark estão detalhados no [cenário de reservas](CENARIO_RESERVAS.md).

### Criar um administrador e ajustar configurações

Na raiz, execute o comando abaixo. Ele solicita e confirma a senha no terminal, sem incluir a senha no comando:

```powershell
.\.venv\Scripts\python.exe -m api.auth create-admin administrador
```

Entre no portal com essa conta. O papel `admin` permite alterar as configurações globais e o estoque do serviço; também autoriza as alterações de cadastros pela API. O cadastro público nunca permite escolher esse papel.

As configurações são:

| Campo | Valores aceitos | Efeito |
| --- | --- | --- |
| `starting_money` | Inteiro de 0 a 10.000 | Saldo das novas contas do portal. Não altera o dinheiro inicial da partida Godot nem redefine carteiras existentes. |
| `shop_title` | Texto de 1 a 100 caracteres | Nome da livraria disponibilizado pela API e exibido no portal. |
| `max_customers_per_day` | Inteiro de 1 a 5 | Limite diário usado por novos jogos que carregarem a configuração; continua limitado aos clientes disponíveis no bairro. |

As configurações podem ser consultadas em `GET /api/settings` e alteradas por administrador em `PATCH /api/settings`. Reinicie o jogo e inicie uma nova partida para demonstrar o limite de clientes recebido da API. Sem API, o jogo usa seu limite local. Novas partidas começam com zero moedas; continuar recupera o saldo salvo e preserva o catálogo/configuração da partida.

## 5. Usar os cadastros pelo Swagger

Na página `/docs`, as seções `books`, `customers` e `suppliers` oferecem as mesmas operações:

As consultas são públicas. Para cadastrar, alterar ou excluir, faça login como administrador em `POST /api/auth/login`, copie o campo `token` retornado e use **Authorize** no Swagger. O envio HTTP correspondente usa o cabeçalho `Authorization: Bearer <token>`. O cadastro em `POST /api/auth/register` cria somente jogadores. Uma conta sem privilégio de administrador não pode alterar os cadastros.

| Método e caminho | Uso |
| --- | --- |
| `GET /api/{recurso}` | Listar com busca `q`, filtro `tag`, paginação `limit` e `offset`; livros e clientes aceitam também `district`. |
| `GET /api/{recurso}/{id}` | Consultar um registro. |
| `POST /api/{recurso}` | Cadastrar um registro completo. |
| `PUT /api/{recurso}/{id}` | Substituir todos os campos do registro, preservando o identificador. |
| `PATCH /api/{recurso}/{id}` | Alterar somente os campos enviados. |
| `DELETE /api/{recurso}/{id}` | Excluir o registro. |

Substitua `{recurso}` por `books`, `customers` ou `suppliers`. Para testar, abra uma operação, clique em **Try it out**, preencha os parâmetros ou JSON e clique em **Execute**. O próprio Swagger apresenta os campos exigidos e os valores aceitos.

Exemplo de alteração parcial de um livro inicial:

```text
PATCH /api/books/jardim_horas
```

```json
{
  "sale_price": 19
}
```

Uma atualização bem-sucedida retorna `200`. O cadastro retorna `201` e a exclusão, `204`. Respostas `401` indicam sessão ausente/inválida; `403`, falta de permissão; `422`, dados inválidos; `404`, identificador não encontrado; `409`, identificador duplicado ou alteração que tornaria o catálogo incompatível com as regras do jogo. Nesses conflitos, a alteração é desfeita. Os preços são inteiros em moedas e o identificador não pode ser alterado.

## 6. Fluxo básico de uma partida

1. Clique no cliente para consultar o pedido, os gostos e a condição preferida. O atendimento fica suspenso enquanto a ficha está aberta.
2. Clique na prancheta azul sobre o balcão para abrir o estoque. Use a busca por título/autor e os filtros de tema e condição.
3. Selecione um exemplar e use **Entregar** para atender ao pedido, **Oferecer** para sugerir outra leitura ou **Negociar** para propor um preço.
4. Se não houver exemplar adequado, use **Reservar livro**, quando a opção estiver disponível.
5. Clique na porta para encerrar o expediente. A saída com cliente presente exige confirmação e reduz a reputação.
6. No fechamento, consulte o resultado, reponha livros pela loja, compre melhorias e abra o próximo dia.

| Controle | Ação |
| --- | --- |
| Mouse | Interagir com cliente, estoque, porta, relógio, jornal e móveis. |
| **Pausa** ou **Esc** | Suspender ou retomar a partida; em telas auxiliares, retornar conforme o contexto. |
| **Modo tranquilo** | Remover o limite de tempo de atendimento; pode ser ativado no início ou na pausa. |
| Relógio da parede | Consultar o horário local do computador em tela ampliada. |
| Jornal sobre o balcão | Abrir a leitura ampliada. |
| **ATELIÊ** | Consultar e instalar móveis, restaurar exemplares e administrar encomendas de restauro. |

No modo normal, o tempo continua correndo durante estoque e negociação. Relógio, jornal e ateliê suspendem o atendimento enquanto estão abertos. O modo tranquilo elimina a pressão do tempo e mantém as regras de estoque, vendas e reputação.

No ateliê, a mesa de restauração permite escolher um exemplar danificado e uma condição final. O diagnóstico indica as etapas necessárias: limpeza, cola, papel/rolete, costura e prensa. Siga as instruções do painel da bancada. A abertura é gratuita; os materiais são cobrados ao concluir. Sair antes da conclusão preserva o exemplar e as moedas, mas o trabalho parcial recomeça na próxima tentativa.

As regras completas de personalidades, recomendações, negociação, melhorias, bairros, encomendas, restauração e recompensas estão no [README principal](../README.md).

## 7. Salvamentos e dados

O jogo salva automaticamente em `user://biblioteca_save.json`, na pasta de dados do aplicativo gerenciada pelo Godot. No Windows, para a configuração atual do projeto, essa pasta costuma ser `%APPDATA%\Godot\app_userdata\Biblioteca\`.

- Sem ações no ateliê, continuar um dia em andamento restaura o ponto de abertura desse dia.
- Após o fechamento, continuar reabre o resumo, sem duplicar recompensas.
- Ações do ateliê criam um ponto de recuperação do expediente atual, incluindo atendimento e paciência.
- A preferência de modo tranquilo é preservada.
- **Novo jogo** pede confirmação quando existe progresso válido e substitui o salvamento ao iniciar.

O progresso do jogador e os dados SQLite são separados. O banco da API guarda cadastros, contas, carteiras, biblioteca adquirida, pagamentos, configurações e reservas temporárias; o arquivo do Godot guarda a partida e sua cópia do catálogo/configuração. Para fazer uma cópia de segurança, encerre os aplicativos e copie os arquivos de dados correspondentes para outro local.

## 8. Verificação para desenvolvimento

O [guia de testes](../tests/README.md) contém os comandos do jogo e a geração de capturas de tela. Para instalar as dependências de teste da API e executar seus testes no PowerShell:

```powershell
.\.venv\Scripts\python.exe -m pip install -r api/requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s api/tests -v
```

O teste de integração real entre HTTP, SQLite e jogo exige o Godot no `PATH` ou a variável `GODOT_BIN`:

```powershell
$env:GODOT_BIN = 'C:\caminho\Godot.exe'
.\.venv\Scripts\python.exe -m unittest api.tests.test_game_integration -v
```

Sem um executável localizável, esse teste de integração é marcado como ignorado pelo `unittest`. Os testes usam dados temporários. Resultados desta entrega devem ser consultados no [relatório de validação](VALIDACAO.md).

## 9. Problemas comuns

| Situação | Ação |
| --- | --- |
| `godot` não é reconhecido | Use o caminho completo do executável com `& 'C:\caminho\Godot.exe'` no PowerShell ou abra o editor manualmente. |
| Recursos ausentes ao importar | Confirme que todo o `.zip` foi extraído, que `project.godot` está na raiz e que as pastas de arte e cenas foram preservadas. Aguarde a importação terminar. |
| `python` não é reconhecido | Instale o Python declarado e abra outro terminal; se o lançador estiver disponível, use `py -3.13 -m venv .venv`. |
| Dependências não instaladas | Execute o `pip` pelo Python de `.venv`, usando o arquivo de requisitos correspondente. Confira a versão do Python e a saída do instalador. |
| API informa que a porta está ocupada | Encerre a instância anterior ou escolha outra porta e ajuste `BIBLIOTECA_API_URL` ao iniciar o jogo. |
| Menu informa **Usando o catálogo local** | Confira `/api/health`, o endereço configurado e o terminal da API. Reinicie o jogo após iniciar o servidor. |
| Mudanças na API não aparecem ao continuar | A partida preserva o catálogo salvo. Use um novo jogo para adotar o catálogo atualizado. |
| **Continuar** está desabilitado | Não foi encontrado um salvamento válido. Inicie um novo jogo; o leitor também rejeita arquivos corrompidos. |
| API retorna `409` ao editar/excluir | Preserve clientes por bairro, livros compatíveis com seus gostos e ao menos um fornecedor que aceite encomendas especiais. Consulte a mensagem da resposta. |
| Uma alteração retorna `401` ou `403` | Entre novamente se a sessão expirou. Alterações de catálogo, estoque e configurações exigem administrador; reservas e compras exigem a conta titular. |
| Compra informa saldo insuficiente | O portal usa moedas simuladas da carteira. Reserve uma quantidade compatível com o saldo disponível; o pagamento recusado não debita a carteira. |
| Compra informa reserva expirada | Crie uma nova reserva e conclua em até oito minutos, conforme a disponibilidade atual. |
| API retorna `503` | Confira se o arquivo e a pasta do banco podem ser acessados e se outro processo não está impedindo o uso do SQLite. |

Para entender os módulos e os pontos de extensão, consulte a [documentação de arquitetura](ARQUITETURA.md) e os [registros de decisão](ADRS.md).
