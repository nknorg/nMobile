package nkngolib

import (
	"github.com/nknorg/nkn-sdk-go"
	"github.com/nknorg/nkngomobile"
	"github.com/nknorg/reedsolomon"
	"golang.org/x/mobile/bind"
)

var (
	_ = nkn.NewStringArray
	_ = nkngomobile.NewStringArray
	_ = reedsolomon.New
	_ = bind.GenGo
)
