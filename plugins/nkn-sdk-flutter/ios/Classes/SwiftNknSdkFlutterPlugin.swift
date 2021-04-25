import Flutter
import UIKit

public class SwiftNknSdkFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    Common().install(binaryMessenger: registrar.messenger())
    Wallet().install(binaryMessenger: registrar.messenger())
    Client().install(binaryMessenger: registrar.messenger())
  }
}
