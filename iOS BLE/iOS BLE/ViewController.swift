//
//  ViewController.swift
//  iOS BLE
//
//  Created by shaqattack13 on 2/14/21.
//

import UIKit
import CoreBluetooth
import Charts

// Initialize global variables
var blePeripheral: CBPeripheral?
var txCharacteristic: CBCharacteristic?
var rxCharacteristic: CBCharacteristic?

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // Variable Initializations
    var centralManager: CBCentralManager!
    var data = NSMutableData()
    var rssiList = [NSNumber]()
    var peripheralList: [CBPeripheral] = []
    var characteristicList = [String: CBCharacteristic]()
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    
    let BLE_Service_UUID = CBUUID.init(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    let BLE_Characteristic_uuid_Rx = CBUUID.init(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    let BLE_Characteristic_uuid_Tx  = CBUUID.init(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    
    var receivedData = [Int]()
    var showGraphIsOn = true
    
    @IBOutlet weak var showGraphLbl: UILabel!
    @IBOutlet weak var connectStatusLbl: UILabel!
    @IBOutlet weak var chartBox: LineChartView!
    
    
  
    
    
    
    
    
    
    // This function is called before the storyboard view is loaded onto the screen.
    // Runs only once.
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the label to say "Disconnected" and make the text red
        connectStatusLbl.text = "Disconnected"
        connectStatusLbl.textColor = UIColor.red
        // Initialize CoreBluetooth Central Manager object which will be necessary
        // to use CoreBlutooth functions
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // This function is called right after the view is loaded onto the screen
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Reset the peripheral connection with the app
        disconnectFromDevice()
        print("View Cleared")
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Stop Scanning")
        centralManager?.stopScan()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // We will just handle it the easy way here: if Bluetooth is on, proceed...start scan!
            print("Bluetooth Enabled")
            startScan()
            
        } else {
            //If Bluetooth is off, display a UI alert message saying "Bluetooth is not enable" and "Make sure that your bluetooth is turned on"
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")
            
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertController.Style.alert)
            let action = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    func startScan() {
        peripheralList = []
        print("Now Scanning...")
        self.timer.invalidate()
        print("Service ID Search: \(BLE_Service_UUID)")
        //[BLEService_UUID]
        //[Particle.BLEService_UUID]
        centralManager?.scanForPeripherals(withServices: [BLE_Service_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) {_ in
            self.cancelScan()
        }
    }
    
    func cancelScan() {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripheralList.count)")
    }
    
    func disconnectFromDevice () {
        // We have a connection to the device but we are not subscribed to the Transfer Characteristic for some reason.
        // Therefore, we will just disconnect from the peripheral
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
    }

    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral:
    CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        blePeripheral = peripheral
        self.peripheralList.append(peripheral)
        self.rssiList.append(RSSI)
        peripheral.delegate = self

        if blePeripheral != nil {
            // Connect to the device
            centralManager?.connect(blePeripheral!, options: nil)
        }

        blePeripheral = peripheral
        self.peripheralList.append(peripheral)
        self.rssiList.append(RSSI)
        peripheral.delegate = self

        if blePeripheral == nil {
           print("Found new pheripheral devices with services")
           print("Peripheral name: \(String(describing: peripheral.name))")
           print("**********************************")
           print ("Advertisement Data : \(advertisementData)")
        }
        
    }
    
    func restoreCentralManager() {
        //Restores Central Manager delegate if something went wrong
        centralManager?.delegate = self
    }
    
    //Peripheral Connections: Connecting, Connected, Disconnected

    /*
     Invoked when a connection is successfully created with a peripheral.
     This method is invoked when a call to connect(_:options:) is successful. You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    //-Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(String(describing: blePeripheral))")
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        cancelScan()
        
        //Erase data that we might have
        data.length = 0
        
        //Discovery callback
        peripheral.delegate = self
        //Only look for services that matches transmit uuid
        //[BLEService_UUID]
        //[Particle.BLEService_UUID]
        peripheral.discoverServices([BLE_Service_UUID])
    }
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        connectStatusLbl.text = "Disconnected"
        connectStatusLbl.textColor = UIColor.red
    }

    /*
     Invoked when you discover the peripheral’s available services.
     This method is invoked when your app calls the discoverServices(_:) method. If the services of the peripheral are successfully discovered, you can access them through the peripheral’s services property. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        print("Discovered Services: \(services)")

        for service in services {
            print("Service.uuid = \(service.uuid)")
            if service.uuid == BLE_Service_UUID {
               print("Service found")
                connectStatusLbl.text = "Connected!"
                connectStatusLbl.textColor = UIColor.blue
            }

            //[BLEService_UUID]
            //[Particle.BLE_Service_uuid]
            peripheral.discoverCharacteristics(nil, for: service)
            // bleService = service
        }
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     This method is invoked when your app calls the discoverCharacteristics(_:for:) method. If the characteristics of the specified service are successfully discovered, you can access them through the service's characteristics property. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("*******************************************************")
        // error was nil
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            //print(characteristic.uuid)
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    // MARK: - Getting Values From Characteristic
    /** After you've found a characteristic of a service that you are interested in, you can read the characteristic's value by calling the peripheral "readValueForCharacteristic" method within the "didDiscoverCharacteristicsFor service" delegate.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic == rxCharacteristic,
            let characteristicValue = characteristic.value,
            let receivedString = NSString(data: characteristicValue,
                                       encoding: String.Encoding.utf8.rawValue)
            else { return }
        
        print(receivedString)
        ///*
        let number:Int = Int(receivedString as String)!
        receivedData.append(number)
        if (receivedData.count > 100) {
            receivedData.removeFirst(receivedData.count-100)
        }
        if (showGraphIsOn && receivedData.count > 0) {
            updateGraph(dataDisplaying: receivedData)
        }
        //*/
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: self)
    }
    
    // used to send msg? nope, used for some error thing, got
    // "<_UISystemGestureGateGestureRecognizer: 0x10540a7b0>: Gesture: Failed to receive system gesture state notification before next touch"
    // error when commenting this out
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }


    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        guard let descriptors = characteristic.descriptors else { return }
            
        descriptors.forEach { descript in
            print("function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
            print("Rx Value \(String(describing: rxCharacteristic?.value))")
            print("Tx Value \(String(describing: txCharacteristic?.value))")
        }
    }
  
        // for writing/send msg?
//    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
//        guard error == nil else {
//            print("Error discovering services: error")
//            return
//        }
//        print("Succeeded!")
//    }
    
    
//    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
//        print("*******************************************************")
//
//        if (error != nil) {
//            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
//
//        } else {
//            print("Characteristic's value subscribed")
//        }
//
//        if (characteristic.isNotifying) {
//            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
//        }
//    }
    
    func updateGraph(dataDisplaying: [Int]) {
        
        var lineChartEntry  = [ChartDataEntry]() //this is the Array that will eventually be displayed on the graph.
        //here is the for loop
        for i in 0..<dataDisplaying.count {
            let value = ChartDataEntry(x: Double(i), y: Double(dataDisplaying[i])) // here we set the X and Y status in a data chart entry

            lineChartEntry.append(value) // here we add it to the data set
        }

        let line1 = LineChartDataSet(entries: lineChartEntry, label: "PPG Data") //Here we convert lineChartEntry to a LineChartDataSet
        
        line1.drawCirclesEnabled = false

        line1.colors = [NSUIColor.blue] //Sets the colour to blue

        let lineData = LineChartData(dataSet: line1) //This is the object that will be added to the chart

        //data.addDataSet(line1) //Adds the line to the dataSet
        
        chartBox.data = lineData //finally - it adds the chart data to the chart and causes an update

        chartBox.chartDescription.text = "Retrieving Data..." // Here we set the description for the graph
    }
    
    func clearGraph() {
        let nullGraph = [Int]()
        updateGraph(dataDisplaying: nullGraph)
    }
    
}






//// Come back to this later
//@IBAction func refreshBtn(_ sender: Any) {
//    receivedData.removeAll()
//    clearGraph()
//    centralManager?.cancelPeripheralConnection(blePeripheral!)
//    usleep(1000000)
//    startScan()
//}
//
//@IBAction func showGraphBtn(_ sender: Any) {
//    if (showGraphIsOn) {
//        clearGraph()
//        showGraphIsOn = false
//    }
//    else {
//        showGraphIsOn = true
//    }
//}
