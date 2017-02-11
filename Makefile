GOFILES := $(shell find . -name "*.go" -print)

alive: chordpad.pid

dead:
	./make/process-dead chordpad

chordpad: $(GOFILES)
	go build

chordpad.pid: dead chordpad
	./make/process chordpad

.PHONY: %.dead %.alive
