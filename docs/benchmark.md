# Benchmark notes

This repository ships a deterministic, project-owned workload so benchmark
results can be reproduced without downloading a proprietary classification
database. The workload contains 1,000 trade records, 1,600 weighted rules,
2,000 mapping scenarios, 1,100 metric definitions, 700 threshold definitions,
and 500 profiles.

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

On 2026-08-22, using Moon `0.1.20260807` / Moonc `0.10.7` on the local
Windows development environment, five warm runs took 158.02 ms, 148.79 ms,
154.94 ms, 159.67 ms and 168.86 ms. The arithmetic mean was 158.06 ms and
the observed range was 20.07 ms. These numbers include process startup and
native CLI execution, so they are a smoke-test baseline rather than a claim
about production hardware.

The CLI also reports the workload cardinalities and 60,960 mapping work units.
To compare another machine, keep the toolchain, target, input cardinalities
and warm/cold procedure fixed, then record the raw output beside the result.
