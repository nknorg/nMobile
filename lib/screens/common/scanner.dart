import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button_icon.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

const flash_on = "FLASH ON";
const flash_off = "FLASH OFF";
const front_camera = "FRONT CAMERA";
const back_camera = "BACK CAMERA";

class ScannerScreen extends BaseStateFulWidget {
  static const String routeName = '/scanner';

  ScannerScreen({Key? key}) : super(key: key);

  @override
  ScannerScreenState createState() => ScannerScreenState();
}

class ScannerScreenState extends BaseStateFulWidgetState<ScannerScreen> {
  var flashState = flash_on;
  var cameraState = front_camera;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void onRefreshArguments() {}

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid && mounted) {
      controller!.resumeCamera();
    } else if (Platform.isIOS && mounted) {
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  _isFlashOn(String current) {
    return flash_on == current;
  }

  _isBackCamera(String current) {
    return back_camera == current;
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    // FIXED:GG Android black screen
    if (Platform.isAndroid) {
      this.controller?.resumeCamera();
    }

    this.controller?.scannedDataStream.listen((Barcode scanData) {
      if (Navigator.of(this.context).canPop()) Navigator.of(this.context).pop(scanData.code);
      this.controller?.dispose();
    });
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
                  if (Navigator.of(this.context).canPop()) Navigator.pop(this.context);
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
