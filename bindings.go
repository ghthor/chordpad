package main

import (
	"github.com/ghthor/chordpad/input"
	"github.com/ghthor/uinput"
)

var Chords = map[input.Chord]OutputEvent{
	17:  Func(FN_ESCAPE),
	128: Letter(uinput.KEY_N),
	132: Letter(uinput.KEY_V),
	238: Letter(uinput.KEY_W),
	224: Func(FN_ENTER),
	68:  Func(FN_SPACE),
	40:  Letter(uinput.KEY_Q),
	3:   Letter(uinput.KEY_X),
	32:  Letter(uinput.KEY_O),
	72:  Letter(uinput.KEY_J),
	192: Letter(uinput.KEY_H),
	9:   Letter(uinput.KEY_W),
	130: Letter(uinput.KEY_Z),
	34:  Func(FN_TAB),
	6:   Letter(uinput.KEY_R),
	160: Letter(uinput.KEY_M),
	144: Letter(uinput.KEY_K),
	1:   Letter(uinput.KEY_S),
	136: Func(FN_BACKSPACE),
	12:  Letter(uinput.KEY_C),
	80:  Letter(uinput.KEY_L),
	10:  Letter(uinput.KEY_D),
	96:  Letter(uinput.KEY_U),
	5:   Letter(uinput.KEY_F),
	37:  Letter(uinput.KEY_B),
	16:  Letter(uinput.KEY_P),
	2:   Letter(uinput.KEY_T),
	4:   Letter(uinput.KEY_E),
	64:  Letter(uinput.KEY_I),
	36:  Letter(uinput.KEY_G),
	66:  Letter(uinput.KEY_Y),
	8:   Letter(uinput.KEY_A),
}
