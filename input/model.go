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

func KeysDown(m Model, keys Chord) Model {
	m.Keys |= keys
	m.Build |= m.Keys
	m.Trigger = 0
	return m
}

func KeysUp(m Model, keys Chord) Model {
	m.Keys ^= keys
	m.Trigger = m.Build
	m.Build = 0
	return m
}
