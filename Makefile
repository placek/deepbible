include build/download.mk
include build/merge.mk
include build/upload.mk
include build/helpers.mk

.PHONY: all clean

all: clean upload apply-helpers

clean: clean-download clean-merged clean-helpers upload-cross-references
