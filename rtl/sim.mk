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

TB_CPP := ../../../../sw/tb/matrix_tb/min_tb_matmul8.cpp

TOP_MODULE := cve2_top

VC_NAME := openhwgroup_cve2_cve2_top_0.1.vc
VC_PATCHED := openhwgroup_cve2_cve2_top_0.1_patched.vc

###############################################################################
# Default
###############################################################################

all: run

###############################################################################
# STEP 1: FuseSoC build (IMPORTANT FIXED TARGET)
###############################################################################
.PHONY: fuse
fuse:
	@echo "Running FuseSoC build..."
	VERILATOR_OPTIONS="-Wno-fatal" \
	PATH="$(PWD)/venv_cve2/bin:$$PATH" \
	fusesoc --cores-root=. run \
		--target=lint \
		--tool=verilator \
		--setup \
		openhwgroup:cve2:cve2_top:0.1 \
		$$(./util/cve2_config.py $(CVE2_CONFIG) fusesoc_opts)

###############################################################################
# STEP 2: Locate VC file dynamically
###############################################################################

VC_FILE := $(shell find build -name $(VC_NAME) | head -n 1)
VC_DIR := $(dir $(VC_FILE))

###############################################################################
# STEP 3: Patch VC file
###############################################################################
.PHONY: gen-vc
gen-vc:
	@if [ -z "$(VC_FILE)" ]; then \
		echo "ERROR: VC file not found. Run 'make fuse' first."; \
		exit 1; \
	fi

	@echo "Patching VC file in $(VC_DIR)"

	cd $(VC_DIR) && \
	cp $(VC_NAME) $(VC_PATCHED) && \
	sed -i \
		'/dpi_memutil.cc/d; \
		 /ecc32_mem_area.cc/d; \
		 /mem_area.cc/d; \
		 /sv_scoped.cc/d; \
		 /scrambled_ecc32_mem_area.cc/d' \
		$(VC_PATCHED)

###############################################################################
# STEP 4: Build simulation
###############################################################################
.PHONY: build-sim
build-sim:
	@if [ -z "$(VC_FILE)" ]; then \
		echo "ERROR: VC file not found. Run 'make fuse' first."; \
		exit 1; \
	fi

	cd $(VC_DIR) && \
	verilator -f $(VC_PATCHED) \
		-Wall \
		-Wno-fatal \
		--cc --exe --build \
		--top-module $(TOP_MODULE) \
		-LDFLAGS "-lelf" \
		$(TB_CPP)

###############################################################################
# STEP 5: Full pipeline
###############################################################################
.PHONY: run
run: fuse gen-vc build-sim
	@echo "=================================================="
	@echo "CVE2 + Matmul8 build complete"
	@echo "Output: $(VC_DIR)/obj_dir/"
	@echo "=================================================="

###############################################################################
# CLEAN
###############################################################################
.PHONY: clean
clean:
	rm -rf build/*/lint-verilator/obj_dir \
	       build/*/lint-verilator/*_patched.vc
