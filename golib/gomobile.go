package nkn

import (
	dnsresolver "github.com/nknorg/dns-resolver-go"
	ethresolver "github.com/nknorg/eth-resolver-go"
	"github.com/nknorg/nkn-sdk-go"
	"github.com/nknorg/nkngomobile"
	"github.com/nknorg/reedsolomon"
	"golang.org/x/mobile/bind"
)

var (
	_ = nkn.NewStringArray
	_ = dnsresolver.NewResolver
	_ = ethresolver.NewResolver
	_ = nkngomobile.NewStringArray
	_ = reedsolomon.New
	_ = bind.GenGo
)
