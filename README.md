# TinyRVV

**A Minimal RVV-Lite Extension for CVE2**

TinyRVV explores a small, workload-driven vector extension for the CVE2 RISC-V core. Instead of adding full RVV hardware or SIMD lanes, the design reuses the scalar ALU and multiplier while adding a vector register file, vector control, hardware loop support, and post-increment memory access.

## Project Summary

TinyRVV targets RVV-Lite Layer A.1 with SEW=32, LMUL=1, and VLEN=256. The goal is to improve loop-heavy embedded workloads such as `rgba2luma` while keeping the design small, simple, and safe to integrate into CVE2.

## Authors

**Guy Lemieux**
The University of British Columbia
[Email](mailto:lemieux@ece.ubc.ca)

**Jerry Yun**
The University of British Columbia
[Email](mailto:zizhuoyun@gmail.com)



## Conference

Presented at [HEART 2026](https://heart2026.github.io/).
