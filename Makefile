#===============================================================
# Direct-Mapped Cache Controller - Build and Verification
#
#   make            show this help
#   make regress    compile and run the full test suite
#   make perf       run the performance / AMAT benchmark
#   make analyze    regenerate the performance graphs
#   make synth      run Yosys generic synthesis
#   make all        regress + perf + analyze + synth
#   make waves TB=cache_rw    open a waveform in GTKWave
#   make clean      remove generated artefacts
#===============================================================

SHELL    := /bin/bash

IVERILOG := iverilog
VVP      := vvp
YOSYS    := yosys
PYTHON   := python3

IVFLAGS  := -g2012 -Wall

RTL_DIR  := rtl
TB_DIR   := testbench
RES_DIR  := results

# Compile order matters only for readability; Icarus resolves
# the hierarchy itself.
RTL_SRCS := \
	$(RTL_DIR)/address_decoder.v \
	$(RTL_DIR)/cache_data_ram.v \
	$(RTL_DIR)/cache_tag_ram.v \
	$(RTL_DIR)/valid_bit_ram.v \
	$(RTL_DIR)/main_memory.v \
	$(RTL_DIR)/tag_comparator.v \
	$(RTL_DIR)/cache_controller.v \
	$(RTL_DIR)/cache_top.v

# Unit and integration testbenches (run by `make regress`)
TESTS := address_decoder cache_controller cache_memory cache_rw cache_top

# Benchmark testbench (run by `make perf`)
PERF  := cache_performance

DIRS := $(RES_DIR) $(RES_DIR)/waveforms $(RES_DIR)/graphs \
        $(RES_DIR)/logs $(RES_DIR)/traces $(RES_DIR)/synthesis

.PHONY: help all regress perf analyze synth waves clean dirs $(TESTS) $(PERF)

#---------------------------------------------------------------
help:
	@echo "Direct-Mapped Cache Controller"
	@echo ""
	@echo "  make regress   compile and run all functional tests"
	@echo "  make perf      run the AMAT / hit-rate benchmark"
	@echo "  make analyze   regenerate performance graphs"
	@echo "  make synth     run Yosys generic synthesis"
	@echo "  make all       everything above, in order"
	@echo "  make waves TB=cache_rw"
	@echo "  make clean     remove generated files"

all: regress perf analyze synth
	@echo ""
	@echo "=============================================="
	@echo " Full build complete."
	@echo "=============================================="

dirs:
	@mkdir -p $(DIRS)

#---------------------------------------------------------------
# Build one simulation binary:  results/<name>_sim
#---------------------------------------------------------------
$(RES_DIR)/%_sim: $(TB_DIR)/tb_%.v $(RTL_SRCS) | dirs
	@echo "[iverilog] $*"
	@$(IVERILOG) $(IVFLAGS) -s tb_$* -o $@ $(RTL_SRCS) $<

#---------------------------------------------------------------
# Functional regression. Any $fatal makes vvp exit non-zero,
# so a broken test stops the build instead of being missed.
#---------------------------------------------------------------
regress: dirs $(addprefix $(RES_DIR)/,$(addsuffix _sim,$(TESTS)))
	@echo ""
	@echo "=============================================="
	@echo " FUNCTIONAL REGRESSION"
	@echo "=============================================="
	@rm -f $(RES_DIR)/logs/regression.log
	@set -o pipefail; for t in $(TESTS); do \
		echo ""; \
		echo ">>> $$t"; \
		if ! $(VVP) $(RES_DIR)/$${t}_sim 2>&1 | tee -a $(RES_DIR)/logs/regression.log; then \
			echo ""; \
			echo "REGRESSION FAILED in $$t"; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "=============================================="
	@echo " ALL FUNCTIONAL TESTS PASSED"
	@echo "=============================================="
#---------------------------------------------------------------
perf: dirs $(RES_DIR)/$(PERF)_sim
	@echo ""
	@echo "=============================================="
	@echo " PERFORMANCE / AMAT BENCHMARK"
	@echo "=============================================="
	@$(VVP) $(RES_DIR)/$(PERF)_sim 2>&1 | tee $(RES_DIR)/logs/performance.log

#---------------------------------------------------------------
analyze: $(RES_DIR)/performance.csv
	@$(PYTHON) scripts/analyze_performance.py

$(RES_DIR)/performance.csv:
	@$(MAKE) --no-print-directory perf

#---------------------------------------------------------------
synth: dirs
	@echo ""
	@echo "=============================================="
	@echo " YOSYS GENERIC SYNTHESIS"
	@echo "=============================================="
	@$(YOSYS) -l $(RES_DIR)/synthesis/yosys_report.log -s scripts/synth.ys
	@echo "Report: $(RES_DIR)/synthesis/yosys_report.log"

#---------------------------------------------------------------
# make waves TB=cache_rw
#---------------------------------------------------------------
waves:
	@if [ -z "$(TB)" ]; then \
		echo "Usage: make waves TB=<cache_rw|cache_top|cache_performance|...>"; \
		exit 1; \
	fi
	gtkwave $(RES_DIR)/waveforms/$(TB).vcd

#---------------------------------------------------------------
clean:
	@rm -f $(RES_DIR)/*_sim
	@rm -f $(RES_DIR)/waveforms/*.vcd
	@rm -f $(RES_DIR)/graphs/*.png
	@rm -f $(RES_DIR)/traces/*.csv
	@rm -f $(RES_DIR)/logs/*.log
	@rm -f $(RES_DIR)/performance.csv
	@echo "Generated files removed."
