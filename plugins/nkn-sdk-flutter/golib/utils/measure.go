package utils

import (
	"encoding/json"
	"github.com/nknorg/nkn-sdk-go"
	"github.com/nknorg/nkngomobile"
)

func MeasureSeedRPCServer(seedRpcList *nkngomobile.StringArray, timeout int32) (string, error) {
	res, err := nkn.MeasureSeedRPCServer(seedRpcList, timeout)
	if err != nil {
		return "[]", err
	}
	b, err := json.Marshal(res.Elems())
	if err != nil {
		return "[]", err
	}
	if b == nil {
		return "[]", err
	}
	return string(b), nil
}

func MeasureSeedRPCServerReturnStringArray(seedRpcList *nkngomobile.StringArray, timeout int32) (*nkngomobile.StringArray, error) {
	res, err := nkn.MeasureSeedRPCServer(seedRpcList, timeout)
	if err != nil {
		return nil, err
	}
	return nkngomobile.NewStringArray(res.Elems()...), nil
}
