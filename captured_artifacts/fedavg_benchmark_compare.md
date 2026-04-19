# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 300ms
- Count: 10
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-16T22:39:54Z
- Go toolchain: go version go1.26.1 linux/amd64
- Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
- Comparability note: performance values depend on host/runtime/toolchain; compare trends across similarly configured runs.

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.CwRotVkHN2/base_bench.txt │ /tmp/tmp.CwRotVkHN2/current_bench.txt │
                                                   │               sec/op               │     sec/op      vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             49.03µ ± 13%     50.83µ ±  7%       ~ (p=0.529 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             56.74µ ±  3%     57.19µ ±  4%       ~ (p=0.853 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             53.49µ ± 18%     51.66µ ± 22%       ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             60.65µ ± 20%     61.85µ ±  9%       ~ (p=0.796 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          50.36µ ± 10%     50.14µ ±  5%       ~ (p=0.529 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            252.1µ ± 16%     255.3µ ± 10%       ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            168.9µ ± 14%     176.9µ ± 20%       ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            171.3µ ± 21%     185.5µ ± 14%       ~ (p=0.971 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            190.1µ ± 13%     188.8µ ±  8%       ~ (p=0.684 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         178.7µ ± 11%     199.0µ ± 28%       ~ (p=0.023 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            979.1µ ±  7%     927.4µ ±  3%       ~ (p=0.105 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            590.8µ ±  8%     609.9µ ± 16%       ~ (p=0.912 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            565.5µ ± 17%     578.1µ ±  7%       ~ (p=0.912 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            625.9µ ± 23%     608.3µ ± 15%       ~ (p=0.247 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         623.9µ ± 20%     560.8µ ± 18%       ~ (p=0.247 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            1.839m ±  5%     1.823m ±  7%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            1.125m ± 42%     1.084m ± 11%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            1.152m ± 15%     1.074m ± 17%       ~ (p=0.481 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            1.072m ±  8%     1.037m ± 17%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.076m ±  8%     1.015m ± 21%       ~ (p=0.280 n=10)
geomean                                                                    301.9µ           300.7µ        -0.41%

                                                   │ /tmp/tmp.CwRotVkHN2/base_bench.txt │ /tmp/tmp.CwRotVkHN2/current_bench.txt │
                                                   │                B/s                 │      B/s        vs base               │
AggregateParallel/clients32_dim2048/workers1-2                            4.979Gi ± 12%    4.807Gi ±  7%       ~ (p=0.529 n=10)
AggregateParallel/clients32_dim2048/workers2-2                            4.303Gi ±  3%    4.269Gi ±  4%       ~ (p=0.853 n=10)
AggregateParallel/clients32_dim2048/workers4-2                            4.583Gi ± 16%    4.727Gi ± 18%       ~ (p=0.631 n=10)
AggregateParallel/clients32_dim2048/workers8-2                            4.026Gi ± 16%    3.947Gi ± 10%       ~ (p=0.796 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                         4.848Gi ±  9%    4.869Gi ±  6%       ~ (p=0.529 n=10)
AggregateParallel/clients128_dim4096/workers1-2                           7.748Gi ± 14%    7.650Gi ±  9%       ~ (p=0.393 n=10)
AggregateParallel/clients128_dim4096/workers2-2                           11.57Gi ± 12%    11.04Gi ± 16%       ~ (p=0.280 n=10)
AggregateParallel/clients128_dim4096/workers4-2                           11.40Gi ± 17%    10.54Gi ± 16%       ~ (p=0.971 n=10)
AggregateParallel/clients128_dim4096/workers8-2                           10.28Gi ± 11%    10.35Gi ±  7%       ~ (p=0.684 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                       10.932Gi ± 12%    9.822Gi ± 22%       ~ (p=0.023 n=10)
AggregateParallel/clients256_dim8192/workers1-2                           7.981Gi ±  8%    8.424Gi ±  3%       ~ (p=0.105 n=10)
AggregateParallel/clients256_dim8192/workers2-2                           13.23Gi ±  7%    12.81Gi ± 20%       ~ (p=0.912 n=10)
AggregateParallel/clients256_dim8192/workers4-2                           13.82Gi ± 15%    13.52Gi ±  8%       ~ (p=0.912 n=10)
AggregateParallel/clients256_dim8192/workers8-2                           12.48Gi ± 19%    12.85Gi ± 17%       ~ (p=0.247 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                        12.53Gi ± 17%    13.93Gi ± 15%       ~ (p=0.247 n=10)
AggregateParallel/clients512_dim8192/workers1-2                           8.495Gi ±  5%    8.577Gi ±  7%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers2-2                           13.90Gi ± 30%    14.42Gi ± 10%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workers4-2                           13.57Gi ± 18%    14.57Gi ± 15%       ~ (p=0.481 n=10)
AggregateParallel/clients512_dim8192/workers8-2                           14.57Gi ±  9%    15.08Gi ± 15%       ~ (p=0.529 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                        14.52Gi ±  8%    15.41Gi ± 17%       ~ (p=0.280 n=10)
geomean                                                                   9.153Gi          9.190Gi        +0.40%

                                                   │ /tmp/tmp.CwRotVkHN2/base_bench.txt │ /tmp/tmp.CwRotVkHN2/current_bench.txt │
                                                   │                B/op                │      B/op       vs base               │
AggregateParallel/clients32_dim2048/workers1-2                             8.118Ki ± 0%     8.118Ki ± 0%       ~ (p=0.723 n=10)
AggregateParallel/clients32_dim2048/workers2-2                             8.271Ki ± 0%     8.272Ki ± 0%       ~ (p=0.850 n=10)
AggregateParallel/clients32_dim2048/workers4-2                             8.521Ki ± 0%     8.521Ki ± 0%       ~ (p=0.403 n=10)
AggregateParallel/clients32_dim2048/workers8-2                             9.022Ki ± 0%     9.022Ki ± 0%       ~ (p=0.665 n=10)
AggregateParallel/clients32_dim2048/workersAuto-2                          8.120Ki ± 0%     8.119Ki ± 0%       ~ (p=0.806 n=10)
AggregateParallel/clients128_dim4096/workers1-2                            16.13Ki ± 0%     16.13Ki ± 0%       ~ (p=0.637 n=10)
AggregateParallel/clients128_dim4096/workers2-2                            16.29Ki ± 0%     16.29Ki ± 0%       ~ (p=0.118 n=10)
AggregateParallel/clients128_dim4096/workers4-2                            16.53Ki ± 0%     16.54Ki ± 0%       ~ (p=0.037 n=10)
AggregateParallel/clients128_dim4096/workers8-2                            17.04Ki ± 0%     17.04Ki ± 0%       ~ (p=0.899 n=10)
AggregateParallel/clients128_dim4096/workersAuto-2                         16.29Ki ± 0%     16.29Ki ± 0%       ~ (p=0.781 n=10)
AggregateParallel/clients256_dim8192/workers1-2                            32.20Ki ± 0%     32.16Ki ± 0%       ~ (p=0.344 n=10)
AggregateParallel/clients256_dim8192/workers2-2                            32.27Ki ± 0%     32.29Ki ± 0%       ~ (p=0.371 n=10)
AggregateParallel/clients256_dim8192/workers4-2                            32.54Ki ± 0%     32.56Ki ± 0%       ~ (p=0.718 n=10)
AggregateParallel/clients256_dim8192/workers8-2                            33.07Ki ± 0%     33.04Ki ± 0%       ~ (p=0.535 n=10)
AggregateParallel/clients256_dim8192/workersAuto-2                         32.32Ki ± 0%     32.27Ki ± 0%       ~ (p=0.030 n=10)
AggregateParallel/clients512_dim8192/workers1-2                            32.28Ki ± 1%     32.27Ki ± 0%       ~ (p=0.775 n=10)
AggregateParallel/clients512_dim8192/workers2-2                            32.35Ki ± 0%     32.27Ki ± 0%       ~ (p=0.338 n=10)
AggregateParallel/clients512_dim8192/workers4-2                            32.61Ki ± 0%     32.52Ki ± 0%       ~ (p=0.153 n=10)
AggregateParallel/clients512_dim8192/workers8-2                            33.10Ki ± 0%     33.10Ki ± 0%       ~ (p=0.677 n=10)
AggregateParallel/clients512_dim8192/workersAuto-2                         32.36Ki ± 0%     32.27Ki ± 0%       ~ (p=0.057 n=10)
geomean                                                                    19.55Ki          19.54Ki       -0.05%

                                                   │ /tmp/tmp.CwRotVkHN2/base_bench.txt │ /tmp/tmp.CwRotVkHN2/current_bench.txt │
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
