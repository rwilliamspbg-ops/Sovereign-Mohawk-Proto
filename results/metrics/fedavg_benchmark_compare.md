# FedAvg Benchmark Comparison

- Base ref: HEAD~1
- Benchtime: 200ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-13T15:21:49Z

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.j39Htg20YZ/base_bench.txt │ /tmp/tmp.j39Htg20YZ/current_bench.txt │
                                                   │               sec/op               │     sec/op      vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             41.61µ ± 17%     46.32µ ±  6%       ~ (p=0.043 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             50.69µ ± 10%     49.59µ ±  8%       ~ (p=0.218 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             56.30µ ± 12%     55.47µ ±  7%       ~ (p=0.912 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             64.29µ ± 12%     68.14µ ±  8%       ~ (p=0.019 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          42.33µ ± 43%     45.17µ ±  8%       ~ (p=0.353 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            253.7µ ± 16%     257.9µ ±  8%       ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            177.8µ ±  9%     184.1µ ± 17%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            176.3µ ± 21%     165.5µ ± 12%       ~ (p=0.218 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            199.7µ ± 12%     203.9µ ±  7%       ~ (p=0.912 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         182.2µ ± 16%     171.1µ ± 11%       ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            900.5µ ±  6%     908.3µ ±  6%       ~ (p=0.247 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            590.7µ ±  8%     536.4µ ±  9%       ~ (p=0.075 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            572.5µ ± 10%     566.1µ ± 20%       ~ (p=0.853 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            561.5µ ± 13%     547.9µ ± 18%       ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         559.6µ ± 11%     534.1µ ± 33%       ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            1.752m ± 13%     1.834m ±  6%       ~ (p=0.353 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.065m ± 11%     1.069m ± 11%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            975.9µ ± 22%    1001.5µ ± 13%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.049m ± 14%     1.028m ± 15%       ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.015m ±  8%     1.007m ± 10%       ~ (p=0.684 n=10)
geomean                                                                    289.7µ           290.0µ        +0.09%

                                                   │ /tmp/tmp.j39Htg20YZ/base_bench.txt │ /tmp/tmp.j39Htg20YZ/current_bench.txt │
                                                   │                B/s                 │      B/s        vs base               │
AggregateParallel/clients32_dim2048/workers1-2                            5.867Gi ± 15%    5.271Gi ±  6%       ~ (p=0.043 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            4.817Gi ±  9%    4.923Gi ±  7%       ~ (p=0.218 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            4.336Gi ± 14%    4.402Gi ±  7%       ~ (p=0.912 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            3.798Gi ± 14%    3.583Gi ±  7%       ~ (p=0.019 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         5.768Gi ± 30%    5.405Gi ±  7%       ~ (p=0.353 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           7.700Gi ± 14%    7.575Gi ±  7%       ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers2-2                           10.98Gi ± 10%    10.61Gi ± 15%       ~ (p=0.579 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           11.08Gi ± 18%    11.80Gi ± 10%       ~ (p=0.218 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           9.784Gi ± 11%    9.581Gi ±  7%       ~ (p=0.912 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                        10.74Gi ± 19%    11.42Gi ± 10%       ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           8.676Gi ±  5%    8.602Gi ±  6%       ~ (p=0.247 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           13.23Gi ±  9%    14.56Gi ±  8%       ~ (p=0.075 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           13.65Gi ± 11%    13.80Gi ± 16%       ~ (p=0.853 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           13.91Gi ± 11%    14.26Gi ± 16%       ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        13.97Gi ± 11%    14.64Gi ± 25%       ~ (p=0.631 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           8.920Gi ± 12%    8.519Gi ±  6%       ~ (p=0.353 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           14.68Gi ± 10%    14.61Gi ± 12%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           16.01Gi ± 18%    15.60Gi ± 11%       ~ (p=0.796 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           14.90Gi ± 12%    15.20Gi ± 13%       ~ (p=0.739 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        15.40Gi ±  8%    15.51Gi ±  9%       ~ (p=0.684 n=10)
geomean                                                                   9.536Gi          9.527Gi        -0.10%

                                                   │ /tmp/tmp.j39Htg20YZ/base_bench.txt │ /tmp/tmp.j39Htg20YZ/current_bench.txt │
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

                                                   │ /tmp/tmp.j39Htg20YZ/base_bench.txt │ /tmp/tmp.j39Htg20YZ/current_bench.txt │
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
