import argparse

import uvicorn


def main():
    parser = argparse.ArgumentParser(description="API REST da Biblioteca")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    arguments = parser.parse_args()
    uvicorn.run("api.main:app", host=arguments.host, port=arguments.port)


if __name__ == "__main__":
    main()
