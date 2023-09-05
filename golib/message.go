package nkngolib

import (
	"github.com/nknorg/nkn-sdk-go"
)

func Reply(c *nkn.MultiClient, msg *nkn.Message, data string, encrypted bool, maxHoldingSeconds int32) error {
	payload, err := nkn.NewReplyPayload(data, msg.MessageID)

	if err != nil {
		return err
	}
	if _, err := c.SendPayload(nkn.NewStringArray(msg.Src), payload, &nkn.MessageConfig{Unencrypted: !encrypted, MaxHoldingSeconds: maxHoldingSeconds}); err != nil {
		return err
	}
	return nil
}
