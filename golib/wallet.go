package nkngolib

import (
	"github.com/nknorg/nkn/v2/common"
	"github.com/nknorg/nkn/v2/program"
)

func ProgramHashToAddr(hash []byte) (string, error) {
	programHash, err := common.ToCodeHash(hash)
	if err != nil {
		return "", err
	}

	return programHash.ToAddress()
}

func PubKeyToProgramHash(pubKey []byte) ([]byte, error) {
	programHash, err := program.CreateProgramHash(pubKey)
	if err != nil {
		return nil, err
	}
	return programHash.ToArray(), nil
}
