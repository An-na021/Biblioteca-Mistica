# API da Biblioteca

## Requisito

Python 3.13 instalado.

## Instalar e executar

No PowerShell, na raiz do projeto:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r api/requirements.txt
.\.venv\Scripts\python.exe -m api
```

Nas próximas execuções, use apenas o último comando. Para encerrar, pressione `Ctrl+C`.

## Acessar

- API: http://127.0.0.1:8000
- Portal de contas, reservas e compras em moedas: http://127.0.0.1:8000/portal
- Documentação e testes dos endpoints: http://127.0.0.1:8000/docs
- Verificar funcionamento: http://127.0.0.1:8000/api/health

O banco SQLite é criado automaticamente em `api/data/biblioteca.sqlite3`.

## Contas e administração

Crie uma conta de jogador pelo portal. Para criar um administrador, execute na raiz:

```powershell
.\.venv\Scripts\python.exe -m api.auth create-admin administrador
```

O comando solicita a senha no terminal. Entre com essa conta no portal para administrar as configurações. No Swagger, faça login em `/api/auth/login`, copie `access_token` e informe-o no botão **Authorize**. Alterações de catálogo, estoque e configurações exigem administrador; reservas e pagamentos exigem uma conta autenticada.

As compras usam moedas fictícias e entregam livros na biblioteca da conta. Carteira e estoque do portal são separados do progresso da simulação Godot. Consulte o [guia completo](../docs/INSTALACAO_E_USO.md), a [arquitetura](../docs/ARQUITETURA.md) e o [cenário de expiração](../docs/CENARIO_RESERVAS.md).
