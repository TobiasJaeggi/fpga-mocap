PROJECT = blobDetector

# please refer to the followings for more information:
#   https://stackoverflow.com/a/30142139/2604712
#       > Makefile, header dependencies
#   https://www.gnu.org/software/make/manual/html_node/Text-Functions.html
#   https://devhints.io/makefile
#   https://bytes.usc.edu/cs104/wiki/makefile/
#   https://stackoverflow.com/a/3477400/2604712
#       > What do @, - and + do as prefixes to recipe lines in Make?

TOOLCHAIN ?= or1k-elf
CC = $(TOOLCHAIN)-gcc
LD = $(TOOLCHAIN)-ld
ELF2MEM ?= convert_or32
DEBUG ?= 0

CFLAGS ?= -D OR1420 -Wall
LDFLAGS ?=

_LDFLAGS += -nostartfiles
_CFLAGS += -MMD -DPRINTF_INCLUDE_CONFIG_H -I include/ -I support/include

ifeq ($(DEBUG), 1)
BUILD = build-debug
_CFLAGS += -Og -g
else
BUILD = build-release
_CFLAGS += -Os -msoft-div
endif

# User sources go in the src/ directory
# Support files go in the support/src/ directory

CSRCS = $(wildcard src/*.c) $(wildcard support/src/*.c)
SSRCS = $(wildcard src/*.s) $(wildcard support/src/*.s)

OBJS = $(SSRCS:%.s=$(BUILD)/%.s.o) $(CSRCS:%.c=$(BUILD)/%.c.o)
DEPS = $(OBJS:%.o=%.d) # dependencies

ELF = $(addsuffix .elf,$(BUILD)/$(PROJECT))
MEM = $(addsuffix .mem,$(BUILD)/$(PROJECT))

mem : $(MEM)
elf : $(ELF)

$(MEM) : $(ELF)
	mkdir -p $(@D)
	cd $(BUILD); \
		$(ELF2MEM) $(addsuffix .elf,$(PROJECT)); \
		mv $(addsuffix .elf.mem,$(PROJECT)) $(addsuffix .mem,$(PROJECT)); \
		mv $(addsuffix .elf.cmem,$(PROJECT)) $(addsuffix .cmem,$(PROJECT))

$(ELF) : $(OBJS)
	mkdir -p $(@D)
	$(CC) $(_LDFLAGS) $(LDFLAGS) $^ -o $@

-include $(DEPS)

# user source code
$(BUILD)/src/%.c.o : src/%.c
	mkdir -p $(@D)
	$(CC) $(_CFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD)/src/%.s.o : src/%.s
	mkdir -p $(@D)
	$(CC) $(_CFLAGS) $(CFLAGS) -c $< -o $@

# for support
$(BUILD)/support/src/%.c.o : support/src/%.c
	mkdir -p $(@D)
	$(CC) $(_CFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD)/support/src/%.s.o : support/src/%.s
	mkdir -p $(@D)
	$(CC) $(_CFLAGS) $(CFLAGS) -c $< -o $@

.PHONY : clean

clean :
	-rm -rf $(BUILD)/*
