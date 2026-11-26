"""Carga reproduzível do serviço de reservas, com SQLite real e relógio acelerado.

Executar na raiz: python -m tools.benchmark_reservations --count 3000
Não mede rede HTTP; não espera oito minutos de tempo de parede.
"""

import argparse
import json
import platform
import statistics
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

from api.database import Database
from api.reservations import ReservationService


PROJECT = Path(__file__).resolve().parents[1]
HOLD_BOOK = "jardim_horas"
TRAFFIC_BOOK = "relogio_perdido"


class AcceleratedClock:
    """Congela a criação; salta 480 s; daí acompanha os segundos reais."""

    def __init__(self):
        self.epoch = 1_800_000_000.0
        self.started = None

    def __call__(self):
        return self.epoch if self.started is None else self.epoch + time.perf_counter() - self.started

    def start(self, advance=0):
        self.epoch += advance
        self.started = time.perf_counter()


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low = int(position)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def latency_summary(samples):
    result = {}
    for kind in ("all", "stock_read", "reserve_and_cancel"):
        durations = [sample[2] * 1000 for sample in samples if kind == "all" or sample[1] == kind]
        result[kind] = {
            "samples": len(durations),
            "p50_ms": percentile(durations, 0.50),
            "p95_ms": percentile(durations, 0.95),
            "max_ms": max(durations, default=None),
            "mean_ms": statistics.fmean(durations) if durations else None,
        }
    return result


def run_case(directory, *, name, count, batch, jitter, cache, expiry, horizon, workers, rate, poll):
    database = Database(directory / f"{name}.sqlite3")
    database.initialize()
    clock = AcceleratedClock()
    service = ReservationService(database, clock=clock, ttl_seconds=480, jitter_seconds=jitter,
                                 batch_size=batch, poll_seconds=poll)
    service.set_stock(HOLD_BOOK, count)
    service.set_stock(TRAFFIC_BOOK, workers * 4)
    preparation_start = time.perf_counter()
    for _ in range(count):
        service.reserve(HOLD_BOOK)
    preparation_seconds = time.perf_counter() - preparation_start
    if not cache:
        service.invalidate_cache()
    stop = threading.Event()
    ready = threading.Barrier(workers + 1)
    samples = []
    errors = []
    samples_lock = threading.Lock()

    def traffic(worker):
        local_samples = []
        local_errors = []
        ready.wait(timeout=20)
        index = worker
        next_request = time.perf_counter()
        while not stop.is_set():
            if time.perf_counter() < next_request:
                stop.wait(min(next_request - time.perf_counter(), 0.01))
                continue
            kind = "stock_read" if index % 2 == 0 else "reserve_and_cancel"
            started = time.perf_counter()
            try:
                if kind == "stock_read":
                    service.book_stock(TRAFFIC_BOOK)
                else:
                    held = service.reserve(TRAFFIC_BOOK)
                    service.cancel(held["id"])
                local_samples.append((started - clock.started, kind, time.perf_counter() - started))
            except Exception as error:
                local_errors.append({"kind": kind, "error": f"{type(error).__name__}: {error}"})
            index += 1
            next_request += 1 / rate
            # Não acumula uma fila ilimitada se uma rodada for mais lenta que a taxa oferecida.
            next_request = max(next_request, time.perf_counter())
        with samples_lock:
            samples.extend(local_samples)
            errors.extend(local_errors)

    completion = None
    first_release = None
    remaining = count
    cycles = 0
    last_metrics = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(traffic, worker) for worker in range(workers)]
        clock.start(480 if expiry else 0)
        ready.wait(timeout=20)
        next_poll = time.perf_counter()
        while time.perf_counter() - clock.started < horizon:
            last_metrics = service.process_due()
            cycles += 1
            remaining = service.book_stock(HOLD_BOOK)["reserved"]
            elapsed = time.perf_counter() - clock.started
            if expiry and remaining < count and first_release is None:
                first_release = elapsed
            if expiry and remaining == 0 and completion is None:
                completion = elapsed
            next_poll += poll
            # Espera no máximo um intervalo; o jitter é aplicado pelo serviço, não pelo benchmark.
            time.sleep(max(0, min(next_poll - time.perf_counter(), horizon - elapsed)))
        measured_seconds = time.perf_counter() - clock.started
        stop.set()
        for future in futures:
            future.result(timeout=15)
    # Considera as operações iniciadas dentro da janela, incluindo sua duração completa.
    samples = [sample for sample in samples if sample[0] <= horizon]
    return {
        "name": name, "batch_size": batch, "jitter_seconds": jitter,
        "schedule_cache": cache, "expiry_enabled": expiry,
        "preparation_seconds": preparation_seconds, "measured_seconds": measured_seconds,
        "poll_cycles": cycles, "reservations": count, "remaining_reserved": remaining,
        "released_percent": (count - remaining) * 100 / count if expiry else 0,
        "first_release_seconds": first_release, "all_released_seconds": completion,
        "all_released_within_5_seconds": completion is not None and completion <= 5 if expiry else None,
        "latency": latency_summary(samples), "traffic_errors": errors,
        "service_metrics": last_metrics,
    }


def benchmark(arguments):
    cases = []
    batch = arguments.batch_size
    specifications = [
        ("baseline", batch, 1, True, False),
        ("batch_1_jitter_0", 1, 0, True, True),
        ("batch_1_jitter_1", 1, 1, True, True),
        (f"batch_{batch}_jitter_0", batch, 0, True, True),
        (f"batch_{batch}_jitter_1", batch, 1, True, True),
        (f"batch_{batch}_jitter_1_db_fallback", batch, 1, False, True),
    ]
    selected_name = f"batch_{batch}_jitter_1"
    if arguments.focus:
        specifications = [case for case in specifications if case[0] in ("baseline", selected_name)]
    specifications = list({case[0]: case for case in specifications}.values())
    with tempfile.TemporaryDirectory(prefix="biblioteca_benchmark_") as temporary:
        for name, batch, jitter, cache, expiry in specifications:
            print(f"Executando {name}: {arguments.count} reservas...", flush=True)
            cases.append(run_case(Path(temporary), name=name, count=arguments.count, batch=batch,
                                  jitter=jitter, cache=cache, expiry=expiry, horizon=arguments.horizon,
                                  workers=arguments.workers, rate=arguments.rate, poll=arguments.poll))
    baseline = cases[0]["latency"]
    for case in cases[1:]:
        comparisons = {}
        for operation in ("all", "stock_read", "reserve_and_cancel"):
            before = baseline[operation]["p95_ms"]
            after = case["latency"][operation]["p95_ms"]
            ratio = after / before if before and after is not None else None
            comparisons[operation] = {"p95_ratio_to_baseline": ratio,
                                      "within_20_percent": ratio is not None and ratio <= 1.2}
        case["latency_comparison"] = comparisons
        case["criteria_passed"] = (case["all_released_within_5_seconds"]
                                   and all(item["within_20_percent"] for key, item in comparisons.items() if key != "all")
                                   and not case["traffic_errors"])
    optimized = next(case for case in cases if case["name"] == selected_name)
    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "environment": {"python": platform.python_version(), "platform": platform.platform()},
        "parameters": {"batch_size": batch, "focus": arguments.focus, "count": arguments.count,
                       "workers": arguments.workers, "rate": arguments.rate,
                       "horizon": arguments.horizon, "poll": arguments.poll},
        "selected_configuration": selected_name,
        "methodology": {
            "layer": "In-process ReservationService + real SQLite, no HTTP/network",
            "clock": "Frozen creation; jump forward 480 seconds; then follow real elapsed time",
            "expiration_ttl_seconds": 480, "release_target_seconds": 5,
            "other_operations_p95_ratio_limit": 1.2, "count_per_case": arguments.count,
            "traffic_workers": arguments.workers, "offered_operations_per_worker_second": arguments.rate,
            "traffic_mix": "Alternating stock read and reserve+cancel on a separate book",
            "observation_window_seconds": arguments.horizon, "poll_seconds": arguments.poll,
            "baseline": "Same holds and traffic, but reservations do not expire during the window",
            "limitations": ["Synthetic simultaneous deadlines; virtual passage of the initial eight minutes",
                            "Single local host and single benchmark run per configuration",
                            "Latency excludes HTTP, network and UI; this is not proof of thousands of online users"]
                           + (["Focused run: baseline and proposed configuration only; unit batch, zero jitter and cache fallback are not retested"] if arguments.focus else []),
        },
        "optimized_criteria_passed": optimized["criteria_passed"], "cases": cases,
    }


def write_markdown_report(result, destination):
    lines = ["# Resultado do benchmark de reservas", "",
             "Medição sintética local com SQLite real; os oito minutos iniciais são avançados por relógio injetável.",
             "A janela após o vencimento é medida em tempo real. A latência corresponde ao serviço, sem HTTP/rede.", "",
             "| Configuração | Liberadas | Todas em até 5 s | p95 consulta (ms) | p95 reservar/cancelar (ms) | Limite de latência (+20%) |",
             "| --- | --- | --- | --- | --- | --- |"]
    for case in result["cases"]:
        latency = case["latency"]
        comparison = case.get("latency_comparison", {})
        acceptable = all(comparison.get(key, {}).get("within_20_percent", False) for key in ("stock_read", "reserve_and_cancel")) if comparison else None
        released = f"{case['released_percent']:.1f}%" if case["expiry_enabled"] else "não expiram"
        gate = "sim" if acceptable else "não" if acceptable is False else "referência"
        target = "sim" if case["all_released_within_5_seconds"] else "não" if case["expiry_enabled"] else "referência"
        lines.append(f"| {case['name']} | {released} | {target} | {latency['stock_read']['p95_ms']:.3f} | {latency['reserve_and_cancel']['p95_ms']:.3f} | {gate} |")
    batch = result["parameters"]["batch_size"]
    json_name = destination.with_suffix(".json").name
    if result["parameters"]["focus"]:
        lines.extend(["", "Rodada focada: somente referência e proposta; os controles com lote unitário, jitter zero e fallback sem cache não foram repetidos."])
    lines.extend(["", f"**Configuração proposta (lote {batch} + jitter até 1 s + cache): {'atingiu' if result['optimized_criteria_passed'] else 'não atingiu'} todos os critérios nesta execução.**", "",
                  f"Os resultados completos, contagens, razões de latência, erros e métricas do serviço estão em [{json_name}]({json_name}).", "",
                  "Uma execução isolada não garante o mesmo comportamento em outros equipamentos ou em produção.",
                  "O teste mede milhares de reservas simultaneamente ativas, com tráfego paralelo de serviço, e não milhares de conexões HTTP.", ""])
    destination.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=3000)
    parser.add_argument("--batch-size", type=int, default=1024, help="Tamanho dos lotes da proposta e dos controles correspondentes (padrão: 1024).")
    parser.add_argument("--focus", action="store_true", help="Mede somente referência e proposta com jitter de até 1 s.")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--rate", type=float, default=100)
    parser.add_argument("--horizon", type=float, default=5)
    parser.add_argument("--poll", type=float, default=0.1)
    parser.add_argument("--output", type=Path, default=PROJECT / "output/validacao/benchmark_reservas.json")
    parser.add_argument("--strict", action="store_true", help="Retorna erro se a configuração proposta não atingir as duas metas.")
    arguments = parser.parse_args()
    if arguments.count < 1 or arguments.batch_size < 1 or arguments.workers < 1 or arguments.rate <= 0 or arguments.horizon < 5 or arguments.poll <= 0:
        parser.error("count/batch-size/workers/rate/poll precisam ser positivos; horizon deve ser pelo menos 5 segundos")
    result = benchmark(arguments)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    write_markdown_report(result, arguments.output.with_suffix(".md"))
    print(f"Resultado: {arguments.output}", flush=True)
    print(f"Critérios da configuração proposta: {result['optimized_criteria_passed']}", flush=True)
    return 1 if arguments.strict and not result["optimized_criteria_passed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
