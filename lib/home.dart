import 'dart:async';
import 'dart:io' show Platform;

import 'package:bluetoothtest/entrylist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as plus;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class HomePage extends StatefulWidget {
  final bool start;

  const HomePage({this.start = true});

  @override
  _DiscoveryPage createState() => new _DiscoveryPage();
}

class _DiscoveryPage extends State<HomePage> {
  StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  plus.FlutterBluePlus flutterBlue = plus.FlutterBluePlus.instance;
  List<BluetoothDiscoveryResult> results =
      List<BluetoothDiscoveryResult>.empty(growable: true);
  List<plus.ScanResult> iosResults =
      List<plus.ScanResult>.empty(growable: true);
  bool isDiscovering = false;

  _DiscoveryPage();

  @override
  void initState() {
    super.initState();

    isDiscovering = widget.start;
    if (isDiscovering) {
      _startDiscovery();
    }
  }

  void _restartDiscovery() {
    setState(() {
      results.clear();
      isDiscovering = true;
    });

    _startDiscovery();
  }

  void _startDiscovery() {
    if (Platform.isAndroid) {
      _streamSubscription =
          FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
        print(r.device.name);
        setState(() {
          final existingIndex = results.indexWhere(
              (element) => element.device.address == r.device.address);
          if (existingIndex >= 0)
            results[existingIndex] = r;
          else
            results.add(r);
        });
      });

      _streamSubscription!.onDone(() {
        setState(() {
          isDiscovering = false;
        });
      });
    } else if (Platform.isIOS) {}
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isDiscovering
            ? const Text('Discovering devices')
            : const Text('Discovered devices'),
        actions: <Widget>[
          isDiscovering
              ? FittedBox(
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: _restartDiscovery,
                )
        ],
      ),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (BuildContext context, index) {
          BluetoothDiscoveryResult result = results[index];
          final device = result.device;
          final address = device.address;
          return BluetoothDeviceListEntry(
            device: device,
            rssi: result.rssi,
            onTap: () async {
              print('Connecting');
              BluetoothConnection connection =
                  await BluetoothConnection.toAddress(device.address);
              print('Connected to the device ${connection.isConnected}');
            },
            onLongPress: () async {
              try {
                bool bonded = false;
                if (device.isBonded) {
                  print('Unbonding from ${device.address}...');
                  await FlutterBluetoothSerial.instance
                      .removeDeviceBondWithAddress(address);
                  print('Unbonding from ${device.address} has succed');
                } else {
                  print('Bonding with ${device.address}...');
                  bonded = (await FlutterBluetoothSerial.instance
                      .bondDeviceAtAddress(address))!;
                  print(
                      'Bonding with ${device.address} has ${bonded ? 'succed' : 'failed'}.');
                }
                setState(() {
                  results[results.indexOf(result)] = BluetoothDiscoveryResult(
                      device: BluetoothDevice(
                        name: device.name ?? '',
                        address: address,
                        type: device.type,
                        bondState: bonded
                            ? BluetoothBondState.bonded
                            : BluetoothBondState.none,
                      ),
                      rssi: result.rssi);
                });
              } catch (ex) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Error occured while bonding'),
                      content: Text("${ex.toString()}"),
                      actions: <Widget>[
                        TextButton(
                          child: const Text("Close"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}
