package nkngolib

import (
	"context"
	"fmt"
	"github.com/nknorg/nkn-sdk-go"
	"github.com/nknorg/nkngomobile"
	"log"
	"net"
	"strings"
)

func MeasureSeedRPCServer(seedRPCList *nkngomobile.StringArray, timeout int32) (*nkngomobile.StringArray, error) {
	nodes, err := nkn.MeasureSeedRPCServer(seedRPCList, timeout, nil)
	if err != nil {
		log.Println(err)
		dialContext := func(ctx context.Context, network, addr string) (net.Conn, error) {
			d := &net.Dialer{}
			host, port, err := net.SplitHostPort(addr)

			var conn net.Conn
			if net.ParseIP(host) != nil && strings.Contains(host, ".") {
				log.Printf("%s:%s => %s", host, port, fmt.Sprintf("%s.ipv4.nknlabs.io:%s", strings.ReplaceAll(host, ".", "-"), port))
				conn, err = d.DialContext(ctx, network, fmt.Sprintf("%s.ipv4.nknlabs.io:%s", strings.ReplaceAll(host, ".", "-"), port))
			} else {
				conn, err = d.DialContext(ctx, network, addr)
			}

			if err != nil {
				return nil, err
			}
			return conn, nil
		}
		nodes, err = nkn.MeasureSeedRPCServer(seedRPCList, timeout, dialContext)
		if err != nil {
			return nil, err
		}
		return nodes, nil
	}
	return nodes, nil
}
