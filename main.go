package main

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/ghthor/uinput"
	evdev "github.com/gvalkov/golang-evdev"
)

type Chord uint

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
func (s InputStream) Err() error { return s.err }

var ErrStreamClosedByContext = errors.New("input event stream context completed")

// ReadEvents is used to start a go routine that reads events
// from the evdev InputDevice sends them on the returned channel.
func (stream *InputStream) ReadEvents(ctx context.Context) <-chan *evdev.InputEvent {
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

// An InputEventTransformer is used to process of stream of
// evdev.InputEvents into the actual InputEvents that will sent
// to a virtual input device.
type InputEventTransformer func(context.Context, <-chan *evdev.InputEvent) <-chan int

// ChordQuick allows you to hold keys down in between chord presses.
// A key event is output when a key is released and a chord has
// been played. (TODO explain the mechanics better)
func ChordQuick(inputConfig ChordInputMapping, outputConfig ChordOutputMapping) InputEventTransformer {
	return func(ctx context.Context, input <-chan *evdev.InputEvent) <-chan int {
		output := make(chan int)

		go func(output chan<- int) {
			defer close(output)

			// Stores current state of each key attached to chording
			var keys Chord

			// Stores the current chord being built that is unsent
			var chord Chord

			for ev := range input {
				switch ev.Type {
				case evdev.EV_KEY:
					ke := evdev.NewKeyEvent(ev)

					switch ke.State {
					case evdev.KeyDown:
						// log.Printf("%s %d (0x%x) KeyDown\n", evdev.BTN[int(ke.Scancode)], ke.Scancode, ke.Scancode)
						keys |= inputConfig[ke.Scancode]
						chord |= keys

					case evdev.KeyUp:
						// log.Printf("%s %d (0x%x) KeyUp\n", evdev.BTN[int(ke.Scancode)], ke.Scancode, ke.Scancode)
						btn := inputConfig[ke.Scancode]
						keys ^= btn

						if chord == 0 {
							continue
						}

						if key, isBound := outputConfig[chord]; isBound {
							select {
							case output <- key:
							case <-ctx.Done():
								return
							}
						} else {
							log.Println("unbound chord", chord)
						}

						chord = 0

					default:
					}

				default:
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
	inputEvents := inputStream.ReadEvents(ctx)
	keyEvents := ChordQuick(ChordInputMappingDefaults, ChordOutputMappingDefaults)(ctx, inputEvents)

	for key := range keyEvents {
		if key == 0 {
			continue
		}

		err := vk.SendKeyPress(key)
		if err != nil {
			cancel()
			break
		}

		time.Sleep(50 * time.Millisecond)

		err = vk.SendKeyRelease(key)
		if err != nil {
			cancel()
			break
		}
	}

	if inputStream.Err() != nil {
		log.Fatal(inputStream.Err())
	}
}
