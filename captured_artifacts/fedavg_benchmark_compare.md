# FedAvg Benchmark Comparison

- Base ref: HEAD~1
- Benchtime: 200ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-13T15:35:09Z
- Go toolchain: go version go1.25.9 linux/amd64
- Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
- Comparability note: performance values depend on host/runtime/toolchain; compare trends across similarly configured runs.

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.2iLho6HxU6/base_bench.txt │ /tmp/tmp.2iLho6HxU6/current_bench.txt │
                                                   │               sec/op               │     sec/op      vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             45.88µ ± 32%     52.14µ ± 39%       ~ (p=0.247 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             51.50µ ± 12%     51.26µ ±  4%       ~ (p=0.739 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             54.04µ ±  8%     56.58µ ±  6%       ~ (p=0.436 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             67.94µ ±  6%     65.40µ ±  7%       ~ (p=0.105 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          46.04µ ± 14%     44.27µ ±  7%       ~ (p=0.165 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            254.8µ ± 11%     254.9µ ±  8%       ~ (p=0.529 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            179.1µ ± 24%     182.9µ ± 11%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            174.4µ ± 16%     183.9µ ± 11%       ~ (p=0.971 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            199.2µ ±  6%     198.9µ ± 16%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         181.1µ ± 18%     182.7µ ± 21%       ~ (p=0.631 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            918.7µ ±  7%     930.4µ ±  9%       ~ (p=0.165 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            540.2µ ± 13%     595.7µ ± 10%       ~ (p=0.105 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            585.2µ ± 20%     587.9µ ±  9%       ~ (p=0.684 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            587.8µ ± 19%     566.8µ ±  7%       ~ (p=0.190 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         549.8µ ±  9%     561.7µ ± 23%       ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            1.764m ±  7%     1.746m ±  8%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.067m ±  9%     1.044m ± 14%       ~ (p=0.853 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            980.2µ ± 15%     999.8µ ± 20%       ~ (p=0.912 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.001m ± 12%     1.004m ± 22%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         980.5µ ± 18%    1032.1µ ±  8%       ~ (p=0.393 n=10)
geomean                                                                    291.4µ           296.0µ        +1.59%

                                                   │ /tmp/tmp.2iLho6HxU6/base_bench.txt │ /tmp/tmp.2iLho6HxU6/current_bench.txt │
                                                   │                B/s                 │      B/s        vs base               │
AggregateParallel/clients32_dim2048/workers1-2                            5.325Gi ± 24%    4.686Gi ± 28%       ~ (p=0.247 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            4.741Gi ± 11%    4.763Gi ±  4%       ~ (p=0.739 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            4.518Gi ±  7%    4.315Gi ±  6%       ~ (p=0.436 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            3.594Gi ±  6%    3.734Gi ±  8%       ~ (p=0.105 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         5.303Gi ± 12%    5.515Gi ±  7%       ~ (p=0.165 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           7.666Gi ± 10%    7.662Gi ±  7%       ~ (p=0.529 n=10)
AggregateParallel/clients128_dim4096/workers2-2                           10.91Gi ± 19%    10.68Gi ± 10%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           11.20Gi ± 14%    10.62Gi ± 12%       ~ (p=0.971 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           9.804Gi ±  6%    9.818Gi ± 14%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                        10.79Gi ± 15%    10.69Gi ± 18%       ~ (p=0.631 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           8.505Gi ±  6%    8.397Gi ±  9%       ~ (p=0.165 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           14.46Gi ± 11%    13.12Gi ± 11%       ~ (p=0.105 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           13.35Gi ± 17%    13.30Gi ±  9%       ~ (p=0.684 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           13.30Gi ± 16%    13.78Gi ±  8%       ~ (p=0.190 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        14.21Gi ± 10%    13.91Gi ± 19%       ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           8.856Gi ±  6%    8.948Gi ±  8%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           14.65Gi ± 10%    14.97Gi ± 13%       ~ (p=0.853 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           15.95Gi ± 13%    15.64Gi ± 17%       ~ (p=0.912 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           15.62Gi ± 10%    15.56Gi ± 18%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        15.94Gi ± 15%    15.14Gi ±  9%       ~ (p=0.393 n=10)
geomean                                                                   9.480Gi          9.332Gi        -1.57%

                                                   │ /tmp/tmp.2iLho6HxU6/base_bench.txt │ /tmp/tmp.2iLho6HxU6/current_bench.txt │
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

                                                   │ /tmp/tmp.2iLho6HxU6/base_bench.txt │ /tmp/tmp.2iLho6HxU6/current_bench.txt │
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
