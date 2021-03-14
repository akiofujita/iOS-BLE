//
//  ViewController.swift
//  iOS BLE
//
//  Created by shaqattack13 on 2/14/21.
//

// Import necessary modules
import UIKit
import Foundation
import CoreBluetooth
import Charts

// Initialize global variables
var curPeripheral: CBPeripheral?
var txCharacteristic: CBCharacteristic?
var rxCharacteristic: CBCharacteristic?

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // Variable Initializations
    var centralManager: CBCentralManager!
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
    
    @IBAction func refreshBtn(_ sender: Any) {
    }
    
    @IBAction func showGraphBtn(_ sender: Any) {
    }
  
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
        if curPeripheral != nil {
            centralManager?.cancelPeripheralConnection(curPeripheral!)
        }
        print("View Cleared")
    }
    
    // This function is called right before view disappears from screen
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Stop Scanning")
        
        // Central Manager object stops the scanning for peripherals
        centralManager?.stopScan()
    }

    // Called when manager's state is changed
    // Required method for setting up centralManager object
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // If manager's state is "poweredOn", that means Bluetooth has been enabled
        // in the app. We can begin scanning for peripherals
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth Enabled")
            startScan()
        }
        
        // Else, Bluetooth has NOT been enabled, so we display an alert message to the screen
        // saying that Bluetooth needs to be enabled to use the app
        else {
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")

            let alertVC = UIAlertController(title: "Bluetooth is not enabled",
                                            message: "Make sure that your bluetooth is turned on",
                                            preferredStyle: UIAlertController.Style.alert)
            
            let action = UIAlertAction(title: "ok",
                                       style: UIAlertAction.Style.default,
                                       handler: { (action: UIAlertAction) -> Void in
                                                self.dismiss(animated: true, completion: nil)
                                                })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    // Start scanning for peripherals
    func startScan() {
        print("Now Scanning...")
        print("Service ID Search: \(BLE_Service_UUID)")
        
        // Make an empty list of peripherals that were found
        peripheralList = []
        
        // Stop the timer
        self.timer.invalidate()
        
        // Call method in centralManager class that actually begins the scanning.
        // We are targeting services that have the same UUID value as the BLE_Service_UUID variable.
        // Use a timer to wait 10 seconds before calling cancelScan().
        centralManager?.scanForPeripherals(withServices: [BLE_Service_UUID],
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) {_ in
            self.cancelScan()
        }
    }
    
    // Cancel scanning for peripheral
    func cancelScan() {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripheralList.count)")
    }

    // Called when a peripheral is found.
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        // The peripheral that was just found is stored in a variable and
        // is added to a list of peripherals. Its rssi value is also added to a list
        curPeripheral = peripheral
        self.peripheralList.append(peripheral)
        self.rssiList.append(RSSI)
        peripheral.delegate = self

        // Connect to the peripheral if it exists / has services
        if curPeripheral != nil {
            centralManager?.connect(curPeripheral!, options: nil)
        }
    }
    
    // Restore the Central Manager delegate if something goes wrong
    func restoreCentralManager() {
        centralManager?.delegate = self
    }

    // Called when app successfully connects with the peripheral
    // Use this method to set up the peripheral's delegate and discover its services
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("-------------------------------------------------------")
        print("Connection complete")
        print("Peripheral info: \(String(describing: curPeripheral))")
        
        // Stop scanning because we found the peripheral we want
        cancelScan()
        
        // Set up peripheral's delegate
        peripheral.delegate = self
        
        // Only look for services that match our specified UUID
        peripheral.discoverServices([BLE_Service_UUID])
    }
    
    // Called when the central manager fails to connect to a peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        // Print error message to console for debugging purposes
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }
    
    // Called when the central manager disconnects from the peripheral
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        connectStatusLbl.text = "Disconnected"
        connectStatusLbl.textColor = UIColor.red
    }
    
    // Called when the correct peripheral's services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("-------------------------------------------------------")
        
        // Check for any errors in discovery
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        // Store the discovered services in a variable. If no services are there, return
        guard let services = peripheral.services else {
            return
        }
        
        // Print to console for debugging purposes
        print("Discovered Services: \(services)")

        // For every service found...
        for service in services {
            
            // If service's UUID matches with our specified one...
            if service.uuid == BLE_Service_UUID {
                print("Service found")
                connectStatusLbl.text = "Connected!"
                connectStatusLbl.textColor = UIColor.blue
                
                // Search for the characteristics of the service
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            
        }
    }
    
    // Called when the characteristics we specified are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("-------------------------------------------------------")
        
        // Check if there was an error
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        // Store the discovered characteristics in a variable. If no characteristics, then return
        guard let characteristics = service.characteristics else {
            return
        }
        
        // Print to console for debugging purposes
        print("Found \(characteristics.count) characteristics!")
        
        // For every characteristic found...
        for characteristic in characteristics {
            // If characteritstic's UUID matches with our specified one for Rx...
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                // Subscribe to the this particular characteristic
                // This will also call didUpdateNotificationStateForCharacteristic
                // method automatically
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            
            // If characteritstic's UUID matches with our specified one for Tx...
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            
            // Find descriptors for each characteristic
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")

        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")

        } else {
            print("Characteristic's value subscribed")
        }

        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    }
    
    // Called when peripheral.readValue(for: characteristic) is called
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        // If characteristic is correct, read its value and save it to a string.
        // Else, return
        guard characteristic == rxCharacteristic,
        let characteristicValue = characteristic.value,
        let receivedString = NSString(data: characteristicValue,
                                      encoding: String.Encoding.utf8.rawValue)
        else { return }
        
        for i in 0..<receivedString.length {
            // Print for debugging purposes
            print(receivedString.character(at: i))
            let number:Int = Int(receivedString.character(at: i))
            receivedData.append(number)
        }
        
        if (receivedData.count > 100) {
            receivedData.removeFirst(receivedData.count-100)
        }
        if (showGraphIsOn && receivedData.count > 0) {
            displayGraph(dataDisplaying: receivedData)
        }
        
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: self)
    }
    
    // Called when app wants to send a message to peripheral
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }

    // Called when descriptors for a characteristic are found
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        // Print for debugging purposes
        print("*******************************************************")
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        
        // Store descriptors in a variable. Return if nonexistent.
        guard let descriptors = characteristic.descriptors else { return }
            
        // For every descriptor, print its description for debugging purposes
        descriptors.forEach { descript in
            print("function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
            print("Rx Value \(String(describing: rxCharacteristic?.value))")
            print("Tx Value \(String(describing: txCharacteristic?.value))")
        }
    }
    
    // Graph the dataset to storyboard
    func displayGraph(dataDisplaying: [Int]) {
        
        // Array that will eventually be displayed on the graph.
        var lineChartEntry  = [ChartDataEntry]()
        
        // For every element in given dataset
        // Set the X and Y status in a data chart entry
        // and add to the entry object
        for i in 0..<dataDisplaying.count {
            let value = ChartDataEntry(x: Double(i), y: Double(dataDisplaying[i]))
            lineChartEntry.append(value)
        }

        // Convert lineChartEntry to a LineChartDataSet
        let line1 = LineChartDataSet(entries: lineChartEntry, label: "PPG Data")
        
        // Customize graph settings to your liking
        line1.drawCirclesEnabled = false
        line1.colors = [NSUIColor.blue]

        // Make object that will be added to the chart
        // and set it to the variable in the Storyboard
        let lineData = LineChartData(dataSet: line1)
        
        //chartBox.dragEnabled = true
        chartBox.setScaleEnabled(true)
        chartBox.pinchZoomEnabled = true
        
        chartBox.data = lineData

        // Settings for the chartBox
        chartBox.chartDescription.text = "Retrieving Data..."
    }
    
    // Clear the graph by displaying a dataset with no elements
    func clearGraph() {
        let nullGraph = [Int]()
        displayGraph(dataDisplaying: nullGraph)
    }
}

// for writing/send msg?



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




//// Come back to this later
//@IBAction func refreshBtn(_ sender: Any) {
//    receivedData.removeAll()
//    clearGraph()
//    if (curPeripheral != nil) {
//        centralManager?.cancelPeripheralConnection(curPeripheral!)
//    }
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

/*
let number:Int = Int(receivedString as String)!
receivedData.append(number)
if (receivedData.count > 100) {
    receivedData.removeFirst(receivedData.count-100)
}
if (showGraphIsOn && receivedData.count > 0) {
    updateGraph(dataDisplaying: receivedData)
}
*/



//
//View Cleared
//Bluetooth Enabled
//Now Scanning...
//Service ID Search: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 50
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = (null), state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//Disconnected
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//Disconnected
//Disconnected
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//Disconnected
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//Scan Stopped
//Number of Peripherals Found: 50
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x2835843c0, identifier = 8997ABAD-B53E-5DCF-AA96-EC897E781028, name = iPad, state = connected>)
//Scan Stopped
//Number of Peripherals Found: 50
//Disconnected



//View Cleared
//Bluetooth Enabled
//Now Scanning...
//Service ID Search: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
//Peripheral info: <CBPeripheral: 0x281518c80, identifier = 3CB209EB-2856-C821-909E-62720199C5DD, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x281519220, identifier = C4CB89F6-FEDB-4EDB-9E47-0D872331CC70, name = (null), state = connecting>
///Peripheral info: <CBPeripheral: 0x281519040, identifier = 302B7541-2981-5053-7EDC-5FF6BA1C4C95, name = iPhone, state = connecting>
//Peripheral info: <CBPeripheral: 0x28150c1e0, identifier = 3D079A6A-5C63-1EBC-9F59-67696DB1E69A, name = iPad, state = connecting>
//Peripheral info: <CBPeripheral: 0x281514320, identifier = E5155DBF-8A5A-BFF8-2E2C-004B7484AB62, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x281510140, identifier = 5890FD45-61E7-F9F7-079E-23021B34ADBF, name = iPhone, state = connecting>
//Peripheral info: <CBPeripheral: 0x281510280, identifier = 0E32C6C6-8B4C-90B9-D3F1-52F65FB87186, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x2815103c0, identifier = 2B128AE5-504B-FD5D-26E7-BFE3FA3F346B, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x2815080a0, identifier = B202BAFC-70D9-5A8F-8F10-CB6C44F17634, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x281514500, identifier = 3D4A2064-C6B7-BEEB-5CA3-AB764408114E, name = mjis3080mac1, state = connecting>
//Peripheral info: <CBPeripheral: 0x281510500, identifier = ED09D73B-EB89-F45D-D6D5-3D52EC6F1499, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x2815081e0, identifier = D9409BF5-966A-0EE9-60CA-A60A781AE36E, name = iPad, state = connecting>
//Peripheral info: <CBPeripheral: 0x281510640, identifier = 71CFB63F-1D2B-527B-6FE5-1712AEE2AD63, name = iPhone, state = connecting>
//Peripheral info: <CBPeripheral: 0x2815145a0, identifier = 62AA1E0C-A8A1-142F-E0FF-8911C01ED811, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x2815146e0, identifier = F089A709-2057-5881-89A4-4B302579DC03, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x28150c280, identifier = 2A8014CD-6AD4-84BC-2516-EBD4A01B0B3C, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x281514820, identifier = 66205E19-9870-4AE0-966D-6D89349CF985, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x281514960, identifier = A5CC9876-2042-2842-A59A-2CFB5F28A991, name = M479fdw Color LJ, state = connecting>
//Peripheral info: <CBPeripheral: 0x28150c3c0, identifier = C8F904EE-FB4D-33C1-C2F3-D27DCC56C726, name = (null), state = connecting>
//Peripheral info: <CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//Disconnected
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//Disconnected
//Disconnected
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x28150c500, identifier = 2A711567-4C88-553F-FF07-BDA3071FF8B3, name = (null), state = connected>)
//Scan Stopped
//Number of Peripherals Found: 40
//



//View Cleared
//Bluetooth Enabled
//Now Scanning...
//Service ID Search: 302B7541-2981-5053-7EDC-5FF6BA1C4C95
//5BA88F63-6693-8BEE-A58D-D1E43C32F4D1, name = (null), state = connecting>
//3D4A2064-C6B7-BEEB-5CA3-AB764408114E, name = mjis3080mac1, state = connecting>
//B69618B3-B341-FD72-DD37-3F5808B4CBDF, name = (null), state = connecting>
//2A711567-4C88-553F-FF07-BDA3071FF8B3, name = iPad, state = connecting>
//F14BBBC4-BABA-A4A1-2ADE-1646DCBD5D0B, name = (null), state = connecting>
//7C796E18-6FA3-4E0E-A6EA-CE903A4398CB, name = (null), state = connecting>
//2D394432-91D5-6B56-8F79-E9B70C5F8AB8, name = (null), state = connecting>
//17EB8341-3735-CFB6-B3EC-AA0BB205D87D, name = iPad, state = connecting>
//3FF36D20-36F6-9403-BDF9-19326D3D760E, name = iPhone, state = connecting>
//C86EB4DF-3EE0-C769-A7DB-D248E7777C9A, name = iPhone, state = connecting>
//A5CC9876-2042-2842-A59A-2CFB5F28A991, name = M479fdw Color LJ, state = connecting>
//01D00E87-4CA7-221A-1276-C7F8F259C3DB, name = (null), state = connecting>
//38EA7B83-3F5D-DE3B-219F-35DFA184B379, name = LE-Bose SoundSport, state = connecting>
//257A277B-7EBC-481F-5B21-257EA2E7E607, name = LE-Beoplay H9, state = connecting>
//FA4B31D9-BAF3-E471-F00E-7D78026716C6, name = (null), state = connecting>
//1E12829D-AA7E-93E4-6B45-546663F134D7, name = Nina’s MacBook Pro, state = connecting>
//A246186B-E569-75CB-7E40-30814171BC0B, name = (null), state = connecting>
//C523040B-C140-8129-47D3-E56DA284F2B8, name = (null), state = connecting>
//72CB71F7-6C0F-AAFB-41AB-D26F545F4BA5, name = (null), state = connecting>
//C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
//Disconnected
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//Disconnected
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*****************************
//Connection complete
//Peripheral info: Optional(<CBPeripheral: 0x282c18640, identifier = C3D2EFBB-CBA3-27B9-BC1C-058F56870BCD, name = (null), state = connecting>)
//Scan Stopped
//Number of Peripherals Found: 40
//*******************************************************
//Discovered Services: []
//*******************************************************
//Discovered Services: []
