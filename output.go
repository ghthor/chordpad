package main

import (
	"github.com/ghthor/chordpad/input"
	"github.com/ghthor/uinput"
)

type Action int

const (
	FN_SPACE     Action = uinput.KEY_SPACE
	FN_TAB              = uinput.KEY_TAB
	FN_BACKSPACE        = uinput.KEY_BACKSPACE
	FN_DELETE           = uinput.KEY_DELETE
	FN_ENTER            = uinput.KEY_ENTER
	FN_ESCAPE           = uinput.KEY_ESC
)

// An OutputEvent is used to send virtual input events using a uinput device.
type OutputEvent interface {
	OutputTo(*uinput.VKeyboard) error
}

type singleKeyPress int

type Wrap struct {
	OutputEvent
	mod int
}
type ShiftPlus struct{ OutputEvent }

type Letter int
type Func Action
type Num int

func (key singleKeyPress) OutputTo(vk *uinput.VKeyboard) error {
	err := vk.SendKeyPress(int(key))
	if err != nil {
		return err
	}

	return vk.SendKeyRelease(int(key))
}

func (key ShiftPlus) OutputTo(vk *uinput.VKeyboard) error {
	return Wrap{key.OutputEvent, uinput.KEY_RIGHTSHIFT}.OutputTo(vk)
}

func (key Wrap) OutputTo(vk *uinput.VKeyboard) error {
	err := vk.SendKeyPress(int(key.mod))
	if err != nil {
		return err
	}

	err = key.OutputEvent.OutputTo(vk)
	if err != nil {
		return err
	}

	return vk.SendKeyRelease(int(key.mod))
}

func (key Letter) OutputTo(vk *uinput.VKeyboard) error {
	return singleKeyPress(key).OutputTo(vk)
}

func (key Func) OutputTo(vk *uinput.VKeyboard) error {
	return singleKeyPress(key).OutputTo(vk)
}

func (key Num) OutputTo(vk *uinput.VKeyboard) error {
	return singleKeyPress(key).OutputTo(vk)
}

func applyModifiersTo(key OutputEvent, mods input.Chord) OutputEvent {
	switch {
	case mods&MOD_SHIFT != 0:
		return ShiftPlus{key}

	case mods&MOD_CTRL != 0:
		return Wrap{key, uinput.KEY_RIGHTCTRL}

	case mods&MOD_ALT != 0:
		return Wrap{key, uinput.KEY_RIGHTALT}

	case mods&MOD_META != 0:
		return Wrap{key, uinput.KEY_RIGHTMETA}

	default:
	}

	return key
}
