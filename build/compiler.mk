CROSS		?= riscv64-unknown-elf-

CC			= $(CROSS)g++
LD			= $(CROSS)ld
OBJDUMP		= $(CROSS)objdump

INCDIRS		= inc

MFLAGS		:= -march=rv32ic -mabi=ilp32 -mno-fdiv

GCCINC 		:= $(dir $(shell $(CC) $(MFLAGS) --print-libgcc-file-name))../../include
INCDIRS     += $(GCCINC)

FFLAGS		?= -fno-threadsafe-statics -fno-builtin -fno-exceptions -fno-rtti

CFLAGS		= -O1 -ggdb -DPLATFORM=$(TARGET)

DEPFLAGS 	= -MT $@ -MMD -MP -MF $(OBJDIR)/$*.d

$(S_OBJ): $(OBJDIR)/%.o: %.S $(OBJDIR)/%.d
	$(info Assembling $@)
	$(VERB)$(CC) $(DEPFLAGS) $(CFLAGS) $(FFLAGS) $(MFLAGS) -c $< -o $@

%.dump: %.elf
	$(info Object Dump: $@)
	$(VERB)$(OBJDUMP) -ldxS --demangle $^ > $@

DEPFILES	:= $(S_SRC:%.S=$(OBJDIR)/%.d)

$(DEPFILES):

include $(wildcard $(DEPFILES))
