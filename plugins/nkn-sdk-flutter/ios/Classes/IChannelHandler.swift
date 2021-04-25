protocol IChannelHandler {
    mutating func install(binaryMessenger: FlutterBinaryMessenger)
    mutating func uninstall()
}
