package input

import (
	"context"
	"io"
)

// A Device is the source for Model changes. Implementations of
// Device should determine how the buttons or other inputs map
// to changes in the Model that change the chord being keyed or
// when to a chord should be played.
type Device interface {
	Update(Model) (Model, error)
	io.Closer
}

// A Source is used to take a Device and produce a non repeating
// channel of Model values from the Devices input events.
type Source struct {
	Device
	Err error
}

// FlatMapModelChanges is used to read and apply input events and
// produce a channel of Model values that will never repeat.
func (dev *Source) FlatMapModelChanges(ctx context.Context) <-chan Model {
	model := Model{}
	output := make(chan Model)

	go func(output chan<- Model) {
		defer close(output)
		for {
			nextModel, err := dev.Update(model)
			if err != nil {
				dev.Err = err
				return
			}

			if nextModel == model {
				continue
			}

			model = nextModel
			select {
			case output <- model:
			case <-ctx.Done():
				return
			}
		}
	}(output)

	return output
}
