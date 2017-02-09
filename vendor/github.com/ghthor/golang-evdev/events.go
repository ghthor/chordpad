package evdev

import (
	"fmt"
	"syscall"
	"unsafe"
)

type InputEvent struct {
	Time  syscall.Timeval // time in seconds since epoch at which event occurred
	Type  uint16          // event type - one of ecodes.EV_*
	Code  uint16          // event code related to the event type
	Value int32           // event value related to the event type
}

// Get a useful description for an input event. Example:
//   event at 1347905437.435795, code 01, type 02, val 02
func (ev *InputEvent) String() string {
	return fmt.Sprintf("event at %d.%d, code %02d, type %s, val %02d",
		ev.Time.Sec, ev.Time.Usec, ev.Code, evType(ev.Type), ev.Value)
}

type evType int

func (v evType) String() string {
	return EV[int(v)]
}

var eventsize = int(unsafe.Sizeof(InputEvent{}))

type KeyEventState uint8

const (
	KeyUp   KeyEventState = 0x0
	KeyDown KeyEventState = 0x1
	KeyHold KeyEventState = 0x2
)

// KeyEvents are used to describe state changes of keyboards, buttons,
// or other key-like devices.
type KeyEvent struct {
	Event    *InputEvent
	Scancode uint16
	Keycode  uint16
	State    KeyEventState
}

func (kev *KeyEvent) New(ev *InputEvent) {
	kev.Event = ev
	kev.Keycode = 0 // :todo
	kev.Scancode = ev.Code

	switch ev.Value {
	case 0:
		kev.State = KeyUp
	case 2:
		kev.State = KeyHold
	case 1:
		kev.State = KeyDown
	}
}

func NewKeyEvent(ev *InputEvent) *KeyEvent {
	kev := &KeyEvent{}
	kev.New(ev)
	return kev
}

func (ev *KeyEvent) String() string {
	state := "unknown"

	switch ev.State {
	case KeyUp:
		state = "up"
	case KeyHold:
		state = "hold"
	case KeyDown:
		state = "down"
	}

	var code string
	if key, exists := KEY[int(ev.Scancode)]; exists {
		code = key
	} else if btn, exists := BTN[int(ev.Scancode)]; exists {
		code = btn
	} else {
		code = fmt.Sprint(ev.Scancode)
	}

	return fmt.Sprintf("key event at %d.%d, %s (%d), (%s)",
		ev.Event.Time.Sec, ev.Event.Time.Usec,
		code, ev.Event.Code, state)
}

// RelEvents are used to describe relative axis value changes,
// e.g. moving the mouse 5 units to the left.
type RelEvent struct {
	Event *InputEvent
}

func (rev *RelEvent) New(ev *InputEvent) {
	rev.Event = ev
}

func NewRelEvent(ev *InputEvent) *RelEvent {
	rev := &RelEvent{}
	rev.New(ev)
	return rev
}

func (ev *RelEvent) String() string {
	return fmt.Sprintf("relative axis event at %d.%d, %s",
		ev.Event.Time.Sec, ev.Event.Time.Usec,
		REL[int(ev.Event.Code)])
}

// AbsEvents are use to describe Absolute axis value changes,
// e.g. moving a joystick or a position on a touchpad.
type AbsEvent struct {
	Event *InputEvent

	Axis     string
	AxisCode int
	Value    int32
}

func NewAbsEvent(ev *InputEvent) *AbsEvent {
	a := AbsEvent{
		Event: ev,

		Axis:     ABS[int(ev.Code)],
		AxisCode: int(ev.Code),
		Value:    ev.Value,
	}

	return &a
}

func (a AbsEvent) String() string {
	return fmt.Sprintf("%s(%d) == %d",
		a.Axis, a.AxisCode, a.Value)
}

// TODO: Make this work

var EventFactory map[uint16]interface{} = make(map[uint16]interface{})

func init() {
	EventFactory[uint16(EV_KEY)] = NewKeyEvent
	EventFactory[uint16(EV_REL)] = NewRelEvent
	EventFactory[uint16(EV_ABS)] = NewAbsEvent
}
