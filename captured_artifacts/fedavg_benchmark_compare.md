# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 200ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-01T00:28:58Z

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.1k0yl7KkvM/base_bench.txt │ /tmp/tmp.1k0yl7KkvM/current_bench.txt │
                                                   │               sec/op               │     sec/op      vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             51.50µ ±  9%     49.61µ ±  9%       ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             55.61µ ±  8%     53.01µ ±  9%       ~ (p=0.353 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             57.12µ ± 12%     53.43µ ±  6%       ~ (p=0.029 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             62.95µ ±  9%     65.20µ ±  8%       ~ (p=0.739 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          49.32µ ± 13%     46.09µ ±  4%       ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            260.5µ ± 10%     260.1µ ±  5%       ~ (p=0.684 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            179.7µ ± 10%     197.0µ ± 10%       ~ (p=0.089 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            178.1µ ± 31%     186.5µ ± 11%       ~ (p=0.912 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            211.7µ ± 15%     217.8µ ± 14%       ~ (p=0.315 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         183.1µ ± 14%     195.4µ ± 17%       ~ (p=0.393 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            908.6µ ± 19%     910.1µ ± 12%       ~ (p=0.684 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            680.9µ ± 18%     569.1µ ± 29%       ~ (p=0.123 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            575.5µ ± 33%     594.7µ ± 26%       ~ (p=0.529 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            623.2µ ± 11%     580.4µ ± 14%       ~ (p=0.280 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         612.4µ ±  8%     597.0µ ±  6%       ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            1.906m ± 13%     1.768m ± 26%       ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.028m ± 19%     1.135m ± 23%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            1.074m ± 15%     1.037m ± 20%       ~ (p=1.000 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.119m ± 15%     1.035m ± 19%       ~ (p=0.393 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.157m ± 39%     1.003m ± 28%       ~ (p=0.280 n=10)
geomean                                                                    308.4µ           301.9µ        -2.12%

                                                   │ /tmp/tmp.1k0yl7KkvM/base_bench.txt │ /tmp/tmp.1k0yl7KkvM/current_bench.txt │
                                                   │                B/s                 │      B/s        vs base               │
AggregateParallel/clients32_dim2048/workers1-2                            4.741Gi ±  9%    4.921Gi ± 10%       ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            4.390Gi ±  9%    4.608Gi ±  8%       ~ (p=0.353 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            4.276Gi ± 11%    4.570Gi ±  7%       ~ (p=0.029 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            3.879Gi ±  9%    3.745Gi ±  8%       ~ (p=0.739 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         4.950Gi ± 15%    5.297Gi ±  4%       ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           7.499Gi ±  9%    7.509Gi ±  5%       ~ (p=0.684 n=10)
AggregateParallel/clients128_dim4096/workers2-2                          10.867Gi ± 12%    9.916Gi ± 11%       ~ (p=0.089 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           10.96Gi ± 24%    10.49Gi ± 10%       ~ (p=0.912 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           9.227Gi ± 13%    8.967Gi ± 12%       ~ (p=0.315 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                       10.670Gi ± 16%    9.999Gi ± 20%       ~ (p=0.393 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           8.598Gi ± 16%    8.584Gi ± 11%       ~ (p=0.684 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           11.48Gi ± 22%    13.74Gi ± 23%       ~ (p=0.123 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           13.59Gi ± 25%    13.14Gi ± 21%       ~ (p=0.529 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           12.54Gi ± 12%    13.48Gi ± 12%       ~ (p=0.280 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        12.76Gi ±  9%    13.09Gi ±  6%       ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           8.212Gi ± 11%    8.839Gi ± 21%       ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           15.21Gi ± 16%    13.78Gi ± 19%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           14.55Gi ± 13%    15.06Gi ± 17%       ~ (p=1.000 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           13.97Gi ± 15%    15.11Gi ± 16%       ~ (p=0.393 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        13.53Gi ± 28%    15.58Gi ± 22%       ~ (p=0.280 n=10)
geomean                                                                   8.958Gi          9.152Gi        +2.17%

                                                   │ /tmp/tmp.1k0yl7KkvM/base_bench.txt │ /tmp/tmp.1k0yl7KkvM/current_bench.txt │
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

                                                   │ /tmp/tmp.1k0yl7KkvM/base_bench.txt │ /tmp/tmp.1k0yl7KkvM/current_bench.txt │
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
