package input

// A Chord is used to store a bitfield of button states. Each
// index in the the bitfield represents the on/off state of a
// button associated to an input device.
type Chord uint32

type Model struct {
	// State of all chord keys
	Keys Chord

	// Current chord being keyed
	Build Chord

	// Chord that's being played
	Trigger Chord
}

type ModelChanges <-chan Model
