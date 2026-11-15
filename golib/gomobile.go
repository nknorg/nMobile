package nkngolib

import (
	"nkngolib/search"

	dnsresolver "github.com/nknorg/dns-resolver-go"
	ethresolver "github.com/nknorg/eth-resolver-go"
	"github.com/nknorg/nkn-sdk-go"
	"github.com/nknorg/nkngomobile"
	"github.com/nknorg/reedsolomon"
	"github.com/pion/webrtc/v4"
	"golang.org/x/mobile/bind"
)

var (
	_ = nkn.NewStringArray
	_ = dnsresolver.NewResolver
	_ = ethresolver.NewResolver
	_ = nkngomobile.NewStringArray
	_ = reedsolomon.New
	_ = webrtc.NewAPI
	_ = bind.GenGo
	_ = search.NewSearchClient
)
