# Bridge Serialization Format Compare

Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)
Base ref: N/A
Benchmark window: 200ms
Sample count per format: 5
Benchstat alpha: 0.01
Go toolchain: go version go1.25.9 linux/amd64
Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
Comparability note: speedups may shift across host/runtime/toolchain changes; track trend deltas on equivalent environments.

| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 512 | 191961 +- 12336 | 2037 +- 72 | 94.22 | 19 | 1 | 19.00 |
| 2048 | 609108 +- 92766 | 7890 +- 198 | 77.20 | 23 | 1 | 23.00 |
| 8192 | 2238688 +- 48673 | 33515 +- 4467 | 66.80 | 27 | 1 | 27.00 |
| 16384 | 4612866 +- 354505 | 61419 +- 1230 | 75.11 | 29 | 1 | 29.00 |

## Statistical Significance (benchstat)

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/pyapi
cpu: AMD EPYC 7763 64-Core Processor                
                                   │ /tmp/tmp.UHdEIemQrv/json_norm.txt │  /tmp/tmp.UHdEIemQrv/zero_norm.txt  │
                                   │              sec/op               │    sec/op     vs base               │
CompressGradientsFormat/dim512-2                        187.091µ ± ∞ ¹   2.045µ ± ∞ ¹  -98.91% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       564.073µ ± ∞ ¹   7.873µ ± ∞ ¹  -98.60% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       2222.31µ ± ∞ ¹   30.84µ ± ∞ ¹  -98.61% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      4460.87µ ± ∞ ¹   60.80µ ± ∞ ¹  -98.64% (p=0.008 n=5)
geomean                                                   1.011m         13.18µ        -98.70%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.UHdEIemQrv/json_norm.txt │  /tmp/tmp.UHdEIemQrv/zero_norm.txt   │
                                   │               B/op                │     B/op       vs base               │
CompressGradientsFormat/dim512-2                        11.273Ki ± ∞ ¹   1.000Ki ± ∞ ¹  -91.13% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       70.898Ki ± ∞ ¹   4.000Ki ± ∞ ¹  -94.36% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       301.52Ki ± ∞ ¹   16.00Ki ± ∞ ¹  -94.69% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      573.52Ki ± ∞ ¹   32.00Ki ± ∞ ¹  -94.42% (p=0.008 n=5)
geomean                                                  108.4Ki         6.727Ki        -93.80%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.UHdEIemQrv/json_norm.txt │ /tmp/tmp.UHdEIemQrv/zero_norm.txt  │
                                   │             allocs/op             │  allocs/op   vs base               │
CompressGradientsFormat/dim512-2                          19.000 ± ∞ ¹   1.000 ± ∞ ¹  -94.74% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                         23.000 ± ∞ ¹   1.000 ± ∞ ¹  -95.65% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                         27.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.30% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                        29.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.55% (p=0.008 n=5)
geomean                                                    24.19         1.000        -95.87%
¹ need >= 6 samples for confidence interval at level 0.95
```
