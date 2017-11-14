package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	evdev "github.com/ghthor/golang-evdev"
)

func getElecomMiceDevices() ([]*evdev.InputDevice, error) {
	devices, err := evdev.ListInputDevices("/dev/input/event*")
	if err != nil {
		return nil, err
	}

	// NOTE: For Debugging Device names
	// for _, d := range devices {
	// 	fmt.Println(d)
	// }

	// Filter to Elecom mice
	mice := make([]*evdev.InputDevice, 0, 2)
	for _, d := range devices {
		if strings.Contains("ELECOM ELECOM TrackBall Mouse", d.Name) {
			mice = append(mice, d)
		}
	}

	return mice, nil
}

//go:generate stringer -type=Hand
type Hand uint

const (
	Unknown Hand = iota
	Left
	Right
)

type Event struct {
	Hand
	*evdev.InputEvent
}

func (event Event) String() string {
	return fmt.Sprintf("{%s\t = %s}", event.Hand, event.InputEvent.String())
}

type Device struct {
	Hand
	*evdev.InputDevice
	Err error
}

func (dev *Device) ReadEvents(ctx context.Context) <-chan Event {
	hand := dev.Hand
	output := make(chan Event)

	go func(output chan<- Event) {
		defer close(output)

		for {
			e, err := dev.ReadOne()
			if err != nil {
				dev.Err = err
				return
			}

			select {
			// NOTE: Careful with race conditions if Hand is changed externally
			case output <- Event{hand, e}:
			case <-ctx.Done():
				return
			}
		}
	}(output)

	return output
}

type DualWieldElecomMouse struct {
	LH, RH *Device
}

// TODO: Change slice into array
func NewDualWieldElecomMouse(mice []*evdev.InputDevice) (DualWieldElecomMouse, error) {
	var LH, RH *Device

	// TOTAL HACK...
	if mice[0].Product == 0x00fd {
		LH = &Device{Left, mice[0], nil}
		RH = &Device{Right, mice[1], nil}
	} else {
		// } else if mice[0].Product == 0x00fc {
		LH = &Device{Left, mice[1], nil}
		RH = &Device{Right, mice[0], nil}
	}

	return DualWieldElecomMouse{LH, RH}, nil
}

func (devices DualWieldElecomMouse) ReadEvents(ctx context.Context) <-chan Event {
	output := make(chan Event)

	LH := devices.LH.ReadEvents(ctx)
	RH := devices.RH.ReadEvents(ctx)

	go func(output chan<- Event) {
		defer close(output)
		for {
			if devices.LH.Err != nil {
				return
			}

			if devices.RH.Err != nil {
				return
			}

			select {
			case e := <-LH:
				output <- e
			case e := <-RH:
				output <- e
			case <-ctx.Done():
				return
			}
		}
	}(output)

	return output
}

func main() {
	// Fetch the Device handles for the Elecom mice
	mice, err := getElecomMiceDevices()
	if err != nil {
		log.Fatal(err)
	}

	// FIXME: Disable OS default handling of devices
	// FIXME: Fix Kernal module for third button

	// Setup LH/RH device
	device, err := NewDualWieldElecomMouse(mice)
	if err != nil {
		log.Fatal(err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		<-time.After(10 * time.Second)
		cancel()
	}()

	// Start a Fan-In channel for reading events
	events := device.ReadEvents(ctx)

	for {
		select {
		case e := <-events:
			log.Println(e)
		case <-ctx.Done():
			return
		}
	}

	// TODO: Start up webui server
}
