extension Data {
    init?(hex: String) {
        let length = hex.count / 2
        var data = Data(capacity: length)
        for i in 0 ..< length {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    var hexEncode: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}
