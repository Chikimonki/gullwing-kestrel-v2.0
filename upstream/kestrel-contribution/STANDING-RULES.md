
Standing Rules for Honest Benchmarking
Every speed computed from actual bytes touched

Assert printed_speed == bytes_touched / elapsed within 1%

Drop caches before cold measurements

Use fresh files >1GB to defeat host cache

Median of 5 runs, watch for thermal throttling

Print checksums so compiler can't skip work

Known-answer test before any speed claim

No multiplier ships without its measurement context

mmap loading is "deferred to first touch" not "faster"

A well-controlled failure beats an unexplained fast number
