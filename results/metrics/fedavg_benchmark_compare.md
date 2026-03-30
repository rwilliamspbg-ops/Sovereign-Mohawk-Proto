# FedAvg Benchmark Comparison

- Base ref: HEAD~1
- Benchtime: 200ms
- Count: 5
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-03-30T11:40:01Z

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.rfWBKqsOqL/base_bench.txt │ /tmp/tmp.rfWBKqsOqL/current_bench.txt │
                                                   │               sec/op               │     sec/op       vs base              │
AggregateParallel/clients32_dim2048/workers1-2                             55.78µ ± ∞ ¹      53.29µ ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients32_dim2048/workers2-2                             54.66µ ± ∞ ¹      55.76µ ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients32_dim2048/workers4-2                             51.42µ ± ∞ ¹      53.40µ ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients32_dim2048/workers8-2                             65.53µ ± ∞ ¹      60.56µ ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients32_dim2048/workersAuto-2                          54.92µ ± ∞ ¹      52.97µ ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients128_dim4096/workers1-2                            286.1µ ± ∞ ¹      254.3µ ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients128_dim4096/workers2-2                            217.1µ ± ∞ ¹      186.9µ ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients128_dim4096/workers4-2                            178.7µ ± ∞ ¹      195.9µ ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients128_dim4096/workers8-2                            224.5µ ± ∞ ¹      204.5µ ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients128_dim4096/workersAuto-2                         358.0µ ± ∞ ¹      193.6µ ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients256_dim8192/workers1-2                           1133.7µ ± ∞ ¹      916.4µ ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients256_dim8192/workers2-2                            757.0µ ± ∞ ¹      641.2µ ± ∞ ¹       ~ (p=0.056 n=5)
AggregateParallel/clients256_dim8192/workers4-2                            601.9µ ± ∞ ¹      653.3µ ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients256_dim8192/workers8-2                            585.3µ ± ∞ ¹      623.0µ ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients256_dim8192/workersAuto-2                         622.1µ ± ∞ ¹      593.0µ ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workers1-2                            1.732m ± ∞ ¹      1.768m ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers2-2                            1.131m ± ∞ ¹      1.088m ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workers4-2                            1.075m ± ∞ ¹      1.174m ± ∞ ¹       ~ (p=0.548 n=5)
AggregateParallel/clients512_dim8192/workers8-2                            1.078m ± ∞ ¹      1.208m ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.213m ± ∞ ¹      1.053m ± ∞ ¹       ~ (p=0.151 n=5)
geomean                                                                    331.7µ            312.0µ        -5.94%
¹ need >= 6 samples for confidence interval at level 0.95

                                                   │ /tmp/tmp.rfWBKqsOqL/base_bench.txt │ /tmp/tmp.rfWBKqsOqL/current_bench.txt │
                                                   │                B/s                 │       B/s        vs base              │
AggregateParallel/clients32_dim2048/workers1-2                            4.377Gi ± ∞ ¹     4.581Gi ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients32_dim2048/workers2-2                            4.467Gi ± ∞ ¹     4.378Gi ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients32_dim2048/workers4-2                            4.748Gi ± ∞ ¹     4.572Gi ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients32_dim2048/workers8-2                            3.726Gi ± ∞ ¹     4.031Gi ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients32_dim2048/workersAuto-2                         4.446Gi ± ∞ ¹     4.609Gi ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients128_dim4096/workers1-2                           6.828Gi ± ∞ ¹     7.679Gi ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients128_dim4096/workers2-2                           8.998Gi ± ∞ ¹    10.448Gi ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients128_dim4096/workers4-2                          10.927Gi ± ∞ ¹     9.970Gi ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients128_dim4096/workers8-2                           8.702Gi ± ∞ ¹     9.552Gi ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients128_dim4096/workersAuto-2                        5.456Gi ± ∞ ¹    10.090Gi ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients256_dim8192/workers1-2                           6.891Gi ± ∞ ¹     8.526Gi ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients256_dim8192/workers2-2                           10.32Gi ± ∞ ¹     12.18Gi ± ∞ ¹       ~ (p=0.056 n=5)
AggregateParallel/clients256_dim8192/workers4-2                           12.98Gi ± ∞ ¹     11.96Gi ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients256_dim8192/workers8-2                           13.35Gi ± ∞ ¹     12.54Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients256_dim8192/workersAuto-2                        12.56Gi ± ∞ ¹     13.18Gi ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workers1-2                           9.022Gi ± ∞ ¹     8.836Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers2-2                           13.82Gi ± ∞ ¹     14.36Gi ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workers4-2                           14.54Gi ± ∞ ¹     13.31Gi ± ∞ ¹       ~ (p=0.548 n=5)
AggregateParallel/clients512_dim8192/workers8-2                           14.50Gi ± ∞ ¹     12.94Gi ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients512_dim8192/workersAuto-2                        12.88Gi ± ∞ ¹     14.84Gi ± ∞ ¹       ~ (p=0.151 n=5)
geomean                                                                   8.327Gi           8.853Gi        +6.32%
¹ need >= 6 samples for confidence interval at level 0.95

                                                   │ /tmp/tmp.rfWBKqsOqL/base_bench.txt │ /tmp/tmp.rfWBKqsOqL/current_bench.txt │
                                                   │                B/op                │     B/op       vs base                │
AggregateParallel/clients32_dim2048/workers1-2                            16.09Ki ± ∞ ¹   16.09Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workers2-2                            24.22Ki ± ∞ ¹   24.22Ki ± ∞ ¹       ~ (p=1.000 n=5)
AggregateParallel/clients32_dim2048/workers4-2                            40.42Ki ± ∞ ¹   40.42Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workers8-2                            72.83Ki ± ∞ ¹   72.83Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workersAuto-2                         16.09Ki ± ∞ ¹   16.09Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers1-2                           32.09Ki ± ∞ ¹   32.09Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers2-2                           48.22Ki ± ∞ ¹   48.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers4-2                           80.42Ki ± ∞ ¹   80.42Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers8-2                           144.8Ki ± ∞ ¹   144.8Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workersAuto-2                        48.22Ki ± ∞ ¹   48.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers1-2                           64.09Ki ± ∞ ¹   64.09Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers2-2                           96.22Ki ± ∞ ¹   96.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers4-2                           160.4Ki ± ∞ ¹   160.4Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers8-2                           288.8Ki ± ∞ ¹   288.8Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workersAuto-2                        96.22Ki ± ∞ ¹   96.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers1-2                           64.09Ki ± ∞ ¹   64.09Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers2-2                           96.22Ki ± ∞ ¹   96.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers4-2                           160.4Ki ± ∞ ¹   160.4Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers8-2                           288.8Ki ± ∞ ¹   288.8Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workersAuto-2                        96.22Ki ± ∞ ¹   96.22Ki ± ∞ ¹       ~ (p=1.000 n=5) ²
geomean                                                                   71.48Ki         71.48Ki        +0.00%
¹ need >= 6 samples for confidence interval at level 0.95
² all samples are equal

                                                   │ /tmp/tmp.rfWBKqsOqL/base_bench.txt │ /tmp/tmp.rfWBKqsOqL/current_bench.txt │
                                                   │             allocs/op              │   allocs/op    vs base                │
AggregateParallel/clients32_dim2048/workers1-2                              5.000 ± ∞ ¹     5.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workers2-2                              9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workers4-2                              15.00 ± ∞ ¹     15.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workers8-2                              27.00 ± ∞ ¹     27.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients32_dim2048/workersAuto-2                           5.000 ± ∞ ¹     5.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers1-2                             5.000 ± ∞ ¹     5.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers2-2                             9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers4-2                             15.00 ± ∞ ¹     15.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workers8-2                             27.00 ± ∞ ¹     27.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients128_dim4096/workersAuto-2                          9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers1-2                             5.000 ± ∞ ¹     5.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers2-2                             9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers4-2                             15.00 ± ∞ ¹     15.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workers8-2                             27.00 ± ∞ ¹     27.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients256_dim8192/workersAuto-2                          9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers1-2                             5.000 ± ∞ ¹     5.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers2-2                             9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers4-2                             15.00 ± ∞ ¹     15.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workers8-2                             27.00 ± ∞ ¹     27.00 ± ∞ ¹       ~ (p=1.000 n=5) ²
AggregateParallel/clients512_dim8192/workersAuto-2                          9.000 ± ∞ ¹     9.000 ± ∞ ¹       ~ (p=1.000 n=5) ²
geomean                                                                     10.72           10.72        +0.00%
¹ need >= 6 samples for confidence interval at level 0.95
² all samples are equal
```
