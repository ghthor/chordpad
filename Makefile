GOFILES := $(shell find . -name "*.go" -print)

chordpad: $(GOFILES)
	go build

chordpad.pid: chordpad
	./make/process $<

chordpad.alive: chordpad chordpad.pid

chordpad.dead:
	cat chordpad.pid | xargs kill || true
	rm chordpad.pid || true

.PHONY: %.dead %.alive
