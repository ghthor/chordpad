package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/ghthor/uinput"
)

// A Button is used to map multiple input sources into a shared namespace.
type Button int

// ButtonState is an Up/Down value for a given button
type ButtonState int

const (
	ButtonUp ButtonState = iota
	ButtonDown
)

// A ButtonEvent is used to abstract over potentially different event
// type sources(evdev,dx_input,etc) into the cross platform, shared
// namespace used by a chord device definition to produce OutputEvents.
type ButtonEvent interface {
	Button() Button
	State() ButtonState
}

type InputDevice interface {
	ReadEvent() (ButtonEvent, error)

	io.Closer
}

type UnboundInputEvent struct {
	// TODO: Reduce generalization into a common pattern
	Description string
}

func (e UnboundInputEvent) Error() string {
	return fmt.Sprint("unbound input", e.Description)
}

type InputConfig map[int]Button

// A Chord is used to store a bitfield of button states. Each
// index in the the bitfield represents the on/off state of a
// button associated to an input device.
type Chord uint32

// ChordBtn0 ... are used as bitflags, mapped to buttons on an input device.
const (
	ChordBtn0 Chord = 1 << iota
	ChordBtn1
	ChordBtn2
	ChordBtn3
	ChordBtn4
	ChordBtn5
	ChordBtn6
	ChordBtn7
	ChordBtn8
	ChordBtn9
	ChordBtn10
)

type ChordInputMapping map[Button]Chord

// A ChordOutputMapping will contain a map of chord values to the key
// code they trigger. This is used to configure what key a specific chord
// will output to the computer.
type ChordOutputMapping map[Chord]int

type ButtonEvents <-chan ButtonEvent

type ButtonEventProcess func(context.Context, <-chan ButtonEvent) <-chan OutputEvent

func (stream ButtonEvents) MapIntoKeyEvents(ctx context.Context, start ButtonEventProcess) <-chan OutputEvent {
	return start(ctx, stream)
}

type InputStream struct {
	InputDevice
	err error
}

func (stream InputStream) Err() error { return stream.err }

// ErrStreamClosedByContext is returned when a stream generator
// is closed by it's parent context being completed.
var ErrStreamClosedByContext = errors.New("input event stream context completed")

// ReadEvents starts a process reading events from an InputDevice
// and sending those events down stream via a returned channel.
func (stream *InputStream) ReadEvents(ctx context.Context) ButtonEvents {
	stream.err = nil

	output := make(chan ButtonEvent)

	go func() {
		<-ctx.Done()
		stream.err = ErrStreamClosedByContext
		stream.InputDevice.Close()
	}()

	go func(output chan<- ButtonEvent) {
		defer close(output)

		for {
			ev, err := stream.InputDevice.ReadEvent()
			if err != nil {
				if err, isUnbound := err.(UnboundInputEvent); isUnbound {
					log.Println(err)
					continue
				}

				if stream.err != ErrStreamClosedByContext {
					stream.err = err
				}
				return
			}

			select {
			case output <- ev:
			case <-ctx.Done():
				stream.err = ErrStreamClosedByContext
				return
			}
		}
	}(output)

	return output
}

// An OutputEvent is used to send virtual input events using a uinput device.
type OutputEvent interface {
	OutputTo(*uinput.VKeyboard) error
}

type singleKeyPress int

func (key singleKeyPress) OutputTo(vk *uinput.VKeyboard) error {
	err := vk.SendKeyPress(int(key))
	if err != nil {
		return err
	}

	time.Sleep(50 * time.Millisecond)

	return vk.SendKeyRelease(int(key))
}

// A Device will transform InputEvents into output events.
type Device interface {
	ApplyEvent(ButtonEvent) OutputEvent
}

type chordDevice struct {
	inputConfig  ChordInputMapping
	outputConfig ChordOutputMapping

	state chordState
}

type chordState struct {
	// State of all chord keys
	keys Chord

	// Current chord being keyed
	build Chord

	// Chord that's being played
	trigger Chord
}

func (state chordState) keyDown(btn Chord) chordState {
	state.keys |= btn
	state.build |= state.keys
	state.trigger = 0
	return state
}

func (state chordState) keyUp(btn Chord) chordState {
	state.keys ^= btn
	state.trigger = state.build
	state.build = 0
	return state
}

func (dev *chordDevice) ApplyEvent(e ButtonEvent) OutputEvent {
	chordBtn := dev.inputConfig[e.Button()]
	if chordBtn == 0 {
		log.Println("unbound input button")
		return nil
	}

	switch e.State() {
	case ButtonDown:
		dev.state = dev.state.keyDown(chordBtn)
	case ButtonUp:
		dev.state = dev.state.keyUp(chordBtn)
	default:
		return nil
	}

	if dev.state.trigger == 0 {
		return nil
	}

	if key, isBound := dev.outputConfig[dev.state.trigger]; isBound {
		return singleKeyPress(key)
	}

	log.Println("unbound chord", dev.state.trigger)
	return nil
}

func EnableDevice(dev Device) ButtonEventProcess {
	return func(ctx context.Context, input <-chan ButtonEvent) <-chan OutputEvent {
		output := make(chan OutputEvent)

		go func(output chan<- OutputEvent) {
			defer close(output)

			for ev := range input {
				if ev := dev.ApplyEvent(ev); ev != nil {
					select {
					case output <- ev:
					case <-ctx.Done():
						return
					}
				}
			}

		}(output)

		return output
	}
}

// SendOutputEvents reads all OutputEvents from provided channel and
// applies/outputs them to the provided uinput device.
func SendOutputEvents(vk *uinput.VKeyboard, events <-chan OutputEvent) error {
	for e := range events {
		if e == nil {
			continue
		}

		if err := e.OutputTo(vk); err != nil {
			return err
		}
	}

	return nil
}

// Must is used to specify any error returned as a fatal error
// that cannot be recovered from.
func Must(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

// RunDeviceStream is used to create and input => device => output stream
// that is all linked together with a context. It will block until there is
// some is an unrecoverable error which will be returned.
func RunDeviceStream(ctx context.Context, input InputStream, dev Device, output uinput.VKeyboard) error {
	ctx, cancelCtx := context.WithCancel(ctx)
	defer cancelCtx()

	events := input.
		ReadEvents(ctx).
		MapIntoKeyEvents(ctx, EnableDevice(dev))

	return SendOutputEvents(&output, events)
}

func main() {
	// TODO: Provide flag to specify the evdev device used to produce chords
	// TODO: Enable using multiple evdev devices to power chord production
	// TODO: Provide flag to specify the uinput device file path
	// TODO: Provide flag for a config file path
	// TODO: Support configuration file

searchForInputDevice:
	log.Println("auto selecting chord input device")
	// Can trigger os.Exit()
	dev := autoSelectEvdevDevice()

	log.Println("input device found")
	log.Println(dev)

	log.Println("creating uinput virtual keyboard output device")
	vk := uinput.VKeyboard{Name: "Test Chordpad Device"}
	Must(vk.Create("/dev/uinput"))

	log.Println("linking evdev input device to uinput virtual keyboard")

	inputStream := InputStream{InputDevice: dev}
	err := RunDeviceStream(
		context.Background(),
		inputStream,
		&chordDevice{ChordInputMappingDefaults, ChordOutputMappingDefaults, chordState{}},
		vk)
	if err != nil {
		log.Println(err)
	}

	log.Println("closing uinput virtual keyboard")
	err = vk.Close()
	if err != nil {
		log.Println(err)
	}

	if inputStream.Err() != nil {
		log.Println(inputStream.Err())
	}

	goto searchForInputDevice
}
