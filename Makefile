//C_SRC 		:= $(wildcard src/*.cc src/platform/*.cc)
S_SRC		:= $(wildcard src/*.S)

OBJDIR 		:= out

TARGET		?= km

VERB		= @

//C_OBJ 		:= $(addprefix $(OBJDIR)/,$(patsubst %.cc,%.o,$(C_SRC)))
S_OBJ 		:= $(addprefix $(OBJDIR)/,$(patsubst %.S,%.o,$(S_SRC)))

all: all_dump

-include build/Makefile.local

include build/compiler.mk

$(OBJDIR)%/:
	$(VERB)mkdir -p $@

//OBJECTS := $(C_OBJ) $(S_OBJ)
OBJECTS := $(S_OBJ)

$(foreach OBJECT,$(OBJECTS),$(eval $(OBJECT): | $(dir $(OBJECT))))

all_dump:	$(OBJDIR)/hv.dump

//$(OBJDIR)/hv.elf:	$(S_OBJ) $(C_OBJ) | src/linker/hypervisor.$(TARGET).ld
$(OBJDIR)/hv.elf:	$(S_OBJ) | src/linker/hypervisor.$(TARGET).ld
	$(info Linking $@)
	$(VERB)$(LD) -o $@ $^ -T src/linker/hypervisor.$(TARGET).ld

clean:
	$(info Cleaning up $(OBJDIR)/*)
	$(VERB)rm -rf $(OBJDIR)/*
