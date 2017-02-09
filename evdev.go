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

type steamController struct {
	*evdev.InputDevice
}

type Model struct {
	input.Model
}

var xboxBtnToChordIndex = map[int]uint{
	evdev.BTN_A:      0,
	evdev.BTN_B:      1,
	evdev.BTN_TL:     2,
	evdev.BTN_TR:     3,
	evdev.BTN_THUMBL: 4,
	evdev.BTN_THUMBR: 5,
}

func (m Model) applyKey(state evdev.KeyEventState) func(uint) Model {
	switch state {
	case evdev.KeyDown:
		return m.keyDown
	default:
		return m.keyUp
	}
}

func (m Model) keyDown(index uint) Model {
	m.Keys |= (1 << index)
	m.Build |= m.Keys
	m.Trigger = 0
	return m
}

func (m Model) keyUp(index uint) Model {
	m.Keys ^= (1 << index)
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
		// TODO: Map into a model change
		abs := evdev.NewAbsEvent(e)
		fmt.Println(abs)
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
	return steamController{dev}
}
