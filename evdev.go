package main

import (
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/cenk/backoff"
	evdev "github.com/ghthor/golang-evdev"
)

type evdevKeyEvent struct {
	btn    Button
	source *evdev.KeyEvent
}

func (e evdevKeyEvent) Button() Button { return e.btn }
func (e evdevKeyEvent) State() ButtonState {
	return ButtonState(e.source.State)
}

type evdevInputDevice struct {
	config InputConfig
	*evdev.InputDevice
}

func (dev evdevInputDevice) ReadEvent() (ButtonEvent, error) {
readOne:
	e, err := dev.ReadOne()
	if err != nil {
		return nil, err
	}

	fmt.Println("input event: ", e.String())

	switch e.Type {
	case evdev.EV_KEY:
		ke := evdev.NewKeyEvent(e)
		if btn, isBound := dev.config[int(ke.Scancode)]; isBound {
			return evdevKeyEvent{btn, ke}, nil
		}

		return nil, UnboundInputEvent{ke.String()}

	case evdev.EV_REL:
		e := evdev.NewRelEvent(e)
		return nil, UnboundInputEvent{e.String()}

	default:
	}

	goto readOne
}

func (dev evdevInputDevice) Close() error {
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

func autoSelectEvdevDevice() InputDevice {
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

	return evdevInputDevice{InputConfigDefaults, dev}
}
