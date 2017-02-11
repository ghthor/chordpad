package main

import (
	"errors"
	"fmt"
	"log"
	"math"
	"time"

	"github.com/cenk/backoff"
	"github.com/ghthor/chordpad/input"
	evdev "github.com/ghthor/golang-evdev"
)

type ChordIndex uint

func keysDown(m input.Model, keys input.Chord) input.Model {
	m.Keys |= keys
	m.Build |= m.Keys
	m.Trigger = 0
	return m
}

func keysUp(m input.Model, keys input.Chord) input.Model {
	m.Keys ^= keys
	m.Trigger = m.Build
	m.Build = 0
	return m
}

func applyKey(state evdev.KeyEventState) func(input.Model, input.Chord) input.Model {
	switch state {
	case evdev.KeyDown:
		return keysDown
	default:
		return keysUp
	}
}

const (
	PAD_S ChordIndex = iota
	PAD_E
	PAD_N
	PAD_W
)

const PAD_ALL input.Chord = 1 | 2 | 4 | 8

const MaxDeadzone = 5 * math.MaxInt16 / 10
const MaxDeadzoneSq = MaxDeadzone * MaxDeadzone

const (
	BTN_A input.Chord = 1 << (iota + 8)
	BTN_TL1
	BTN_TL0
	BTN_THUMBL

	BTN_THUMBR
	BTN_TR0
	BTN_TR1
	BTN_B
)

var BtnIndex = map[int]input.Chord{
	evdev.BTN_A:      BTN_A,
	evdev.BTN_B:      BTN_B,
	evdev.BTN_TL:     BTN_TL0,
	evdev.BTN_TR:     BTN_TR0,
	evdev.BTN_THUMBL: BTN_THUMBL,
	evdev.BTN_THUMBR: BTN_THUMBR,
}

type AbsPad struct {
	offset ChordIndex
	x, y   int32
}

func (p AbsPad) Update(m input.Model) input.Model {
	if p.y == 0 && p.x == 0 {
		return p.touchUp(m)
	}
	return p.touchMove(m)
}

func (p AbsPad) touchMove(m input.Model) input.Model {
	keys := m.Keys | (buttonFor(p.x, p.y) << p.offset)
	if m.Keys == 0 {
		m.Build = keys
	} else if m.Keys != keys {
		m.Build = keys
	}
	m.Keys = keys
	m.Trigger = 0
	return m
}

func (p AbsPad) touchUp(m input.Model) input.Model {
	m.Keys = m.Keys &^ (PAD_ALL << p.offset)
	m.Trigger = m.Build
	m.Build = 0
	return m
}

func buttonFor(x, y int32) input.Chord {
	var xx = x * x
	var yy = y * y
	if xx+yy < MaxDeadzoneSq {
		return 0
	}

	if xx > yy {
		if x < 0 {
			return (1 << PAD_W)
		} else {
			return (1 << PAD_E)
		}
	} else {
		if y < 0 {
			return (1 << PAD_S)
		} else {
			return (1 << PAD_N)
		}
	}
}

type AbsTrigger struct {
	output input.Chord
	value  int32
}

func (t *AbsTrigger) Update(model input.Model, value int32) input.Model {
	if t.value < 255 && value < 255 {
		t.value = value
		return model
	}

	if t.value == 255 && value == 255 {
		return model
	}

	t.value = value
	if value == 255 {
		return keysDown(model, t.output)
	}

	return keysUp(model, t.output)
}

type triggers map[int]*AbsTrigger

func newTriggers() map[int]*AbsTrigger {
	return map[int]*AbsTrigger{
		evdev.ABS_Z:  &AbsTrigger{BTN_TL1, 0},
		evdev.ABS_RZ: &AbsTrigger{BTN_TR1, 0},
	}
}

type touchpads struct {
	left, right *AbsPad
}

func (t touchpads) Update(m input.Model, e evdev.AbsEvent) input.Model {
	switch e.AxisCode {
	case evdev.ABS_HAT0X:
		t.left.x = e.Value
		return t.left.Update(m)
	case evdev.ABS_HAT0Y:
		t.left.y = e.Value
		return t.left.Update(m)

	case evdev.ABS_RX:
		t.right.x = e.Value
		return t.right.Update(m)
	case evdev.ABS_RY:
		t.right.y = e.Value
		return t.right.Update(m)

	default:
	}
	return m
}

func newPadAxes() touchpads {
	return touchpads{
		left:  &AbsPad{offset: 0},
		right: &AbsPad{offset: 4},
	}
}

type steamController struct {
	*evdev.InputDevice

	touchpads
	triggers
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

		if index, exists := BtnIndex[int(ke.Scancode)]; exists {
			return applyKey(ke.State)(model, index), nil
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
			return dev.triggers[abs.AxisCode].Update(model, abs.Value), nil
		default:
			return dev.touchpads.Update(model, *abs), nil
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
	return steamController{dev, newPadAxes(), newTriggers()}
}
