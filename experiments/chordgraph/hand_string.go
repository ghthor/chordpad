// Code generated by "stringer -type=Hand"; DO NOT EDIT.

package main

import "fmt"

const _Hand_name = "UnknownLeftRight"

var _Hand_index = [...]uint8{0, 7, 11, 16}

func (i Hand) String() string {
	if i >= Hand(len(_Hand_index)-1) {
		return fmt.Sprintf("Hand(%d)", i)
	}
	return _Hand_name[_Hand_index[i]:_Hand_index[i+1]]
}
