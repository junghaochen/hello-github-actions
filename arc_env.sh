# Run source env.sh to source this file
echo "Enabling Environment"
arc shell \
	cmake/3.21.3 \
	python/3.7.7 \
	zephyr_sdk/0.13.1 \
	riscv_gnu/baremetal/sifive/10.2.0-2020.12.8 \
	fpga_simics_test/main/[QUALIFIED_BUILD=1]

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export PATH=$SCRIPT_DIR/venv/bin:$PATH

source ./zephyr/zephyr-env.sh

#export CROSS_COMPILE=/p/psg/ctools/riscv_tools/sifive/10.2.0-2020.12.8/linux64/bin/riscv64-unknown-elf-
#export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
