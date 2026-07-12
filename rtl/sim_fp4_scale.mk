###############################################################################
# CVE2 + Matmul8 Verilator Testbench Flow
#
# Pipeline:
#   fuse      -> run FuseSoC (generates RTL + .vc)
#   gen-vc    -> patch .vc file
#   build-sim -> run Verilator + C++ TB
#   run       -> full pipeline
###############################################################################

SHELL := /bin/bash

###############################################################################
# Configuration
###############################################################################

CVE2_CONFIG ?= small

TB_CPP := ../../../../sw/tb/scale_tb/nvfp8_mul_tb.cpp

TOP_MODULE := e4m3_mul
TARGET_NAME := lint_scale_e4m3_no_fuse_mul_only

CORE_FILE := cve2_fp4_scale.core
CORE_NAME := orca:cve2:fp4_scale:0.1
VC_NAME := orca_cve2_fp4_scale_0.1.vc
VC_PATCHED := orca_cve2_fp4_scale_0.1_patched.vc

###############################################################################
# Default
###############################################################################

all: run

###############################################################################
# STEP 1: Generate FuseSoC file list (.vc)
###############################################################################
.PHONY: fuse 
fuse: $(CORE_FILE) rtl/*.sv
	@echo "Running FuseSoC setup..."
	VERILATOR_OPTIONS="-Wno-fatal" \
	PATH="$(PWD)/venv_cve2/bin:$$PATH" \
	fusesoc --cores-root=. run \
		--target=$(TARGET_NAME) \
		--tool=verilator \
		--setup \
		--no-export \
		$(CORE_NAME) 
	@echo "[fuse] Created FuseSoC Dir [1/5]"

###############################################################################
# STEP 2: Patch VC file
###############################################################################
.PHONY: gen-vc
gen-vc: fuse
	@VC_FILE=$$(find build -name "$(VC_NAME)" | head -n 1); \
	if [ -z "$$VC_FILE" ]; then \
		echo "ERROR: VC file not found. Run 'make fuse' first."; \
		exit 1; \
	fi; \
	VC_DIR=$$(dirname "$$VC_FILE"); \
	echo "Patching VC file in $$VC_DIR"; \
	cd "$$VC_DIR" && \
	cp $(VC_NAME) $(VC_PATCHED) && \
	sed -i \
		-e '/--lint-only/d' \
		-e '/dpi_memutil.cc/d' \
		-e '/ecc32_mem_area.cc/d' \
		-e '/mem_area.cc/d' \
		-e '/sv_scoped.cc/d' \
		-e '/scrambled_ecc32_mem_area.cc/d' \
		$(VC_PATCHED) && \
	echo "[GEN-VC] VC File patched [2/5]" 

###############################################################################
# STEP 3: Build simulation
###############################################################################
.PHONY: build-sim
build-sim: gen-vc
	@VC_FILE=$$(find build -name "$(VC_NAME)" | head -n 1); \
	if [ -z "$$VC_FILE" ]; then \
		echo "ERROR: VC file not found. Run 'make fuse' first."; \
		exit 1; \
	fi; \
	VC_DIR=$$(dirname "$$VC_FILE"); \
	echo "Building simulator in $$VC_DIR"; \
	cd "$$VC_DIR" && \
	verilator -f $(VC_PATCHED) \
		-Wall \
		-Wno-fatal \
		--cc --exe --build \
		--top-module $(TOP_MODULE) \
		-LDFLAGS "-lelf" \
		$(TB_CPP)
	@echo "[gen-vc] Compiled to Verilator [3/5]"

###############################################################################
# STEP 4: Full pipeline
###############################################################################
.PHONY: run
run: fuse gen-vc build-sim
	@echo "=================================================="
	@echo "FP8 E3M8 Build Complete"
	@echo "=================================================="
	@echo "Generated executable:"
	@find build -name V$(TOP_MODULE) 2>/dev/null || true
	@echo "=================================================="

###############################################################################
# CLEAN
###############################################################################
.PHONY: clean
clean:
	rm -rf build/*/$(TARGET_NAME)-verilator