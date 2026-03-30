# Bridge Serialization Format Compare

Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)
Base ref: N/A
Benchmark window: 50ms
Sample count per format: 2
Benchstat alpha: 0.01

| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 512 | 172478 +- 6572 | 2526 +- 252 | 68.28 | 19 | 1 | 19.00 |
| 2048 | 673974 +- 46204 | 11490 +- 654 | 58.66 | 23 | 1 | 23.00 |
| 8192 | 2368717 +- 143240 | 36480 +- 3441 | 64.93 | 27 | 1 | 27.00 |
| 16384 | 5003474 +- 769457 | 59304 +- 5829 | 84.37 | 29 | 1 | 29.00 |

## Statistical Significance (benchstat)

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/pyapi
cpu: AMD EPYC 7763 64-Core Processor                
                                   │ /tmp/tmp.n1i1seRtw9/json_norm.txt │   /tmp/tmp.n1i1seRtw9/zero_norm.txt   │
                                   │              sec/op               │    sec/op     vs base                 │
CompressGradientsFormat/dim512-4                        172.478µ ± ∞ ¹   2.526µ ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim2048-4                        673.97µ ± ∞ ¹   11.49µ ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim8192-4                       2368.72µ ± ∞ ¹   36.48µ ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim16384-4                      5003.47µ ± ∞ ¹   59.30µ ± ∞ ¹        ~ (p=0.333 n=2) ²
geomean                                                   1.083m         15.83µ        -98.54%
¹ need >= 6 samples for confidence interval at level 0.95
² need >= 5 samples to detect a difference at alpha level 0.01

                                   │ /tmp/tmp.n1i1seRtw9/json_norm.txt │   /tmp/tmp.n1i1seRtw9/zero_norm.txt    │
                                   │               B/op                │     B/op       vs base                 │
CompressGradientsFormat/dim512-4                        11.273Ki ± ∞ ¹   1.000Ki ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim2048-4                       70.898Ki ± ∞ ¹   4.000Ki ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim8192-4                       301.53Ki ± ∞ ¹   16.00Ki ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim16384-4                      573.52Ki ± ∞ ¹   32.00Ki ± ∞ ¹        ~ (p=0.333 n=2) ²
geomean                                                  108.4Ki         6.727Ki        -93.80%
¹ need >= 6 samples for confidence interval at level 0.95
² need >= 5 samples to detect a difference at alpha level 0.01

                                   │ /tmp/tmp.n1i1seRtw9/json_norm.txt │  /tmp/tmp.n1i1seRtw9/zero_norm.txt   │
                                   │             allocs/op             │  allocs/op   vs base                 │
CompressGradientsFormat/dim512-4                          19.000 ± ∞ ¹   1.000 ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim2048-4                         23.000 ± ∞ ¹   1.000 ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim8192-4                         27.000 ± ∞ ¹   1.000 ± ∞ ¹        ~ (p=0.333 n=2) ²
CompressGradientsFormat/dim16384-4                        29.000 ± ∞ ¹   1.000 ± ∞ ¹        ~ (p=0.333 n=2) ²
geomean                                                    24.19         1.000        -95.87%
¹ need >= 6 samples for confidence interval at level 0.95
² need >= 5 samples to detect a difference at alpha level 0.01
```
