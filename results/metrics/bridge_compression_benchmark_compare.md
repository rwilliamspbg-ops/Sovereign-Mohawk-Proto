# Bridge Serialization Format Compare

Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)
Base ref: N/A
Benchmark window: 200ms
Sample count per format: 5
Benchstat alpha: 0.01

| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 512 | 142519 +- 10193 | 2609 +- 369 | 54.63 | 19 | 1 | 19.00 |
| 2048 | 568858 +- 24503 | 7977 +- 376 | 71.31 | 23 | 1 | 23.00 |
| 8192 | 2318028 +- 62970 | 32431 +- 1167 | 71.48 | 27 | 1 | 27.00 |
| 16384 | 4568639 +- 138185 | 65298 +- 1845 | 69.97 | 29 | 1 | 29.00 |

## Statistical Significance (benchstat)

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/pyapi
cpu: AMD EPYC 7763 64-Core Processor                
                                   │ /tmp/tmp.cxfCuvP5GG/json_norm.txt │  /tmp/tmp.cxfCuvP5GG/zero_norm.txt  │
                                   │              sec/op               │    sec/op     vs base               │
CompressGradientsFormat/dim512-2                        136.417µ ± ∞ ¹   2.733µ ± ∞ ¹  -98.00% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       557.232µ ± ∞ ¹   7.824µ ± ∞ ¹  -98.60% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       2326.74µ ± ∞ ¹   32.91µ ± ∞ ¹  -98.59% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      4519.96µ ± ∞ ¹   64.89µ ± ∞ ¹  -98.56% (p=0.008 n=5)
geomean                                                   945.6µ         14.62µ        -98.45%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.cxfCuvP5GG/json_norm.txt │  /tmp/tmp.cxfCuvP5GG/zero_norm.txt   │
                                   │               B/op                │     B/op       vs base               │
CompressGradientsFormat/dim512-2                        11.273Ki ± ∞ ¹   1.000Ki ± ∞ ¹  -91.13% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                       70.898Ki ± ∞ ¹   4.000Ki ± ∞ ¹  -94.36% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                       301.52Ki ± ∞ ¹   16.00Ki ± ∞ ¹  -94.69% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                      573.52Ki ± ∞ ¹   32.00Ki ± ∞ ¹  -94.42% (p=0.008 n=5)
geomean                                                  108.4Ki         6.727Ki        -93.80%
¹ need >= 6 samples for confidence interval at level 0.95

                                   │ /tmp/tmp.cxfCuvP5GG/json_norm.txt │ /tmp/tmp.cxfCuvP5GG/zero_norm.txt  │
                                   │             allocs/op             │  allocs/op   vs base               │
CompressGradientsFormat/dim512-2                          19.000 ± ∞ ¹   1.000 ± ∞ ¹  -94.74% (p=0.008 n=5)
CompressGradientsFormat/dim2048-2                         23.000 ± ∞ ¹   1.000 ± ∞ ¹  -95.65% (p=0.008 n=5)
CompressGradientsFormat/dim8192-2                         27.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.30% (p=0.008 n=5)
CompressGradientsFormat/dim16384-2                        29.000 ± ∞ ¹   1.000 ± ∞ ¹  -96.55% (p=0.008 n=5)
geomean                                                    24.19         1.000        -95.87%
¹ need >= 6 samples for confidence interval at level 0.95
```
