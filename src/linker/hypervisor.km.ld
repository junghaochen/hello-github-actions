OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv",
	      "elf32-littleriscv")
OUTPUT_ARCH(riscv)

ENTRY(_start);

/* KM Address Map

┌──────────┬──────────────────────────────────┬──┬──────┬──────────┬──────┬────┬─────┬────┐
│      Base│Object                            │Fn│Offset│    Length│Target│Prio│Align│Swap│
├──────────┼──────────────────────────────────┼──┼──────┼──────────┼──────┼────┼─────┼────┤
│       0x0│sdm.cpu_complex.scr:rom_data      │  │   0x0│   0x20000│      │   0│    8│    │
│ 0x2000000│sdm.cpu_complex.clint:regs        │  │   0x0│    0xc000│      │   0│    8│    │
│ 0xc000000│sdm.cpu_complex.plic:regs         │  │   0x0│ 0x4000000│      │   0│    8│    │
│0x10000000│sdm.uart0:regs                    │  │   0x0│    0x4000│      │   0│    8│    │
│0x10013000│sdm.cpu_complex.tty0              │  │   0x0│       0x1│      │   0│    8│    │
│0x10013001│sdm.cpu_complex.dummyram          │  │   0x0│       0x3│      │   0│     │    │
│0x10013004│sdm.cpu_complex.tty1              │  │   0x0│       0x1│      │   0│    8│    │
│0x10013005│sdm.cpu_complex.dummyram          │  │   0x0│       0x3│      │   0│     │    │
│0x1001300c│sdm.cpu_complex.tty3              │  │   0x0│       0x1│      │   0│    8│    │
│0x1001300d│sdm.cpu_complex.dummyram          │  │   0x0│       0x3│      │   0│     │    │
│0x20000300│sdm.cpu_complex.scr:lock_ctrl     │  │   0x0│     0x200│      │   0│    8│    │
│0x20000500│sdm.cpu_complex.scr:non_redundancy│  │   0x0│     0x600│      │   0│    8│    │
│0x40000000│sdm.private_noc                   │  │   0x0│0x40000000│      │   0│     │    │
│0x60000000│sdm.spi                           │  │   0x0│0x20000000│      │   0│     │    │
│0x90000000│sdm.ram                           │  │   0x0│  0x200000│      │   0│     │    │
│0x91000000│sdm.ram                           │  │   0x0│   0x10000│      │   0│     │    │
│0xa0000000│sdm.rom                           │  │   0x0│   0x80000│      │   0│     │    │
│0xa1000000│sdm.patch_ram                     │  │   0x0│   0x10000│      │   0│     │    │
└──────────┴──────────────────────────────────┴──┴──────┴──────────┴──────┴────┴─────┴────┘
*/

__kernel_load_start     = 0xa0000000;       /** BOOT ROM */
__memory_start          = 0x90000000;       /** MEMORY */


MEMORY
{
    flash(rx)   : org = __kernel_load_start, len = 0x10000000
    sram(rwx)   : org = __memory_start, len = 0x180000
}


SECTIONS
{
    /* Discardable section */
    .init __kernel_load_start : {
        *(.init)
    } > flash

    .ctors : {
        /* ctors section, prio-sorted */
        . = ALIGN(16);
        __ctors_GLOBAL__ = .;
        *(SORT(.ctors.1*))
        *(SORT(.ctors.*))
        *(.ctors)
        *(.init_array)
        QUAD(0)
        __CTORS_END = .;
    } > flash


    /* Hypervisor Code - read only */
    .text : {
            __kernel_text_start = .;
            *(.text*)
            *(.gnu.linkonce.*)
            __kernel_text_size = . - __kernel_text_start;
            *(.rodata*)
            . = ALIGN(64);
    } > flash
    __kernel_size = SIZEOF(.text);

    /* RW data */
    .data : {
            QUAD(0xdeadbeef);
            *(.data*)
    } > sram

    .bss : {
        __kernel_bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(.lbss*)
        . = ALIGN(64);
        __kernel_bss_end = .;

        /* a temporary stack for initial setup */
        . += 4 * 512;
        __kernel_stack_end = .;
    } > sram


    /* Stabs debugging sections.  */
    .stab 0 : { *(.stab) }
    .stabstr 0 : { *(.stabstr) }
    .stab.excl 0 : { *(.stab.excl) }
    .stab.exclstr 0 : { *(.stab.exclstr) }
    .stab.index 0 : { *(.stab.index) }
    .stab.indexstr 0 : { *(.stab.indexstr) }

    /* special section that is discarded during linking
        all unwanted sections should go here */
/*
    /DISCARD/ :
    {
        *(*)
        *(.eh_frame)
        *(.note*)
        *(.comment)
    }
*/
}
