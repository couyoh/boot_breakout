BUILDDIR := build
SRCDIR := src
BOCHS := bochs
OUTPUT := $(BUILDDIR)/main.bin

all: $(OUTPUT)

$(BUILDDIR)/%.bin: $(SRCDIR)/%.asm | $(BUILDDIR)
	nasm $< -o $@

qemu: $(OUTPUT)
	qemu-system-x86_64 -hda $<

debug: $(OUTPUT)
	$(BOCHS) -dbg -qf ./.bochsrc

clean:
	rm -f $(OUTPUT)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)
