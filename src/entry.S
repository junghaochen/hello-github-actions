    .section .init

    .globl _start
    .altmacro

_start:
    csrw    mscratch, zero
    la      sp, __kernel_stack_end

    // zeroize the BSS
    la      t0, __kernel_bss_start
    la      t1, __kernel_bss_end

    bge     t0, t1, 2f
1:  sw      zero, 0(t0)
    add     t0, t0, 4
    blt     t0, t1, 1b
2:

    // setup trap entry
    la      t1, hv_trap_entry
    csrw    mtvec, t1

    // initialize global CTORs
    la      s0, __ctors_GLOBAL__
1:
        lw      t0, (s0)
        beqz    t0, 2f
        addi    s0, s0, 4
        jalr    t0
    j       1b
2:

    nop

    // wrap current context into world 0 and return SP - sp <= world_t::wrap_world0
    // we need to have a SP here with a few words in case data is pushed on the stack
    //albert//la      a0, world0test
    //albert//jal     _ZN7world_t11wrap_world0Ej
    mv      sp, a0
    // At this point, we run on world-0 stack

    // call void cpu_t::init(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3)
    //albert//jal     _ZN5cpu_t4initEjjjj

    // Regions for testing
    li      t1, (0x90000000 >> 2) | (0x200000 / 8 - 1);    // 2MB RAM
    csrw    pmpaddr0, t1

    li      t1, (0xa0000000 >> 2) | (0x80000 / 8 - 1);     // 512K ROM
    csrw    pmpaddr1, t1

    li      t1, (0x10013000 >> 2) | (0x1000 / 8 - 1);      // 4K Debug IO
    csrw    pmpaddr2, t1

    li      t1, (0x10000000 >> 2) | (0x4000 / 8 - 1);      // 4K Serial IO
    csrw    pmpaddr3, t1

    li      t1, (0x00000000 >> 2) | (0x100 / 8 - 1);
    csrw    pmpaddr4, t1

    csrw    pmpaddr5, zero
    csrw    pmpaddr6, zero
    csrw    pmpaddr7, zero

    li      t0, 0x1b1b1d1f                          // NAPOT-RW-, NAPOT-RW-, NAPOT-R-X,NAPOT-RWX
    csrw    pmpcfg0, t0

    li      t0, 0x0000001f
    csrw    pmpcfg1, t0                           // DIS, DIS, DIS, DIS


    // call static void world_t::enter_new_world()
    jal     _ZN7world_t15enter_new_worldEv

    // ERROR: we should never get here
 3:
    j       3b


    .section    .text.trap_handlers

/**
    Hypervisor trap entry

    - if not from m-mode, load m-mode stack and store original sp in mscratch
    - store all non-callee saved registers on stack
    - call cpu_t::trap(uint32_t &epc, uint32_t mstatus, uint32_t mcause);
    - update epc and return to revious code and mode
*/
    .set stksize,(4*19)

    .macro  st_reg _reg
        sw      x\_reg,(4*\_reg)(x31)
    .endm
    .macro  ld_reg _reg
        lw      x\_reg,(4*\_reg)(x31)
    .endm

    // handling exception when it was not thrown from within m-mode
    // x31 points to register save area
m_trap_not_m:
    .set    reg, 1
    .rept   30
        st_reg  %reg
        .set    reg, reg+1
    .endr
    // get user x31 back from mscratch and store it into save-restore area
    csrrw   x30, mscratch, zero
    sw      x30, (4*31)(x31)
    addi    sp, x31, 0x3fc          // sizeof WCB

    // a0 parameter is reference to epc - reg[0] used for storing the IP.
    csrr    x30, mepc
    sw      x30, 0(x31)
    addi    a0, x31, 0              // offset into WCB reg[0]

    csrr    a1, mstatus
    sw      a1, (4*32)(x31)        // reg[32]
    csrr    a2, mcause
    // call void cpu_t::trap(uint32_t &epc, uint32_t mstatus, uint32_t mcause)
    //albert//jal     ra, _ZN5cpu_t4trapERjjj

resume_non_mmode:
    // calculate the beginning of the control block pointer
    li      x31, -1024
    and     x31, sp, x31

    .set    reg, 1
    .rept   29
        ld_reg  %reg
        .set    reg, reg+1
    .endr

    lw      x30, 0(x31)                         // user_reg[0] is used for storing the instruction ptr.
    csrw    mepc, x30

    lw      x30, (4*32)(x31)                    // load mstatus
    csrw    mstatus, x30

    lw      x30, (4*30)(x31)
    csrw    mscratch, x31                       // write current vhart_t pointer back to mscratch
    lw      x31, (4*31)(x31)

    .globl  return_non_mmode
return_non_mmode:
    mret

/************************************************************************/
/** THIS IS THE ACTUAL ENTRY POINT **************************************/
hv_trap_entry:
    csrrw   x31, mscratch, x31
    bnez    x31, m_trap_not_m

m_trap_from_m:
    csrrw   x31, mscratch, zero

    addi    sp, sp, -(stksize)

    sw      a0, 0(sp)
    csrr    a0, mepc
    sw      a0, 12(sp)
    add     a0, sp, 12                      // a0 <= ref to mepc on stack

    sw      a1, 4(sp)
    sw      a2, 8(sp)

    csrr    a1, mstatus
    csrr    a2, mcause

    // store only all caller saved registers, the compiler will do the
    // rest for us when necessatry
    sw      ra, 16(sp)
    sw      t0, 20(sp)
    sw      t1, 24(sp)
    sw      t2, 28(sp)

    sw      t3, 32(sp)
    sw      t4, 36(sp)
    sw      t5, 40(sp)
    sw      t6, 44(sp)

    sw      a3, 52(sp)
    sw      a4, 56(sp)
    sw      a5, 60(sp)
    sw      a6, 64(sp)
    sw      a7, 72(sp)

    // call void cpu_t::trap(uint32_t &epc, uint32_t mstatus, uint32_t mcause)
    //albert//jal     ra, _ZN5cpu_t4trapERjjj

    lw      ra, 16(sp)
    lw      t0, 20(sp)
    lw      t1, 24(sp)
    lw      t2, 28(sp)

    lw      t3, 32(sp)
    lw      t4, 36(sp)
    lw      t5, 40(sp)
    lw      t6, 44(sp)

    lw      a3, 52(sp)
    lw      a4, 56(sp)
    lw      a5, 60(sp)
    lw      a6, 64(sp)
    lw      a7, 72(sp)

    lw      a0, 12(sp)
    csrw    mepc, a0

    lw      a1, 4(sp)
    lw      a2, 8(sp)
    lw      a0, 0(sp)
    addi    sp, sp, (stksize)
    mret

/**
    Generic M-mode entry code when a new world is started
    SP is set to the top of the world's stack, so we can easily determine
    the world-control block address; when entering world in s mode, only the
    IP is loaded from the vHART at this point

    static void world_t::enter_new_world();
*/
    .section    .text.enter_new_world
    .globl  _ZN7world_t15enter_new_worldEv
_ZN7world_t15enter_new_worldEv:
    // TODO: mstatus should be set in vhart ****************
    // mstatus.mpp = 1 (smode)
    li      t2, 0x1800
    csrc    mstatus, t2
    li      t3, 0x0800
    csrs    mstatus, t3

    // mstatus.MPIE = 0
    li      t2, 0x0080
    csrc    mstatus, t2

    // store mstatus so we can fetch it later - do this in init?
    li      x31, -1024
    and     x31, sp, x31

    csrr    x30, mstatus
    sw      x30, (4*32)(x31)


    // exception delegation - set for EXC 8 (Environment call from S/U-mode should go to S-mode)
    li      t4, (1 << 8)
    csrs    medeleg, t4

    // delegate Supervisor-{Software 1,Timer 5, External 9}-Interrupt to S-mode
    li      t4, (1 << 9) | (1 << 5) | (1 << 1)
    csrs    mideleg, t4

    // enable MEIE and MTIE so we get timer interrupts when in s/u mode
    li      t4, 0x880
    csrs    mie, t4

    j       resume_non_mmode
