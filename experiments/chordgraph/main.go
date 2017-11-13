package main

import (
	"fmt"
	"log"
	"strings"

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

func main() {
	// Fetch the Device handles for the Elecom mice
	mice, err := getElecomMiceDevices()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(elecom)

	// TODO: Set LH/RH
	// TODO: Start up webui server
}
