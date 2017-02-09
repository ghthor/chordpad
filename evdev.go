package main

import (
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/cenk/backoff"
	"github.com/ghthor/chordpad/input"
	evdev "github.com/ghthor/golang-evdev"
)

type AbsTrigger struct {
	output ChordIndex
	value  int32
}

func (t *AbsTrigger) Update(model Model, value int32) Model {
	if t.value < 255 && value < 255 {
		t.value = value
		return model
	}

	if t.value == 255 && value == 255 {
		return model
	}

	t.value = value
	if value == 255 {
		return model.keyDown(t.output)
	}

	return model.keyUp(t.output)
}

type steamController struct {
	*evdev.InputDevice

	triggers map[int]*AbsTrigger
}

func newTriggers() map[int]*AbsTrigger {
	return map[int]*AbsTrigger{
		evdev.ABS_Z:  &AbsTrigger{BTN_TL1, 0},
		evdev.ABS_RZ: &AbsTrigger{BTN_TR1, 0},
	}
}

type Model struct {
	input.Model
}

type ChordIndex uint

const (
	BTN_A ChordIndex = iota
	BTN_TL1
	BTN_TL0
	BTN_THUMBL

	BTN_THUMBR
	BTN_TR0
	BTN_TR1
	BTN_B
)

var xboxBtnToChordIndex = map[int]ChordIndex{
	evdev.BTN_A:      BTN_A,
	evdev.BTN_B:      BTN_B,
	evdev.BTN_TL:     BTN_TL0,
	evdev.BTN_TR:     BTN_TR0,
	evdev.BTN_THUMBL: BTN_THUMBL,
	evdev.BTN_THUMBR: BTN_THUMBR,
}

func (m Model) applyKey(state evdev.KeyEventState) func(ChordIndex) Model {
	switch state {
	case evdev.KeyDown:
		return m.keyDown
	default:
		return m.keyUp
	}
}

func (m Model) keyDown(i ChordIndex) Model {
	m.Keys |= (1 << i)
	m.Build |= m.Keys
	m.Trigger = 0
	return m
}

func (m Model) keyUp(i ChordIndex) Model {
	m.Keys ^= (1 << i)
	m.Trigger = m.Build
	m.Build = 0
	return m
}

func (dev steamController) Update(model input.Model) (input.Model, error) {
	e, err := dev.ReadOne()
	if err != nil {
		return model, err
	}

	if e.Type == evdev.EV_SYN {
		return model, nil
	}

	switch e.Type {
	case evdev.EV_KEY:
		ke := evdev.NewKeyEvent(e)

		if index, exists := xboxBtnToChordIndex[int(ke.Scancode)]; exists {
			return Model{model}.applyKey(ke.State)(index).Model, nil
		}

		// TODO: Bind all possible buttons
		fmt.Println("unbound input: ", ke)
		return model, nil

	case evdev.EV_REL:
		// TODO: Map into a model change
		//e := evdev.NewRelEvent(e)
		return model, nil

	case evdev.EV_ABS:
		abs := evdev.NewAbsEvent(e)
		// TODO: Bind all possible input Axis
		switch abs.AxisCode {
		case evdev.ABS_Z:
			fallthrough
		case evdev.ABS_RZ:
			return dev.triggers[abs.AxisCode].Update(Model{model}, abs.Value).Model, nil
		default:
		}
		return model, nil

	default:
	}

	fmt.Println("unexpected input event: ", e.String())
	return model, nil
}

func (dev steamController) Close() error {
	return dev.File.Close()
}

// ErrNoValidInputDevices is returned when no valid evdev input devices are found
var ErrNoValidInputDevices = errors.New("no valid evdev input devices to use for chording")

func autoSelectDevice() (*evdev.InputDevice, error) {
	inputs, err := evdev.ListInputDevices("/dev/input/event*")
	if err != nil {
		return nil, err
	}

	if len(inputs) < 1 {
		return nil, ErrNoValidInputDevices
	}

	return inputs[0], nil
}

func autoSelectInputDeviceOp(output **evdev.InputDevice) func() error {
	return func() error {
		pad, err := autoSelectDevice()
		switch err {
		case ErrNoValidInputDevices:
			log.Println(ErrNoValidInputDevices)
			return ErrNoValidInputDevices

		default:
			log.Fatal(err)

		case nil:
		}

		*output = pad
		return nil
	}
}

func autoSelectEvdevDevice() input.Device {
	var dev *evdev.InputDevice

	backoffConfig := backoff.ExponentialBackOff{
		InitialInterval:     500 * time.Millisecond,
		RandomizationFactor: 0.5,
		Multiplier:          1.5,
		MaxInterval:         5 * time.Second,
		MaxElapsedTime:      0,
		Clock:               backoff.SystemClock,
	}
	backoffConfig.Reset()

	err := backoff.Retry(autoSelectInputDeviceOp(&dev), &backoffConfig)
	if err != nil {
		log.Fatal(err)
	}

	// TODO: Map into different types of devices
	return steamController{dev, newTriggers()}
}
