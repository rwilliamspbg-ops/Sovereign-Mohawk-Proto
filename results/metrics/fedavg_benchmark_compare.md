# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 200ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-03-30T11:08:14Z

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.NVFhxYgLZy/base_bench.txt │ /tmp/tmp.NVFhxYgLZy/current_bench.txt │
                                                   │               sec/op               │    sec/op      vs base                │
AggregateParallel/clients32_dim2048/workers1-4                             55.33µ ± 28%    52.75µ ±  6%        ~ (p=0.143 n=10)
AggregateParallel/clients32_dim2048/workers2-4                             64.75µ ±  2%    64.07µ ±  1%        ~ (p=0.165 n=10)
AggregateParallel/clients32_dim2048/workers4-4                             60.96µ ±  5%    58.88µ ±  7%        ~ (p=0.579 n=10)
AggregateParallel/clients32_dim2048/workers8-4                             69.95µ ± 13%    74.24µ ±  6%        ~ (p=0.123 n=10)
AggregateParallel/clients32_dim2048/workersAuto-4                          52.16µ ±  5%    50.51µ ±  5%        ~ (p=0.353 n=10)
AggregateParallel/clients128_dim4096/workers1-4                            263.3µ ±  8%    256.1µ ±  3%        ~ (p=0.123 n=10)
AggregateParallel/clients128_dim4096/workers2-4                            211.1µ ±  6%    209.9µ ± 10%        ~ (p=0.631 n=10)
AggregateParallel/clients128_dim4096/workers4-4                            215.1µ ± 22%    208.9µ ± 13%        ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers8-4                            223.1µ ±  9%    230.5µ ± 13%        ~ (p=0.165 n=10)
AggregateParallel/clients128_dim4096/workersAuto-4                         211.8µ ± 20%    229.7µ ± 31%        ~ (p=0.165 n=10)
AggregateParallel/clients256_dim8192/workers1-4                            937.9µ ±  5%    918.6µ ±  3%        ~ (p=0.393 n=10)
AggregateParallel/clients256_dim8192/workers2-4                            638.2µ ±  7%    700.8µ ± 13%        ~ (p=0.089 n=10)
AggregateParallel/clients256_dim8192/workers4-4                            583.8µ ± 20%    590.4µ ±  8%        ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workers8-4                            618.0µ ± 18%    599.1µ ± 14%        ~ (p=0.353 n=10)
AggregateParallel/clients256_dim8192/workersAuto-4                         599.7µ ±  6%    605.0µ ±  7%        ~ (p=0.481 n=10)
AggregateParallel/clients512_dim8192/workers1-4                            1.786m ± 14%    1.836m ±  8%        ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-4                            1.253m ±  9%    1.122m ±  9%  -10.39% (p=0.009 n=10)
AggregateParallel/clients512_dim8192/workers4-4                            1.042m ± 10%    1.098m ± 12%        ~ (p=0.089 n=10)
AggregateParallel/clients512_dim8192/workers8-4                            1.101m ±  7%    1.058m ±  8%        ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workersAuto-4                         1.060m ± 17%    1.068m ± 13%        ~ (p=0.796 n=10)
geomean                                                                    323.6µ          323.3µ         -0.08%

                                                   │ /tmp/tmp.NVFhxYgLZy/base_bench.txt │ /tmp/tmp.NVFhxYgLZy/current_bench.txt │
                                                   │                B/s                 │      B/s       vs base                │
AggregateParallel/clients32_dim2048/workers1-4                            4.418Gi ± 22%   4.630Gi ±  7%        ~ (p=0.143 n=10)
AggregateParallel/clients32_dim2048/workers2-4                            3.770Gi ±  2%   3.811Gi ±  1%        ~ (p=0.165 n=10)
AggregateParallel/clients32_dim2048/workers4-4                            4.005Gi ±  5%   4.146Gi ±  7%        ~ (p=0.579 n=10)
AggregateParallel/clients32_dim2048/workers8-4                            3.491Gi ± 12%   3.289Gi ±  6%        ~ (p=0.123 n=10)
AggregateParallel/clients32_dim2048/workersAuto-4                         4.681Gi ±  5%   4.835Gi ±  6%        ~ (p=0.353 n=10)
AggregateParallel/clients128_dim4096/workers1-4                           7.419Gi ±  8%   7.626Gi ±  3%        ~ (p=0.123 n=10)
AggregateParallel/clients128_dim4096/workers2-4                           9.251Gi ±  7%   9.304Gi ±  9%        ~ (p=0.631 n=10)
AggregateParallel/clients128_dim4096/workers4-4                           9.085Gi ± 18%   9.351Gi ± 12%        ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers8-4                           8.756Gi ±  8%   8.474Gi ± 11%        ~ (p=0.165 n=10)
AggregateParallel/clients128_dim4096/workersAuto-4                        9.232Gi ± 17%   8.508Gi ± 24%        ~ (p=0.165 n=10)
AggregateParallel/clients256_dim8192/workers1-4                           8.331Gi ±  5%   8.505Gi ±  3%        ~ (p=0.393 n=10)
AggregateParallel/clients256_dim8192/workers2-4                           12.24Gi ±  7%   11.16Gi ± 15%        ~ (p=0.089 n=10)
AggregateParallel/clients256_dim8192/workers4-4                           13.38Gi ± 17%   13.23Gi ±  8%        ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workers8-4                           12.64Gi ± 15%   13.04Gi ± 12%        ~ (p=0.353 n=10)
AggregateParallel/clients256_dim8192/workersAuto-4                        13.03Gi ±  7%   12.91Gi ±  6%        ~ (p=0.481 n=10)
AggregateParallel/clients512_dim8192/workers1-4                           8.749Gi ± 12%   8.513Gi ±  7%        ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-4                           12.47Gi ±  8%   13.92Gi ±  9%  +11.60% (p=0.009 n=10)
AggregateParallel/clients512_dim8192/workers4-4                           14.99Gi ±  9%   14.24Gi ± 11%        ~ (p=0.089 n=10)
AggregateParallel/clients512_dim8192/workers8-4                           14.19Gi ±  7%   14.78Gi ±  8%        ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workersAuto-4                        14.74Gi ± 15%   14.64Gi ± 12%        ~ (p=0.796 n=10)
geomean                                                                   8.537Gi         8.544Gi         +0.08%

                                                   │ /tmp/tmp.NVFhxYgLZy/base_bench.txt │ /tmp/tmp.NVFhxYgLZy/current_bench.txt │
                                                   │                B/op                │     B/op      vs base                 │
AggregateParallel/clients32_dim2048/workers1-4                             16.09Ki ± 0%   16.09Ki ± 0%       ~ (p=0.737 n=10)
AggregateParallel/clients32_dim2048/workers2-4                             24.22Ki ± 0%   24.22Ki ± 0%       ~ (p=0.536 n=10)
AggregateParallel/clients32_dim2048/workers4-4                             40.42Ki ± 0%   40.42Ki ± 0%       ~ (p=1.000 n=10)
AggregateParallel/clients32_dim2048/workers8-4                             72.83Ki ± 0%   72.83Ki ± 0%       ~ (p=0.628 n=10)
AggregateParallel/clients32_dim2048/workersAuto-4                          16.09Ki ± 0%   16.09Ki ± 0%       ~ (p=1.000 n=10)
AggregateParallel/clients128_dim4096/workers1-4                            32.09Ki ± 0%   32.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers2-4                            48.22Ki ± 0%   48.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers4-4                            80.42Ki ± 0%   80.42Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers8-4                            144.8Ki ± 0%   144.8Ki ± 0%       ~ (p=1.000 n=10)
AggregateParallel/clients128_dim4096/workersAuto-4                         80.42Ki ± 0%   80.42Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers1-4                            64.09Ki ± 0%   64.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers2-4                            96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers4-4                            160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers8-4                            288.8Ki ± 0%   288.8Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workersAuto-4                         160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10)
AggregateParallel/clients512_dim8192/workers1-4                            64.09Ki ± 0%   64.09Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers2-4                            96.22Ki ± 0%   96.22Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers4-4                            160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers8-4                            288.8Ki ± 0%   288.8Ki ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workersAuto-4                         160.4Ki ± 0%   160.4Ki ± 0%       ~ (p=1.000 n=10) ¹
geomean                                                                    77.18Ki        77.18Ki       +0.00%
¹ all samples are equal

                                                   │ /tmp/tmp.NVFhxYgLZy/base_bench.txt │ /tmp/tmp.NVFhxYgLZy/current_bench.txt │
                                                   │             allocs/op              │  allocs/op    vs base                 │
AggregateParallel/clients32_dim2048/workers1-4                               5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers2-4                               9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers4-4                               15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workers8-4                               27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients32_dim2048/workersAuto-4                            5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers1-4                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers2-4                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers4-4                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workers8-4                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients128_dim4096/workersAuto-4                           15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers1-4                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers2-4                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers4-4                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workers8-4                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients256_dim8192/workersAuto-4                           15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers1-4                              5.000 ± 0%     5.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers2-4                              9.000 ± 0%     9.000 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers4-4                              15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workers8-4                              27.00 ± 0%     27.00 ± 0%       ~ (p=1.000 n=10) ¹
AggregateParallel/clients512_dim8192/workersAuto-4                           15.00 ± 0%     15.00 ± 0%       ~ (p=1.000 n=10) ¹
geomean                                                                      11.57          11.57       +0.00%
¹ all samples are equal
```
