/*********************************************************************
 This is an example for our nRF52 based Bluefruit LE modules

 Pick one up today in the adafruit shop!

 Adafruit invests time and resources providing this open source code,
 please support Adafruit and open-source hardware by purchasing
 products from Adafruit!

 MIT license, check LICENSE for more information
 All text above, and the splash screen below must be included in
 any redistribution
*********************************************************************/
#include <bluefruit.h>
#include <Adafruit_LittleFS.h>
#include <InternalFileSystem.h>
#include "KickExampleData.h"

// BLE Service
BLEDfu  bledfu;  // OTA DFU service
BLEDis  bledis;  // device information
BLEUart bleuart; // uart over ble
BLEBas  blebas;  // battery

bool BLEisConnected = false;

uint16_t numVals = 10
uint8_t vals[10] = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};

void setup()
{
  Serial.begin(115200);

#if CFG_DEBUG
  // Blocking wait for connection when debug mode is enabled via IDE
  while ( !Serial ) yield();
#endif
  
  Serial.println("Bluefruit52 BLEUART Example");
  Serial.println("---------------------------\n");

  // Setup the BLE LED to be enabled on CONNECT
  // Note: This is actually the default behaviour, but provided
  // here in case you want to control this LED manually via PIN 19
  Bluefruit.autoConnLed(true);

  // Config the peripheral connection with maximum bandwidth 
  // more SRAM required by SoftDevice
  // Note: All config***() function must be called before begin()
  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);

  Bluefruit.begin();
  Bluefruit.setTxPower(4);    // Check bluefruit.h for supported values
  Bluefruit.setName("Bluefruit52");
  //Bluefruit.setName(getMcuUniqueID()); // useful testing with multiple central connections
  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);

  // To be consistent OTA DFU should be added first if it exists
  bledfu.begin();

  // Configure and Start Device Information Service
  bledis.setManufacturer("Adafruit Industries");
  bledis.setModel("Bluefruit Feather52");
  bledis.begin();

  // Configure and Start BLE Uart Service
  bleuart.begin();

  // Start BLE Battery Service
  blebas.begin();
  blebas.write(100);

  // Set up and start advertising
  startAdv();

  Serial.println("Please use Adafruit's Bluefruit LE app to connect in UART mode");
  Serial.println("Once connected, enter character(s) that you wish to send");
}

void startAdv(void)
{
  // Advertising packet
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();

  // Include bleuart 128-bit uuid
  Bluefruit.Advertising.addService(bleuart);

  // Secondary Scan Response packet (optional)
  // Since there is no room for 'Name' in Advertising packet
  Bluefruit.ScanResponse.addName();
  
  /* Start Advertising
   * - Enable auto advertising if disconnected
   * - Interval:  fast mode = 20 ms, slow mode = 152.5 ms
   * - Timeout for fast mode is 30 seconds
   * - Start(timeout) with timeout = 0 will advertise forever (until connected)
   * 
   * For recommended advertising interval
   * https://developer.apple.com/library/content/qa/qa1931/_index.html   
   */
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244);    // in unit of 0.625 ms
  Bluefruit.Advertising.setFastTimeout(30);      // number of seconds in fast mode
  Bluefruit.Advertising.start(0);                // 0 = Don't stop advertising after n seconds  
}

void loop()
{
  delay(1000);

  // While there is a bluetooth connection, send the array values to app
  while (BLEisConnected) {
    bleuart.write(vals, numVals);
    Serial.println("Done");
    delay(5000);          // Wait 5 seconds
  }
   
  // Forward from BLEUART to HW Serial, try to see if app
  while ( bleuart.available() )
  {
    uint8_t ch;
    ch = (uint8_t) bleuart.read();
    Serial.write(ch);
  }
}

// callback invoked when central connects
void connect_callback(uint16_t conn_handle)
{
  // Get the reference to current connection
  BLEConnection* connection = Bluefruit.Connection(conn_handle);

  char central_name[32] = { 0 };
  connection->getPeerName(central_name, sizeof(central_name));

  Serial.print("Connected to ");
  Serial.println(central_name);
  BLEisConnected = true;
}

/**
 * Callback invoked when a connection is dropped
 * @param conn_handle connection where this event happens
 * @param reason is a BLE_HCI_STATUS_CODE which can be found in ble_hci.h
 */
void disconnect_callback(uint16_t conn_handle, uint8_t reason)
{
  (void) conn_handle;
  (void) reason;

  Serial.println();
  Serial.print("Disconnected, reason = 0x"); Serial.println(reason, HEX);
  BLEisConnected = false;
}

int fill_buffer(const int16_t num, uint8_t text[])
{
  //Serial.println("Filling buffer");
  String strData = String(num);
  int strLen = strData.length();
  int index = 0;
  while(index < strLen) {
    text[index] = strData[index];
    //Serial.println(text[index]);
    index++;
  }
  //text[index++] = ',';
  //Serial.println("Buffer loaded");
  return index;
}


int fill_buffer(const int16_t rawData[], uint8_t text[], int16_t samples)
{
  //Serial.println("Filling buffer");
  int space = 0;
  for (int i = 0; i < samples / 4; i++) {
    String strData = String(rawData[i]);
    int strLen = strData.length();
    for (int k = 0; k < 4 - strLen; k++) {
      text[space++] = ' ';
      //Serial.println(k);
    }
    for (int j = 0; j < strLen; j++) {
      text[space] = strData[j];  
      space++;
    }
  }
  //Serial.println("Buffer loaded");
  return space;
  /*
  Serial.println("Filling buffer");
  int index = 0;
  for (int i = 0; i < samples; i++) {
    String strData = String(rawData[i]);
    int strLen = strData.length();
    for (int j = 0; j < strLen; j++) {
      text[index] = strData[j];
      Serial.println((char) text[index]);
      index++;
    }
    //text[index++] = ',';
  }
  Serial.println("Buffer loaded");
  return index;
  */
}

int fill_buffer(const int16_t rawData[], uint8_t text[], int16_t samples, uint16_t index)
{
  //Serial.println("Filling buffer");
  int space = 0;
  int lowLim = index;
  int uppLim = samples / 4 + index;
  String strData;
  //char hex[3];
  for (int i = lowLim; i < uppLim; i++) {
    //String strData = String(rawData[i]);
    //String strData = String(rawData[i], HEX);
    strData = dec2hex(rawData[i]);
    
    int strLen = strData.length();
    //for (int k = 0; k < 4 - strLen; k++) {
    for (int k = 0; k < 3 - strLen; k++) {
      text[space++] = ' ';
      //Serial.println(k);
    }
    for (int j = 0; j < strLen; j++) {
      text[space] = strData[j];  
      space++;
    }
    index++;
  }
  //Serial.println("Buffer loaded");
  return index;
}

void print_array(const uint8_t text[], int lim)
{
  for (int i = 0; i < lim; i++) {
    //Serial.println(text[i]);
    Serial.print(i);
    Serial.print(", ");
    //Serial.println((char) text[i]);
    Serial.println(text[i]);
  }
  //Serial.print("Length: ");
  //Serial.println(lim);
}

void print_int_array(const int16_t arr[], const int16_t samples)
{
  for (int i = 0; i < samples; i++) {
    //Serial.println(text[i]);
    Serial.print(i);
    Serial.print(", ");
    Serial.println(arr[i]);
  }
  Serial.print("int length: ");
  Serial.println(samples);
}

String dec2hex(int16_t dec) {
  if (dec > 1 && dec < 4095) {
    char hex[3];
    uint8_t index = 2;
    while (dec > 0) {
      uint8_t rem = dec % 16;
      if (rem < 10) {
        hex[index--] = rem + 48;
      }
      else {
        hex[index--] = rem + 87;
      }
      dec /= 16;
    }
    return (String) hex;
  }
  else {
    Serial.print("[ERROR] ");
    Serial.print(dec);
    Serial.println(" not in range 1-4095");
  }
}

void decComp(const int16_t rawData[], uint8_t text[], uint16_t loLim, uint16_t hiLim) {
  uint8_t dig;
  int16_t datum;
  int16_t textIdx = 0;
  for (int i = loLim; i < hiLim; i++) {
    datum = rawData[i];
    //Serial.println(datum);
    for (int j = 0; j < 2; j++) {
      dig = (datum % 10) << (j * 4);
      //Serial.println(dig);
      text[textIdx] += dig;
      datum /= 10;
    }
    textIdx++;
    for (int j = 0; j < 2; j++) {
      dig = (datum % 10) << (j * 4);
      //Serial.println(dig);
      text[textIdx] += dig;
      datum /= 10;
    }
    textIdx++;
  }
}
