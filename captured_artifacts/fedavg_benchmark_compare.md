# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 300ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-10-25T18:26:20Z
- Go toolchain: go version go1.27.3 linux/amd64
- Runtime host: Linux 6.8.0 x86_64 GNU/Linux
- Comparability note: performance values depend on host/runtime/toolchain; compare trends across similarly configured runs.

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: Intel(R) Xeon(R) Processor @ 2.30GHz
                                                   │ /tmp/tmp.a3O8ooCHpD/base_bench.txt │ /tmp/tmp.a3O8ooCHpD/current_bench.txt │
                                                   │               sec/op               │    sec/op      vs base                │
AggregateParallel/clients32_dim2048/workers1-2                             77.84µ ±  2%    81.57µ ±  7%   +4.80% (p=0.002 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             68.65µ ±  2%    71.18µ ±  7%        ~ (p=0.063 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             64.07µ ±  4%    67.22µ ±  2%   +4.92% (p=0.003 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             74.22µ ±  2%    92.42µ ± 42%  +24.53% (p=0.000 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          77.68µ ±  4%   112.53µ ± 30%  +44.85% (p=0.000 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            437.4µ ±  3%    441.1µ ±  4%        ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            282.8µ ±  2%    290.4µ ±  4%        ~ (p=0.123 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            290.8µ ±  2%    298.1µ ±  4%        ~ (p=0.075 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            305.2µ ±  1%    313.0µ ± 20%   +2.55% (p=0.001 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         275.7µ ±  3%    292.8µ ± 32%   +6.17% (p=0.000 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            1.618m ±  2%    1.647m ±  7%        ~ (p=0.011 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            929.0µ ±  3%    946.9µ ±  8%        ~ (p=0.143 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            941.8µ ±  2%    945.3µ ±  6%        ~ (p=0.436 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            966.3µ ±  1%    962.3µ ±  2%        ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         914.9µ ±  2%    913.5µ ±  1%        ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            3.431m ±  6%    3.218m ±  2%   -6.21% (p=0.005 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.762m ±  2%    1.723m ±  2%        ~ (p=0.029 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            1.758m ±  1%    1.854m ±  7%        ~ (p=0.063 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.773m ± 10%    1.890m ±  5%        ~ (p=0.019 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.789m ± 12%    1.761m ±  7%        ~ (p=0.393 n=10)
geomean                                                                    467.8µ          489.8µ         +4.69%

                                                   │ /tmp/tmp.a3O8ooCHpD/base_bench.txt │ /tmp/tmp.a3O8ooCHpD/current_bench.txt │
                                                   │                B/s                 │      B/s       vs base                │
AggregateParallel/clients32_dim2048/workers1-2                            3.137Gi ±  2%   2.993Gi ±  6%   -4.58% (p=0.002 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            3.556Gi ±  2%   3.430Gi ±  8%        ~ (p=0.063 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            3.811Gi ±  4%   3.632Gi ±  2%   -4.69% (p=0.003 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            3.290Gi ±  2%   2.655Gi ± 30%  -19.29% (p=0.000 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         3.143Gi ±  4%   2.178Gi ± 43%  -30.70% (p=0.000 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           4.465Gi ±  3%   4.427Gi ±  4%        ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers2-2                           6.906Gi ±  2%   6.726Gi ±  4%        ~ (p=0.123 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           6.716Gi ±  2%   6.552Gi ±  4%        ~ (p=0.075 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           6.399Gi ±  1%   6.240Gi ± 17%   -2.49% (p=0.001 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                        7.083Gi ±  3%   6.671Gi ± 24%   -5.81% (p=0.000 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           4.830Gi ±  2%   4.745Gi ±  6%        ~ (p=0.011 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           8.409Gi ±  3%   8.251Gi ±  7%        ~ (p=0.143 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           8.295Gi ±  2%   8.265Gi ±  5%        ~ (p=0.436 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           8.085Gi ±  1%   8.119Gi ±  2%        ~ (p=0.579 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        8.539Gi ±  2%   8.552Gi ±  1%        ~ (p=0.315 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           4.554Gi ±  6%   4.855Gi ±  2%   +6.62% (p=0.005 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           8.869Gi ±  2%   9.067Gi ±  2%        ~ (p=0.029 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           8.886Gi ±  1%   8.426Gi ±  7%        ~ (p=0.063 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           8.814Gi ±  9%   8.268Gi ±  5%        ~ (p=0.019 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        8.733Gi ± 11%   8.871Gi ±  6%        ~ (p=0.393 n=10)
geomean                                                                   5.904Gi         5.643Gi         -4.43%

                                                   │ /tmp/tmp.a3O8ooCHpD/base_bench.txt │ /tmp/tmp.a3O8ooCHpD/current_bench.txt │
                                                   │                B/op                │      B/op       vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             8.121Ki ± 0%     8.121Ki ± 0%       ~ (p=0.866 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             8.271Ki ± 0%     8.271Ki ± 0%       ~ (p=0.783 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             8.521Ki ± 0%     8.521Ki ± 0%       ~ (p=0.837 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             9.021Ki ± 0%     9.021Ki ± 0%       ~ (p=0.668 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          8.122Ki ± 0%     8.122Ki ± 0%       ~ (p=0.470 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            16.14Ki ± 0%     16.13Ki ± 0%       ~ (p=0.086 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            16.30Ki ± 0%     16.30Ki ± 0%       ~ (p=0.468 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            16.54Ki ± 0%     16.54Ki ± 0%       ~ (p=0.929 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            17.04Ki ± 0%     17.04Ki ± 0%       ~ (p=0.955 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         16.28Ki ± 0%     16.29Ki ± 0%       ~ (p=0.670 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            32.12Ki ± 0%     32.12Ki ± 0%       ~ (p=0.647 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            32.27Ki ± 0%     32.27Ki ± 0%       ~ (p=0.504 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            32.52Ki ± 0%     32.52Ki ± 0%       ~ (p=0.373 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            33.02Ki ± 0%     33.06Ki ± 0%       ~ (p=0.720 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         32.27Ki ± 0%     32.27Ki ± 0%       ~ (p=0.790 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            32.44Ki ± 0%     32.44Ki ± 1%       ~ (p=0.343 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            32.42Ki ± 0%     32.42Ki ± 0%       ~ (p=0.958 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            32.67Ki ± 0%     32.52Ki ± 0%       ~ (p=0.516 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            33.10Ki ± 0%     33.02Ki ± 1%       ~ (p=0.589 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         32.27Ki ± 0%     32.42Ki ± 0%       ~ (p=0.356 n=10)
geomean                                                                    19.55Ki          19.55Ki       -0.01%

                                                   │ /tmp/tmp.a3O8ooCHpD/base_bench.txt │ /tmp/tmp.a3O8ooCHpD/current_bench.txt │
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
