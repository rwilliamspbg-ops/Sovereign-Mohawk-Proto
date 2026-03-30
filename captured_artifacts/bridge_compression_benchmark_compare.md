# Bridge Serialization Format Compare

Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)
Base ref: N/A
Benchmark window: 200ms
Sample count per format: 5
Benchstat alpha: 0.01

| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 512 | 144510 +- 8237 | 1745 +- 33 | 82.81 | 19 | 1 | 19.00 |
| 2048 | 595417 +- 30275 | 6840 +- 378 | 87.04 | 23 | 1 | 23.00 |
| 8192 | 2446000 +- 98809 | 34438 +- 14674 | 71.03 | 27 | 1 | 27.00 |
| 16384 | 4904656 +- 248434 | 66803 +- 18571 | 73.42 | 29 | 1 | 29.00 |

## Statistical Significance (benchstat)

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/pyapi
cpu: AMD EPYC 7763 64-Core Processor                
                                   │ /tmp/tmp.O8LqYlJSel/json_norm.txt │  /tmp/tmp.O8LqYlJSel/zero_norm.txt  │
                                   │              sec/op               │    sec/op     vs base               │
CompressGradientsFormat/dim512-2                        140.852µ ± ∞ ¹   1.738µ ± ∞ ¹  -98.77% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       584.751µ ± ∞ ¹   6.713µ ± ∞ ¹  -98.85% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       2440.93µ ± ∞ ¹   28.71µ ± ∞ ¹  -98.82% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      4970.45µ ± ∞ ¹   59.85µ ± ∞ ¹  -98.80% (p=0.008 n=5)
geomean                                                   999.8µ         11.90µ        -98.81%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.O8LqYlJSel/json_norm.txt │  /tmp/tmp.O8LqYlJSel/zero_norm.txt   │
                                   │               B/op                │     B/op       vs base               │
CompressGradientsFormat/dim512-2                        11.273Ki ± ∞ ¹   1.000Ki ± ∞ ¹  -91.13% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       70.898Ki ± ∞ ¹   4.000Ki ± ∞ ¹  -94.36% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       301.52Ki ± ∞ ¹   16.00Ki ± ∞ ¹  -94.69% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      573.52Ki ± ∞ ¹   32.00Ki ± ∞ ¹  -94.42% (p=0.008 n=5)
geomean                                                  108.4Ki         6.727Ki        -93.80%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.O8LqYlJSel/json_norm.txt │ /tmp/tmp.O8LqYlJSel/zero_norm.txt  │
                                   │             allocs/op             │  allocs/op   vs base               │
CompressGradientsFormat/dim512-2                          19.000 ± ∞ ¹   1.000 ± ∞ ¹  -94.74% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                         23.000 ± ∞ ¹   1.000 ± ∞ ¹  -95.65% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                         27.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.30% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                        29.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.55% (p=0.008 n=5)
geomean                                                    24.19         1.000        -95.87%
¹ need >= 6 samples for confidence interval at level 0.95
```
