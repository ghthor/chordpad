package main

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/ghthor/uinput"
	evdev "github.com/gvalkov/golang-evdev"
)

// A Chord is used to store a bitfield of button states. Each
// index in the the bitfield represents the on/off state of a
// button associated to an input device.
type Chord uint

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

// A ChordInputMapping contains a map of evdev produced input scan codes
// into a Chord value. This is used to configure the buttons from the evdev
// input device map into a chorded value.
type ChordInputMapping map[uint16]Chord

// A ChordOutputMapping will contain a map of chord values to the key
// code they trigger. This is used to configure what key a specific chord
// will output to the computer.
type ChordOutputMapping map[Chord]int

// ErrNoValidInputDevices is returned when no valid evdev input devices are found
var ErrNoValidInputDevices = errors.New("no valid evdev input devices to use for chording")

// autoSelectInput will select the first valid evdev device for use as a chording input source.
func autoSelectInput() (*evdev.InputDevice, error) {
	inputs, err := evdev.ListInputDevices("/dev/input/event*")
	if err != nil {
		return nil, err
	}

	if len(inputs) < 1 {
		return nil, ErrNoValidInputDevices
	}

	return inputs[0], nil
}

// InputEvents is a read only stream of evdev.InputEvent's. The
// stream allows for mapping the InputEvents into a stream of
// OutputEvents.
type InputEvents <-chan *evdev.InputEvent

// An InputEventTransformer is used to process of stream of
// evdev.InputEvents into the actual OutputEvents that can be
// sent to a virtual uinput device.
type InputEventTransformer func(context.Context, <-chan *evdev.InputEvent) <-chan OutputEvent

// MapIntoKeyEvents is used to process a stream of input events
// into a output of InputEvents that can be sent to a virtual input
// device.
func (stream InputEvents) MapIntoKeyEvents(ctx context.Context, transform InputEventTransformer) <-chan OutputEvent {
	return transform(ctx, stream)
}

// An InputStream wraps an evdev input device to provide
// the deferred error handling pattern. A Go Routine can be started
// that reads input events and sends them on a channel. If an error
// is encountered during reading, the error will be  stored in the
// structure, the channel will be closed and the go routine will exit.
type InputStream struct {
	*evdev.InputDevice
	err error
}

// Err returns any error that was encountered while reading events
// from the provided evdev.InputDevice.
func (stream InputStream) Err() error { return stream.err }

// ErrStreamClosedByContext is returned when a stream generator
// is closed by it's parent context being completed.
var ErrStreamClosedByContext = errors.New("input event stream context completed")

// ReadEvents is used to start a go routine that reads events
// from the evdev InputDevice sends them on the returned channel.
func (stream *InputStream) ReadEvents(ctx context.Context) InputEvents {
	stream.err = nil

	output := make(chan *evdev.InputEvent)

	go func() {
		<-ctx.Done()
		stream.err = ErrStreamClosedByContext
		stream.InputDevice.File.Close()
	}()

	go func(output chan<- *evdev.InputEvent) {
		defer close(output)

		for {
			ev, err := stream.InputDevice.ReadOne()
			if err != nil {
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
	ApplyEvent(*evdev.InputEvent) OutputEvent
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

func (dev *chordDevice) ApplyEvent(e *evdev.InputEvent) OutputEvent {
	var chordBtn Chord

	switch e.Type {
	default:
		return nil

	case evdev.EV_KEY:
	}

	ke := evdev.NewKeyEvent(e)
	chordBtn = dev.inputConfig[ke.Scancode]
	if chordBtn == 0 {
		log.Println("unbound input button")
		return nil
	}

	switch ke.State {
	case evdev.KeyDown:
		dev.state = dev.state.keyDown(chordBtn)
	case evdev.KeyUp:
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

// EnableDevice is used to turn a Device into an InputEventTransformer.
func EnableDevice(dev Device) InputEventTransformer {
	return func(ctx context.Context, input <-chan *evdev.InputEvent) <-chan OutputEvent {
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

func main() {
	// TODO: Provide flag to specify the evdev device used to produce chords
	// TODO: Enable using multiple evdev devices to power chord production
	// TODO: Provide flag to specify the uinput device file path
	// TODO: Provide flag for a config file path
	// TODO: Support configuration file

	log.Println("auto selecting chord input device")
	pad, err := autoSelectInput()
	if err != nil {
		log.Fatal(err)
	}

	log.Println("creating virtual keyboard output device")
	vk := uinput.VKeyboard{Name: "Test Chordpad Device"}
	err = vk.Create("/dev/uinput")
	if err != nil {
		log.Fatal(err)
	}

	defer vk.Close()

	ctx, cancel := context.WithCancel(context.Background())

	inputStream := InputStream{InputDevice: pad}
	chordDev := EnableDevice(&chordDevice{ChordInputMappingDefaults, ChordOutputMappingDefaults, chordState{}})
	keyEvents := inputStream.
		ReadEvents(ctx).
		MapIntoKeyEvents(ctx, chordDev)

	for e := range keyEvents {
		if e == nil {
			continue
		}

		if err := e.OutputTo(&vk); err != nil {
			log.Println(err)
			cancel()
			break
		}
	}

	if inputStream.Err() != nil {
		log.Fatal(inputStream.Err())
	}
}
