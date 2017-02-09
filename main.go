package main

import (
	"context"
	"log"
	"time"

	"github.com/ghthor/chordpad/input"
	"github.com/ghthor/uinput"
)

// A ChordOutputMapping will contain a map of chord values to the key
// code they trigger. This is used to configure what key a specific chord
// will output to the computer.
type ChordOutputMapping map[input.Chord]int

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

func send(ctx context.Context, device *input.Source, output uinput.VKeyboard) error {
	ctx, cancelCtx := context.WithCancel(ctx)
	defer cancelCtx()
	return apply(device.FlatMapModelChanges(ctx), &output)
}

func apply(changes <-chan input.Model, device *uinput.VKeyboard) error {
	for model := range changes {
		if model.Trigger == 0 {
			continue
		}

		if key, isBound := ChordOutputMappingDefaults[model.Trigger]; isBound {
			if err := singleKeyPress(key).OutputTo(device); err != nil {
				return err
			}

			continue
		}

		log.Println("unbound chord", model.Trigger)
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

	source := input.Source{dev, nil}
	err := send(context.Background(), &source, vk)
	if err != nil {
		log.Println(err)
	}

	log.Println("closing uinput virtual keyboard")
	err = vk.Close()
	if err != nil {
		log.Println(err)
	}

	if source.Err != nil {
		log.Println(source.Err)
	}

	goto searchForInputDevice
}
