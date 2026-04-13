# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 200ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-13T17:10:04Z
- Go toolchain: go version go1.25.9 linux/amd64
- Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
- Comparability note: performance values depend on host/runtime/toolchain; compare trends across similarly configured runs.

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.rbVfFD1kTS/base_bench.txt │ /tmp/tmp.rbVfFD1kTS/current_bench.txt │
                                                   │               sec/op               │    sec/op      vs base                │
AggregateParallel/clients32_dim2048/workers1-2                             42.11µ ± 20%    42.22µ ± 16%        ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             50.80µ ± 10%    50.36µ ±  7%        ~ (p=0.971 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             57.40µ ±  9%    55.95µ ± 10%        ~ (p=0.481 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             64.65µ ±  5%    65.67µ ±  8%        ~ (p=0.853 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          44.86µ ± 22%    46.95µ ± 11%        ~ (p=0.481 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            257.0µ ± 11%    248.1µ ±  4%        ~ (p=0.023 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            201.7µ ±  8%    176.1µ ±  7%  -12.68% (p=0.007 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            180.5µ ± 10%    179.2µ ± 13%        ~ (p=0.796 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            207.6µ ± 15%    203.6µ ±  7%        ~ (p=0.089 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         201.1µ ±  9%    185.6µ ± 20%        ~ (p=0.353 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            898.6µ ±  9%    897.6µ ±  6%        ~ (p=0.971 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            562.4µ ± 25%    601.7µ ± 21%        ~ (p=0.436 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            583.9µ ± 11%    552.7µ ± 15%        ~ (p=0.971 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            582.0µ ±  8%    566.1µ ± 35%        ~ (p=0.853 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         603.5µ ± 30%    597.3µ ± 14%        ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            1.819m ± 13%    1.748m ± 15%        ~ (p=0.190 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.017m ±  7%    1.019m ± 11%        ~ (p=0.912 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            992.3µ ± 13%    976.1µ ± 33%        ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.030m ±  8%    1.048m ± 17%        ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.005m ± 20%    1.056m ± 33%        ~ (p=0.579 n=10)
geomean                                                                    296.4µ          292.5µ         -1.30%

                                                   │ /tmp/tmp.rbVfFD1kTS/base_bench.txt │ /tmp/tmp.rbVfFD1kTS/current_bench.txt  │
                                                   │                B/s                 │      B/s        vs base                │
AggregateParallel/clients32_dim2048/workers1-2                            5.799Gi ± 17%    5.783Gi ± 14%        ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            4.806Gi ±  9%    4.848Gi ±  6%        ~ (p=0.971 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            4.253Gi ±  8%    4.364Gi ± 11%        ~ (p=0.481 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            3.777Gi ±  5%    3.718Gi ±  9%        ~ (p=0.853 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         5.444Gi ± 18%    5.200Gi ± 12%        ~ (p=0.481 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           7.600Gi ± 10%    7.873Gi ±  3%        ~ (p=0.023 n=10)
AggregateParallel/clients128_dim4096/workers2-2                           9.685Gi ±  9%   11.089Gi ±  6%  +14.50% (p=0.007 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           10.82Gi ±  9%    10.90Gi ± 14%        ~ (p=0.796 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           9.410Gi ± 13%    9.594Gi ±  7%        ~ (p=0.089 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                        9.713Gi ±  8%   10.530Gi ± 17%        ~ (p=0.353 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           8.694Gi ±  8%    8.704Gi ±  6%        ~ (p=0.971 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           13.92Gi ± 20%    12.99Gi ± 17%        ~ (p=0.436 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           13.39Gi ± 13%    14.14Gi ± 13%        ~ (p=0.971 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           13.43Gi ±  9%    13.80Gi ± 26%        ~ (p=0.853 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        12.94Gi ± 23%    13.08Gi ± 16%        ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           8.592Gi ± 11%    8.940Gi ± 13%        ~ (p=0.190 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           15.36Gi ±  7%    15.33Gi ± 10%        ~ (p=0.912 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           15.75Gi ± 11%    16.01Gi ± 25%        ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           15.17Gi ±  8%    14.92Gi ± 15%        ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        15.55Gi ± 17%    14.83Gi ± 25%        ~ (p=0.579 n=10)
geomean                                                                   9.321Gi          9.444Gi         +1.32%

                                                   │ /tmp/tmp.rbVfFD1kTS/base_bench.txt │ /tmp/tmp.rbVfFD1kTS/current_bench.txt │
                                                   │                B/op                │     B/op      vs base                 │
AggregateParallel/clients32_dim2048/workers1-2                             16.09Ki ± 0%   16.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers2-2                             24.22Ki ± 0%   24.22Ki ± 0%       ~ (p=1.000 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             40.42Ki ± 0%   40.42Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers8-2                             72.83Ki ± 0%   72.83Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workersAuto-2                          16.09Ki ± 0%   16.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers1-2                            32.09Ki ± 0%   32.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers2-2                            48.22Ki ± 0%   48.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers4-2                            80.42Ki ± 0%   80.42Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers8-2                            144.8Ki ± 0%   144.8Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workersAuto-2                         48.22Ki ± 0%   48.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers1-2                            64.09Ki ± 0%   64.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers2-2                            96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers4-2                            160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers8-2                            288.8Ki ± 0%   288.8Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workersAuto-2                         96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers1-2                            64.09Ki ± 0%   64.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers2-2                            96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers4-2                            160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers8-2                            288.8Ki ± 0%   288.8Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workersAuto-2                         96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
geomean                                                                    71.48Ki        71.48Ki       +0.00%
¹ all samples are equal

                                                   │ /tmp/tmp.rbVfFD1kTS/base_bench.txt │ /tmp/tmp.rbVfFD1kTS/current_bench.txt │
                                                   │             allocs/op              │  allocs/op    vs base                 │
AggregateParallel/clients32_dim2048/workers1-2                               5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers2-2                               9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers4-2                               15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers8-2                               27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workersAuto-2                            5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers1-2                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers2-2                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers4-2                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers8-2                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workersAuto-2                           9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers1-2                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers2-2                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers4-2                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers8-2                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workersAuto-2                           9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers1-2                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers2-2                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers4-2                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers8-2                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workersAuto-2                           9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
geomean                                                                      10.72          10.72       +0.00%
¹ all samples are equal
```
