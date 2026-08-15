
Campaign Log: From Petabytes to Bedrock
The Mistakes We Made (And Corrected)
Mistake 1: The Petabyte Fantasy
Claimed: 1,000,000,000 MB/s

Reality: Dead code elimination removed the read loop

Fix: Added checksum so compiler can't skip work

Mistake 2: The Warm Read Illusion
Claimed: 250 GB/s warm reads

Reality: Touched 25,000 bytes, invoiced for 100MB

Fix: Count actual bytes touched, compute from that

Mistake 3: The WSL2 Bridge Mask
Claimed: C: and D: both at 195 MB/s

Reality: Both going through 9P translation layer

Fix: Test inside VM ext4 (~/) for real speeds

Mistake 4: The mmap Miracle
Claimed: 245,000x faster loading

Reality: mmap defers reads to first touch

Fix: Reframe as "deferred loading" not "faster"

The Honest Numbers That Survived
Zig AVX2 over scalar: 2.73x (fp32), 2.97x (int8)

Recognition cache: 51.6x for known binaries

VM ext4: 565 MB/s, D: bridge: 162 MB/s

Policy routing: 0.108μs/route
