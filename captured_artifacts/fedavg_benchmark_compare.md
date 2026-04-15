# FedAvg Benchmark Comparison

- Base ref: origin/main
- Benchtime: 300ms
- Count: 5
- Tool: benchstat (alpha=0.01)
- Generated at: 2026-04-15T23:29:02Z
- Go toolchain: go version go1.25.9 linux/amd64
- Runtime host: Linux 6.8.0-1044-azure x86_64 GNU/Linux
- Comparability note: performance values depend on host/runtime/toolchain; compare trends across similarly configured runs.

```text
goos: linux
goarch: amd64
pkg: github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test
cpu: AMD EPYC 7763 64-Core Processor                
                                                   │ /tmp/tmp.EIgJvbdQZ0/base_bench.txt │ /tmp/tmp.EIgJvbdQZ0/current_bench.txt │
                                                   │               sec/op               │     sec/op       vs base              │
AggregateParallel/clients32_dim2048/workers1-2                             55.20µ ± ∞ ¹      49.07µ ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients32_dim2048/workers2-2                             50.98µ ± ∞ ¹      55.40µ ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients32_dim2048/workers4-2                             59.41µ ± ∞ ¹      54.03µ ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients32_dim2048/workers8-2                             64.50µ ± ∞ ¹      62.64µ ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients32_dim2048/workersAuto-2                          44.96µ ± ∞ ¹      48.25µ ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients128_dim4096/workers1-2                            258.9µ ± ∞ ¹      263.9µ ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients128_dim4096/workers2-2                            203.9µ ± ∞ ¹      167.7µ ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients128_dim4096/workers4-2                            203.1µ ± ∞ ¹      184.1µ ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients128_dim4096/workers8-2                            207.4µ ± ∞ ¹      192.4µ ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients128_dim4096/workersAuto-2                         195.5µ ± ∞ ¹      171.2µ ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients256_dim8192/workers1-2                            896.3µ ± ∞ ¹      952.2µ ± ∞ ¹       ~ (p=0.056 n=5)
AggregateParallel/clients256_dim8192/workers2-2                            612.9µ ± ∞ ¹      612.3µ ± ∞ ¹       ~ (p=1.000 n=5)
AggregateParallel/clients256_dim8192/workers4-2                            581.7µ ± ∞ ¹      620.2µ ± ∞ ¹       ~ (p=0.548 n=5)
AggregateParallel/clients256_dim8192/workers8-2                            770.7µ ± ∞ ¹      604.0µ ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients256_dim8192/workersAuto-2                         609.3µ ± ∞ ¹      646.9µ ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers1-2                            1.772m ± ∞ ¹      1.815m ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers2-2                            1.176m ± ∞ ¹      1.097m ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients512_dim8192/workers4-2                            1.049m ± ∞ ¹      1.102m ± ∞ ¹       ~ (p=1.000 n=5)
AggregateParallel/clients512_dim8192/workers8-2                            1.033m ± ∞ ¹      1.177m ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients512_dim8192/workersAuto-2                         1.070m ± ∞ ¹      1.062m ± ∞ ¹       ~ (p=0.310 n=5)
geomean                                                                    312.0µ            304.2µ        -2.49%
¹ need >= 6 samples for confidence interval at level 0.95

                                                   │ /tmp/tmp.EIgJvbdQZ0/base_bench.txt │ /tmp/tmp.EIgJvbdQZ0/current_bench.txt │
                                                   │                B/s                 │       B/s        vs base              │
AggregateParallel/clients32_dim2048/workers1-2                            4.423Gi ± ∞ ¹     4.976Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients32_dim2048/workers2-2                            4.789Gi ± ∞ ¹     4.407Gi ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients32_dim2048/workers4-2                            4.109Gi ± ∞ ¹     4.519Gi ± ∞ ¹       ~ (p=0.310 n=5)
AggregateParallel/clients32_dim2048/workers8-2                            3.785Gi ± ∞ ¹     3.898Gi ± ∞ ¹       ~ (p=0.841 n=5)
AggregateParallel/clients32_dim2048/workersAuto-2                         5.430Gi ± ∞ ¹     5.060Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients128_dim4096/workers1-2                           7.545Gi ± ∞ ¹     7.402Gi ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients128_dim4096/workers2-2                           9.578Gi ± ∞ ¹    11.649Gi ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients128_dim4096/workers4-2                           9.616Gi ± ∞ ¹    10.609Gi ± ∞ ¹       ~ (p=0.095 n=5)
AggregateParallel/clients128_dim4096/workers8-2                           9.418Gi ± ∞ ¹    10.150Gi ± ∞ ¹       ~ (p=0.421 n=5)
AggregateParallel/clients128_dim4096/workersAuto-2                        9.990Gi ± ∞ ¹    11.410Gi ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients256_dim8192/workers1-2                           8.717Gi ± ∞ ¹     8.204Gi ± ∞ ¹       ~ (p=0.056 n=5)
AggregateParallel/clients256_dim8192/workers2-2                           12.75Gi ± ∞ ¹     12.76Gi ± ∞ ¹       ~ (p=1.000 n=5)
AggregateParallel/clients256_dim8192/workers4-2                           13.43Gi ± ∞ ¹     12.60Gi ± ∞ ¹       ~ (p=0.548 n=5)
AggregateParallel/clients256_dim8192/workers8-2                           10.14Gi ± ∞ ¹     12.93Gi ± ∞ ¹       ~ (p=0.016 n=5)
AggregateParallel/clients256_dim8192/workersAuto-2                        12.82Gi ± ∞ ¹     12.08Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers1-2                           8.817Gi ± ∞ ¹     8.609Gi ± ∞ ¹       ~ (p=0.690 n=5)
AggregateParallel/clients512_dim8192/workers2-2                           13.29Gi ± ∞ ¹     14.25Gi ± ∞ ¹       ~ (p=0.222 n=5)
AggregateParallel/clients512_dim8192/workers4-2                           14.90Gi ± ∞ ¹     14.18Gi ± ∞ ¹       ~ (p=1.000 n=5)
AggregateParallel/clients512_dim8192/workers8-2                           15.13Gi ± ∞ ¹     13.27Gi ± ∞ ¹       ~ (p=0.151 n=5)
AggregateParallel/clients512_dim8192/workersAuto-2                        14.60Gi ± ∞ ¹     14.72Gi ± ∞ ¹       ~ (p=0.310 n=5)
geomean                                                                   8.853Gi           9.079Gi        +2.56%
¹ need >= 6 samples for confidence interval at level 0.95

                                                   │ /tmp/tmp.EIgJvbdQZ0/base_bench.txt │ /tmp/tmp.EIgJvbdQZ0/current_bench.txt │
                                                   │                B/op                │      B/op       vs base               │
AggregateParallel/clients32_dim2048/workers1-2                           16.094Ki ± ∞ ¹    8.118Ki ± ∞ ¹  -49.56% (p=0.008 n=5)
AggregateParallel/clients32_dim2048/workers2-2                           24.219Ki ± ∞ ¹    8.271Ki ± ∞ ¹  -65.85% (p=0.008 n=5)
AggregateParallel/clients32_dim2048/workers4-2                           40.422Ki ± ∞ ¹    8.521Ki ± ∞ ¹  -78.92% (p=0.008 n=5)
AggregateParallel/clients32_dim2048/workers8-2                           72.828Ki ± ∞ ¹    9.023Ki ± ∞ ¹  -87.61% (p=0.008 n=5)
AggregateParallel/clients32_dim2048/workersAuto-2                        16.094Ki ± ∞ ¹    8.120Ki ± ∞ ¹  -49.54% (p=0.008 n=5)
AggregateParallel/clients128_dim4096/workers1-2                           32.09Ki ± ∞ ¹    16.12Ki ± ∞ ¹  -49.78% (p=0.008 n=5)
AggregateParallel/clients128_dim4096/workers2-2                           48.22Ki ± ∞ ¹    16.29Ki ± ∞ ¹  -66.23% (p=0.008 n=5)
AggregateParallel/clients128_dim4096/workers4-2                           80.42Ki ± ∞ ¹    16.54Ki ± ∞ ¹  -79.43% (p=0.008 n=5)
AggregateParallel/clients128_dim4096/workers8-2                          144.83Ki ± ∞ ¹    17.04Ki ± ∞ ¹  -88.23% (p=0.008 n=5)
AggregateParallel/clients128_dim4096/workersAuto-2                        48.22Ki ± ∞ ¹    16.29Ki ± ∞ ¹  -66.22% (p=0.008 n=5)
AggregateParallel/clients256_dim8192/workers1-2                           64.09Ki ± ∞ ¹    32.20Ki ± ∞ ¹  -49.76% (p=0.008 n=5)
AggregateParallel/clients256_dim8192/workers2-2                           96.22Ki ± ∞ ¹    32.33Ki ± ∞ ¹  -66.40% (p=0.008 n=5)
AggregateParallel/clients256_dim8192/workers4-2                          160.42Ki ± ∞ ¹    32.57Ki ± ∞ ¹  -79.70% (p=0.008 n=5)
AggregateParallel/clients256_dim8192/workers8-2                          288.83Ki ± ∞ ¹    33.02Ki ± ∞ ¹  -88.57% (p=0.008 n=5)
AggregateParallel/clients256_dim8192/workersAuto-2                        96.22Ki ± ∞ ¹    32.32Ki ± ∞ ¹  -66.41% (p=0.008 n=5)
AggregateParallel/clients512_dim8192/workers1-2                           64.09Ki ± ∞ ¹    32.28Ki ± ∞ ¹  -49.64% (p=0.008 n=5)
AggregateParallel/clients512_dim8192/workers2-2                           96.22Ki ± ∞ ¹    32.27Ki ± ∞ ¹  -66.47% (p=0.008 n=5)
AggregateParallel/clients512_dim8192/workers4-2                          160.42Ki ± ∞ ¹    32.52Ki ± ∞ ¹  -79.73% (p=0.008 n=5)
AggregateParallel/clients512_dim8192/workers8-2                          288.83Ki ± ∞ ¹    33.12Ki ± ∞ ¹  -88.53% (p=0.008 n=5)
AggregateParallel/clients512_dim8192/workersAuto-2                        96.22Ki ± ∞ ¹    32.27Ki ± ∞ ¹  -66.46% (p=0.008 n=5)
geomean                                                                   71.48Ki          19.54Ki        -72.66%
¹ need >= 6 samples for confidence interval at level 0.95

                                                   │ /tmp/tmp.EIgJvbdQZ0/base_bench.txt │ /tmp/tmp.EIgJvbdQZ0/current_bench.txt │
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
