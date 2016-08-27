package main

import (
	"github.com/ghthor/uinput"
	evdev "github.com/gvalkov/golang-evdev"
)

var ChordInputMappingDefaults = ChordInputMapping{
	evdev.BTN_BASE4:    ChordBtn0,
	evdev.BTN_TOP2:     ChordBtn1,
	evdev.BTN_TOP:      ChordBtn2,
	evdev.BTN_JOYSTICK: ChordBtn3,
}

var ChordOutputMappingDefaults = ChordOutputMapping{
	1: uinput.KEY_A,
	2: uinput.KEY_B,
	3: uinput.KEY_C,
	4: uinput.KEY_D,
	5: uinput.KEY_E,
	6: uinput.KEY_F,
	// TODO: Fill out with a complete usable set of keys
}
