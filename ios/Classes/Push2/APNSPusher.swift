//
//  APNSPusher.swift
//  Runner
//
//  Created by 蒋治国 on 2021/10/31.
//

import Foundation
import Sentry

let pushTopic = "com.xxx.xxx"
let p12FileName = "fileName"
let p12FilePasswordd = "password"


var connection: Connection? = nil

public class APNSPusher {
    
    static func connect() -> Connection? {
        var _connection: Connection?
        do {
            _connection = try Connection(p12FileName: p12FileName, passPhrase: p12FilePasswordd)
        } catch {
            print("APNSPusher - connect faile")
            return nil
        }
        print("APNSPusher - connect success")
        return _connection
    }
    
    static func push(uuid: String, deviceToken: String, payload: String) {
        if(connection == nil) {
            connection = connect();
        }
        
        let header = APNsRequest.Header(id: uuid, priority: APNsRequest.Header.Priority.p10, topic: pushTopic)
        let payload = APNsPayload(str: payload)
        let request = APNsRequest(port: APNsPort.p2197, server: APNsServer.production, deviceToken: deviceToken, header: header, payload: payload)
        
        connection?.send(request: request) {
            switch $0 {
            case .success:
                print("APNSPusher - pushed success")
            case .failure(let errorCode, let message):
                print("APNSPusher - pushed Failed - \(errorCode), \(uuid), \(deviceToken), \(message)")
                if (!message.contains("-1001") && !message.contains("-1005") && !message.contains("-1017")) {
                    SentrySDK.capture(error: NSError(domain: "\(uuid), \(deviceToken), \(message)", code: errorCode))
                }
            }
        }
    }
}
