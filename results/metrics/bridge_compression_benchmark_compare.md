# Bridge Serialization Format Compare

Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)
Base ref: N/A
Benchmark window: 250ms
Sample count per format: 8
Benchstat alpha: 0.01
Go toolchain: go version go1.25.9 linux/amd64
Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
Comparability note: speedups may shift across host/runtime/toolchain changes; track trend deltas on equivalent environments.

| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 512 | 142777 +- 9192 | 2111 +- 120 | 67.64 | 19 | 1 | 19.00 |
| 2048 | 630460 +- 80435 | 8628 +- 445 | 73.07 | 23 | 1 | 23.00 |
| 8192 | 2243927 +- 99891 | 33236 +- 1522 | 67.51 | 27 | 1 | 27.00 |
| 16384 | 4511630 +- 279913 | 71800 +- 9453 | 62.84 | 29 | 1 | 29.00 |

## Statistical Significance (benchstat)

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/pyapi
cpu: AMD EPYC 7763 64-Core Processor                
                                   │ /tmp/tmp.oiKjkqnWYk/json_norm.txt │  /tmp/tmp.oiKjkqnWYk/zero_norm.txt  │
                                   │              sec/op               │    sec/op     vs base               │
CompressGradientsFormat/dim512-2                        140.420µ ± 10%   2.065µ ± 10%  -98.53% (p=0.000 n=8)
CompressGradientsFormat/dim2048-2                       595.512µ ± 23%   8.559µ ±  6%  -98.56% (p=0.000 n=8)
CompressGradientsFormat/dim8192-2                       2199.09µ ±  8%   32.64µ ±  5%  -98.52% (p=0.000 n=8)
CompressGradientsFormat/dim16384-2                      4413.61µ ± 11%   67.50µ ± 16%  -98.47% (p=0.000 n=8)
geomean                                                   949.2µ         14.05µ        -98.52%

                                   │ /tmp/tmp.oiKjkqnWYk/json_norm.txt │  /tmp/tmp.oiKjkqnWYk/zero_norm.txt  │
                                   │               B/op                │     B/op      vs base               │
CompressGradientsFormat/dim512-2                         11.273Ki ± 0%   1.000Ki ± 0%  -91.13% (p=0.000 n=8)
CompressGradientsFormat/dim2048-2                        70.898Ki ± 0%   4.000Ki ± 0%  -94.36% (p=0.000 n=8)
CompressGradientsFormat/dim8192-2                        301.52Ki ± 0%   16.00Ki ± 0%  -94.69% (p=0.000 n=8)
CompressGradientsFormat/dim16384-2                       573.52Ki ± 0%   32.00Ki ± 0%  -94.42% (p=0.000 n=8)
geomean                                                   108.4Ki        6.727Ki       -93.80%

                                   │ /tmp/tmp.oiKjkqnWYk/json_norm.txt │ /tmp/tmp.oiKjkqnWYk/zero_norm.txt │
                                   │             allocs/op             │ allocs/op   vs base               │
CompressGradientsFormat/dim512-2                           19.000 ± 0%   1.000 ± 0%  -94.74% (p=0.000 n=8)
CompressGradientsFormat/dim2048-2                          23.000 ± 0%   1.000 ± 0%  -95.65% (p=0.000 n=8)
CompressGradientsFormat/dim8192-2                          27.000 ± 0%   1.000 ± 0%  -96.30% (p=0.000 n=8)
CompressGradientsFormat/dim16384-2                         29.000 ± 0%   1.000 ± 0%  -96.55% (p=0.000 n=8)
geomean                                                     24.19        1.000       -95.87%
```
