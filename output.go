package main

import (
	"time"

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

type Letter int
type Func Action
type Num int

func (key singleKeyPress) OutputTo(vk *uinput.VKeyboard) error {
	err := vk.SendKeyPress(int(key))
	if err != nil {
		return err
	}

	time.Sleep(50 * time.Millisecond)

	return vk.SendKeyRelease(int(key))
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
