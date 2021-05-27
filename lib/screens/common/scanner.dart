import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

const flash_on = "FLASH ON";
const flash_off = "FLASH OFF";
const front_camera = "FRONT CAMERA";
const back_camera = "BACK CAMERA";

class ScannerScreen extends StatefulWidget {
  static const String routeName = '/scanner';

  ScannerScreen({Key? key}) : super(key: key);

  @override
  ScannerScreenState createState() => ScannerScreenState();
}

class ScannerScreenState extends State<ScannerScreen> {
  var _data;
  var flashState = flash_on;
  var cameraState = front_camera;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void initState() {
    super.initState();
  }

  _isFlashOn(String current) {
    return flash_on == current;
  }

  _isBackCamera(String current) {
    return back_camera == current;
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((Barcode scanData) {
      Navigator.of(context).pop(scanData.code);
      controller.dispose();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: application.theme.backgroundColor5,
      body: Stack(
        children: <Widget>[
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: application.theme.lineColor,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
          Positioned(
            //            left: 20,
            top: 20,
            child: SafeArea(
              child: ButtonIcon(
                padding: const EdgeInsets.all(18),
                icon: Icon(
                  FontAwesomeIcons.arrowLeft,
                  size: 24,
                  color: application.theme.fontColor2,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: SafeArea(
              child: ButtonIcon(
                icon: Icon(
                  _isFlashOn(flashState) ? FontAwesomeIcons.lightbulb : FontAwesomeIcons.solidLightbulb,
                  size: 50,
                  color: application.theme.primaryColor,
                ),
                onPressed: () {
                  controller?.toggleFlash();
                  if (_isFlashOn(flashState)) {
                    setState(() {
                      flashState = flash_off;
                    });
                  } else {
                    setState(() {
                      flashState = flash_on;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
