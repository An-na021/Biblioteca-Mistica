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
- Documentação e testes dos endpoints: http://127.0.0.1:8000/docs
- Verificar funcionamento: http://127.0.0.1:8000/api/health

O banco SQLite é criado automaticamente em `api/data/biblioteca.sqlite3`.
