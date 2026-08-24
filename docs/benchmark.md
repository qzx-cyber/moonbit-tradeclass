# Benchmark notes

This repository ships a deterministic, project-owned synthetic workload so
benchmark results can be reproduced without downloading a proprietary
classification database. `src/benchmark.mbt` generates 1,000 trade records,
1,600 weighted rules, 2,000 mapping scenarios, 1,100 metric definitions, 700
threshold definitions, and 500 profiles at runtime. The generator is source
code and keeps the workload parameters deterministic, inspectable, and
reproducible across targets.

## Command

Run the native CLI from a warm build:

```powershell
1..5 | ForEach-Object {
  $m = Measure-Command {
    moon run cmd/moonbit-tradeclass --target native | Out-Null
  }
  $m.TotalMilliseconds
}
```

## Recorded baseline

On 2026-08-24, using Moon `0.1.20260824` / Moonc `v0.10.10` on the local
Windows development environment, five warm native CLI runs took 124.78 ms,
117.12 ms, 112.76 ms, 107.35 ms and 116.91 ms. The arithmetic mean was
115.78 ms and the observed range was 17.43 ms. These numbers include process
startup and native CLI execution, so they are a smoke-test baseline rather
than a claim about production hardware.

The repository CI enforces Moonc `>= v0.10.9`. Benchmark numbers must include
the toolchain, target, host and warm/cold procedure so they can be reproduced.

The CLI also reports the workload cardinalities and 60,960 mapping work units.
To compare another machine, keep the toolchain, target, input cardinalities
and warm/cold procedure fixed, then record the raw output beside the result.
