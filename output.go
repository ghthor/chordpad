package main

import (
	"time"

	"github.com/ghthor/uinput"
)

// An OutputEvent is used to send virtual input events using a uinput device.
type OutputEvent interface {
	OutputTo(*uinput.VKeyboard) error
}

type singleKeyPress int

type Letter int
type Func int
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
