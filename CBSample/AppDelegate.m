//
//  AppDelegate.m
//  CBSample
//
//  Created by Tim Burks on 7/3/12.
//  Copyright (c) 2012 Tim Burks. All rights reserved.
//

#import "AppDelegate.h"

#define SAMPLE_SERVICE        @"00000000-0000-0000-0000-000000000000"
#define SAMPLE_CHARACTERISTIC @"00000000-0000-0000-0000-000000000000"

UITextView *gTextView;

@interface SampleService : NSObject
@end

@interface SampleService () <CBPeripheralManagerDelegate>
@property (nonatomic, strong) CBPeripheralManager *manager;
@property (nonatomic, strong) CBMutableService *sampleService;
@property (nonatomic, strong) CBMutableCharacteristic *sampleCharacteristic;
@end

@implementation SampleService

- (id) init
{
    self = [super init];
    if (self) {
        self.manager = [[CBPeripheralManager alloc]
                        initWithDelegate:self queue:nil];
    }
    return self;
}

- (void) dealloc
{
    [self.manager removeAllServices];
}

- (void) setupService
{
    CBUUID *cbuuidService = [CBUUID UUIDWithString:SAMPLE_SERVICE];
    CBUUID *cbuuidPipe = [CBUUID UUIDWithString:SAMPLE_CHARACTERISTIC];
    
    self.sampleCharacteristic = [[CBMutableCharacteristic alloc]
                                 initWithType:cbuuidPipe
                                 properties:CBCharacteristicPropertyNotify
                                 value:nil
                                 permissions:0];
    
    self.sampleService = [[CBMutableService alloc]
                          initWithType:cbuuidService
                          primary:YES];
    
    self.sampleService.characteristics =
    [NSArray arrayWithObject:self.sampleCharacteristic];
    
    [self.manager addService:self.sampleService];
}

- (void) advertise
{
    CBUUID *cbuuidService = [CBUUID UUIDWithString:SAMPLE_SERVICE];
    NSArray *services = [NSArray arrayWithObject:cbuuidService];
    NSDictionary *advertisingDict = [NSDictionary
                                     
                                     dictionaryWithObject:services
                                     forKey:CBAdvertisementDataServiceUUIDsKey];
    [self.manager startAdvertising:advertisingDict];
}

- (void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSString *state = nil;
    switch (peripheral.state) {
        case CBPeripheralManagerStateResetting:
            state = @"resetting"; break;
        case CBPeripheralManagerStateUnsupported:
            state = @"unsupported"; break;
        case CBPeripheralManagerStateUnauthorized:
            state = @"unauthorized"; break;
        case CBPeripheralManagerStatePoweredOff:
            state = @"off"; break;
        case CBPeripheralManagerStatePoweredOn:
            state = @"on"; break;
        default:
            state = @"unknown"; break;
    }
    NSLog(@"peripheralManagerDidUpdateState:%@ to %@ (%d)", peripheral, state, peripheral.state);
    
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self setupService];
            [self advertise];
            break;
        default:
            break;
    }
}

/*!
 *  @method peripheralManagerDidStartAdvertising:error:
 *
 *  @param peripheral   The peripheral manager providing this information.
 *  @param error        If an error occurred, the cause of the failure.
 *
 *  @discussion         This method returns the result of a @link startAdvertising: @/link call. If advertisement could
 *                      not be started, the cause will be detailed in the <i>error</i> parameter.
 *
 */
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    NSLog(@"peripheralManagerDidStartAdvertising:");
}

/*!
 *  @method peripheralManager:didAddService:error:
 *
 *  @param peripheral   The peripheral manager providing this information.
 *  @param service      The service that was added to the local database.
 *  @param error        If an error occurred, the cause of the failure.
 *
 *  @discussion         This method returns the result of an @link addService: @/link call. If the service could
 *                      not be published to the local database, the cause will be detailed in the <i>error</i> parameter.
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    NSLog(@"peripheralManager:didAddService:error:");
}

/*!
 *  @method peripheralManager:central:didSubscribeToCharacteristic:
 *
 *  @param peripheral       The peripheral manager providing this update.
 *  @param central          The central that issued the command.
 *  @param characteristic   The characteristic on which notifications or indications were enabled.
 *
 *  @discussion             This method is invoked when a central configures <i>characteristic</i> to notify or indicate.
 *                          It should be used as a cue to start sending updates as the characteristic value changes.
 *
 */
static int count = 0;

- (void) resetChunks {
    count = 0;
}

- (void) stepChunks {
    count++;
}

- (NSData *) currentChunk
{
    switch (count) {
        case 0: return [@"testing" dataUsingEncoding:NSUTF8StringEncoding];
        case 1: return [@"one" dataUsingEncoding:NSUTF8StringEncoding];
        case 2: return [@"two" dataUsingEncoding:NSUTF8StringEncoding];
        case 3: return [@"three" dataUsingEncoding:NSUTF8StringEncoding];
        case 4: return [@"ENDVAL" dataUsingEncoding:NSUTF8StringEncoding];
        default:
            return nil;
    }
}

- (void) sendChunks {
    NSData *nextChunk = [self currentChunk];
    while (nextChunk) {
        NSLog(@"sending chunk %@", [[NSString alloc] initWithData:nextChunk encoding:NSUTF8StringEncoding]);
        
        BOOL success = [self.manager updateValue:nextChunk
                               forCharacteristic:self.sampleCharacteristic
                            onSubscribedCentrals:nil];
        if (success) {
            [self stepChunks];
            nextChunk = [self currentChunk];
        } else {
            NSLog(@"out of space. temporarily halting transmission");
            break;
        }
    }
}

- (void) peripheralManager:(CBPeripheralManager *) peripheral
                   central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"peripheralManager:central:didSubscribeToCharacteristic:");
    [self resetChunks];
    [self sendChunks];
}

/*!
 *  @method peripheralManager:central:didUnsubscribeFromCharacteristic:
 *
 *  @param peripheral       The peripheral manager providing this update.
 *  @param central          The central that issued the command.
 *  @param characteristic   The characteristic on which notifications or indications were disabled.
 *
 *  @discussion             This method is invoked when a central removes notifications/indications from <i>characteristic</i>.
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    [self resetChunks];
    NSLog(@"peripheralManager:central:didUnsubscribeFromCharacteristic:");
}

/*!
 *  @method peripheralManager:didReceiveReadRequest:
 *
 *  @param peripheral   The peripheral manager requesting this information.
 *  @param request      A <code>CBATTRequest</code> object.
 *
 *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request for a characteristic with a dynamic value.
 *                      For every invocation of this method, @link respondToRequest:withResult: @/link must be called.
 *
 *  @see                CBATTRequest
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"peripheralManager:didReceiveRequest:");
}

/*!
 *  @method peripheralManager:didReceiveWriteRequests:
 *
 *  @param peripheral   The peripheral manager requesting this information.
 *  @param requests     A list of one or more <code>CBATTRequest</code> objects.
 *
 *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request or command for one or more characteristics with a dynamic value.
 *                      For every invocation of this method, @link respondToRequest:withResult: @/link should be called exactly once. If <i>requests</i> contains
 *                      multiple requests, they must be treated as an atomic unit. If the execution of one of the requests would cause a failure, the request
 *                      and error reason should be provided to <code>respondToRequest:withResult:</code> and none of the requests should be executed.
 *
 *  @see                CBATTRequest
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    NSLog(@"peripheralManager:didReceiveWriteRequests:");
    
}

/*!
 *  @method peripheralManagerIsReadyToUpdateSubscribers:
 *
 *  @param peripheral   The peripheral manager providing this update.
 *
 *  @discussion         This method is invoked after a failed call to @link updateValue:forCharacteristic:onSubscribedCentrals: @/link, when <i>peripheral</i> is again
 *                      ready to send characteristic value updates.
 *
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers:");
    [self sendChunks];
}

@end

@interface SampleClient : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;

- (void) startScan;
@end

@implementation SampleClient

- (id) init {
    if (self = [super init]) {
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void) dealloc {
    
}

#pragma mark - Start/Stop Scan methods

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    switch ([self.manager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    NSLog(@"Central manager state: %@", state);
    return FALSE;
}

// Request CBCentralManager to scan for peripherals
- (void) startScan
{
    NSLog(@"starting scan");
    NSArray *services = [NSArray arrayWithObject:[CBUUID UUIDWithString:SAMPLE_SERVICE]];
    [self.manager scanForPeripheralsWithServices:services options:nil];
}

// Request CBCentralManager to stop scanning for peripherals
- (void) stopScan
{
    [self.manager stopScan];
}

#pragma mark - CBCentralManager delegate methods

// Invoked when the central manager's state is updated.
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState:");
    [self isLECapableHardware];
    
    NSString * state = nil;
    switch ([self.manager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            state = @"Powered On";
            [self startScan];
            break;
        case CBCentralManagerStateUnknown:
        default:
            state = @"Unknown";
    }
    NSLog(@"centralManagerDidUpdateState: %@ to %@", central, state);
}

// Invoked when the central discovers peripheral while scanning.
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)aPeripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"centralManager:didDiscoverPeripheral:%@ advertisementData:%@ RSSI %@",
          aPeripheral,
          [advertisementData description],
          RSSI);
    
    self.peripheral = aPeripheral;
    
    [self.manager
     connectPeripheral:self.peripheral
     options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                         forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"centralManager:didRetrievePeripherals:%@", [peripherals description]);
    [self stopScan];
    // If there are any known devices, automatically connect to it.
    if([peripherals count] >= 1) {
        NSLog(@"connecting...");
        self.peripheral = [peripherals objectAtIndex:0];
        [self.manager connectPeripheral:self.peripheral
                                options:[NSDictionary dictionaryWithObject:
                                         [NSNumber numberWithBool:YES]
                                                                    forKey:
                                         CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
}

// Invoked when a connection is succesfully created with the peripheral.
// Discover available services on the peripheral
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    NSLog(@"centralManager:didConnectPeripheral:%@", aPeripheral);
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void) centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    NSLog(@"centralManager:didDisconnectPeripheral:%@ error:%@", aPeripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

// Invoked when the central manager fails to create a connection with the peripheral.
- (void) centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    NSLog(@"centralManager:didFailToConnectPeripheral:%@ error:%@", aPeripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

/*!
 *  @method peripheralDidUpdateName:
 *
 *  @param peripheral	The peripheral providing this update.
 *
 *  @discussion			This method is invoked when the @link name @/link of <i>peripheral</i> changes.
 */
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    NSLog(@"peripheralDidUpdateName:%@", peripheral);
}

/*!
 *  @method peripheralDidInvalidateServices:
 *
 *  @param peripheral	The peripheral providing this update.
 *
 *  @discussion			This method is invoked when the @link services @/link of <i>peripheral</i> have been changed. At this point,
 *						all existing <code>CBService</code> objects are invalidated. Services can be re-discovered via @link discoverServices: @/link.
 */
- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    NSLog(@"peripheralDidInvalidateServices:%@", peripheral);
}

/*!
 *  @method peripheralDidUpdateRSSI:error:
 *
 *  @param peripheral	The peripheral providing this update.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link readRSSI: @/link call.
 */
- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"peripheralDidUpdateRSSI:%@ error:%@", peripheral, [error localizedDescription]);
}

/*!
 *  @method peripheral:didDiscoverServices:
 *
 *  @param peripheral	The peripheral providing this information.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverServices: @/link call. If the service(s) were read successfully, they can be retrieved via
 *						<i>peripheral</i>'s @link services @/link property.
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"peripheral:%@ didDiscoverServices:%@", peripheral, [error localizedDescription]);
    for (CBService *aService in peripheral.services) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:SAMPLE_SERVICE]]) {
            NSLog(@"SAMPLE SERVICE FOUND");
            [peripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

/*!
 *  @method peripheral:didDiscoverIncludedServicesForService:error:
 *
 *  @param peripheral	The peripheral providing this information.
 *  @param service		The <code>CBService</code> object containing the included services.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverIncludedServices:forService: @/link call. If the included service(s) were read successfully,
 *						they can be retrieved via <i>service</i>'s <code>includedServices</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error
{
   NSLog(@"peripheral:%@ didDiscoverIncludedServicesForService:%@ error:%@",
         peripheral, service, [error localizedDescription]);
}

/*!
 *  @method peripheral:didDiscoverCharacteristicsForService:error:
 *
 *  @param peripheral	The peripheral providing this information.
 *  @param service		The <code>CBService</code> object containing the characteristic(s).
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverCharacteristics:forService: @/link call. If the characteristic(s) were read successfully,
 *						they can be retrieved via <i>service</i>'s <code>characteristics</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"peripheral:%@ didDiscoverCharacteristicsForService:%@ error:%@",
          peripheral, service, [error localizedDescription]);
    
    if (error)
    {
        NSLog(@"Discovered characteristics for %@ with error: %@",
              service.UUID, [error localizedDescription]);
        return;
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:SAMPLE_SERVICE]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            NSLog(@"discovered characteristic %@", characteristic.UUID);
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:SAMPLE_CHARACTERISTIC]])
            {
                NSLog(@"Found a Sample Characteristic");
                [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
    
    else if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *characteristic in service.characteristics)
        {
            NSLog(@"discovered generic characteristic %@", characteristic.UUID);
            
            /* Read device name */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
                [self.peripheral readValueForCharacteristic:characteristic];
                NSLog(@"Found a Device Name Characteristic - Read device name");
            }
        }
    }
    
    else {
        NSLog(@"unknown service discovery %@", service.UUID);
        
    }
}

/*!
 *  @method peripheral:didUpdateValueForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method is invoked after a @link readValueForCharacteristic: @/link call, or upon receipt of a notification/indication.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"peripheral:%@ didUpdateValueForCharacteristic:%@ error:%@",
          peripheral, characteristic, error);
    
    if (error) {
        NSLog(@"Error updating value for characteristic %@ error: %@",
              characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:SAMPLE_CHARACTERISTIC]]) {
        NSString *chunk = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"chunk = %@", chunk);
        
        gTextView.text = [NSString stringWithFormat:@"%@\n%@", [gTextView text], chunk];
        if ([chunk isEqualToString:@"ENDVAL"]) {
            // let's disconnect
            NSLog(@"disconnecting");
            gTextView.text = [NSString stringWithFormat:@"%@\n%@", [gTextView text], @"disconnecting"];
            [self.manager cancelPeripheralConnection:self.peripheral];
            
        }
    }
}

/*!
 *  @method peripheral:didWriteValueForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link writeValue:forCharacteristic: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"peripheral:%@ didWriteValueForCharacteristic:%@ error:%@",
          peripheral, characteristic, [error description]);
}

/*!
 *  @method peripheral:didUpdateNotificationStateForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link setNotifyValue:forCharacteristic: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"peripheral:%@ didUpdateNotificationStateForCharacteristic:%@ error:%@",
          peripheral, characteristic, [error description]);
}

/*!
 *  @method peripheral:didDiscoverDescriptorsForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link discoverDescriptorsForCharacteristic: @/link call. If the descriptors were read successfully,
 *							they can be retrieved via <i>characteristic</i>'s <code>descriptors</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"peripheral:%@ didDiscoverDescriptorsForCharacteristic:%@ error:%@",
          peripheral, characteristic, [error description]);
}

/*!
 *  @method peripheral:didUpdateValueForDescriptor:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param descriptor		A <code>CBDescriptor</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link readValueForDescriptor: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    NSLog(@"peripheral:%@ didUpdateValueForDescriptor:%@ error:%@",
          peripheral, descriptor, [error description]);
}

/*!
 *  @method peripheral:didWriteValueForDescriptor:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param descriptor		A <code>CBDescriptor</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link writeValue:forDescriptor: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    NSLog(@"peripheral:%@ didWriteValueForDescriptor:%@ error:%@",
          peripheral, descriptor, [error description]);
}




/*!
 *  @method centralManager:didRetrievePeripherals:
 *
 *  @param central      The central manager providing this information.
 *  @param peripherals  A list of <code>CBPeripheral</code> objects.
 *
 *  @discussion         This method returns the result of a @link retrievePeripherals @/link call, with the peripheral(s) that the central manager was
 *                      able to match to the provided UUID(s).
 *
 */

/*!
 *  @method centralManager:didRetrieveConnectedPeripherals:
 *
 *  @param central      The central manager providing this information.
 *  @param peripherals  A list of <code>CBPeripheral</code> objects representing all peripherals currently connected to the system.
 *
 *  @discussion         This method returns the result of a @link retrieveConnectedPeripherals @/link call.
 *
 */
- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
    NSLog(@"centralManager:didRetrieveConnectedPeripherals:%@", peripherals);
    
}

/*!
 *  @method centralManager:didDiscoverPeripheral:advertisementData:RSSI:
 *
 *  @param central              The central manager providing this update.
 *  @param peripheral           A <code>CBPeripheral</code> object.
 *  @param advertisementData    A dictionary containing any advertisement and scan response data.
 *  @param RSSI                 The current RSSI of <i>peripheral</i>, in decibels.
 *
 *  @discussion                 This method is invoked while scanning, upon the discovery of <i>peripheral</i> by <i>central</i>. Any advertisement/scan response
 *                              data stored in <i>advertisementData</i> can be accessed via the <code>CBAdvertisementData</code> keys. A discovered peripheral must
 *                              be retained in order to use it; otherwise, it is assumed to not be of interest and will be cleaned up by the central manager.
 *
 *  @seealso                    CBAdvertisementData.h
 *
 */

/*!
 *  @method centralManager:didConnectPeripheral:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has connected.
 *
 *  @discussion         This method is invoked when a connection initiated by @link connectPeripheral:options: @/link has succeeded.
 *
 */

/*!
 *  @method centralManager:didFailToConnectPeripheral:error:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has failed to connect.
 *  @param error        The cause of the failure.
 *
 *  @discussion         This method is invoked when a connection initiated by @link connectPeripheral:options: @/link has failed to complete. As connection attempts do not
 *                      timeout, the failure of a connection is atypical and usually indicative of a transient issue.
 *
 */

/*!
 *  @method centralManager:didDisconnectPeripheral:error:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has disconnected.
 *  @param error        If an error occurred, the cause of the failure.
 *
 *  @discussion         This method is invoked upon the disconnection of a peripheral that was connected by @link connectPeripheral:options: @/link. If the disconnection
 *                      was not initiated by @link cancelPeripheralConnection @/link, the cause will be detailed in the <i>error</i> parameter. Once this method has been
 *                      called, no more methods will be invoked on <i>peripheral</i>'s <code>CBPeripheralDelegate</code>.
 *
 */

@end


@interface SampleViewController : UIViewController
@property (nonatomic, strong) SampleService *service;
@property (nonatomic, strong) SampleClient *client;
@property (nonatomic, strong) UITextView *textView;
@end

@implementation SampleViewController

- (void) loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor redColor];
    UIButton *serviceButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    serviceButton.frame = CGRectInset(CGRectMake(0,25,
                                                 0.5*self.view.bounds.size.width,50),
                                      20, 0);
    [serviceButton setTitle:@"start service" forState:UIControlStateNormal];
    [serviceButton addTarget:self action:@selector(startService:)
            forControlEvents:UIControlEventTouchUpInside];
    serviceButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin+UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:serviceButton];
    UIButton *clientButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    clientButton.frame = CGRectInset(CGRectMake(0.5*self.view.bounds.size.width,25,
                                                0.5*self.view.bounds.size.width,50),
                                     20, 0);
    [clientButton setTitle:@"start client" forState:UIControlStateNormal];
    [clientButton addTarget:self action:@selector(startClient:)
           forControlEvents:UIControlEventTouchUpInside];
    clientButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin+UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:clientButton];
    
    self.textView = [[UITextView alloc]
                     initWithFrame:CGRectInset(CGRectMake(0, 100,
                                                          self.view.bounds.size.width,
                                                          self.view.bounds.size.height-100),
                                               20, 20)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleHeight;
    self.textView.editable = NO;
    [self.view addSubview:self.textView];
    
    gTextView = self.textView;
    
}

- (void) startService:(id) sender
{
    NSLog(@"startService: pressed");
    self.service = [[SampleService alloc] init];
    gTextView.text = @"Starting Service";
}

- (void) startClient:(id) sender
{
    NSLog(@"startClient: pressed");
    self.client = [[SampleClient alloc] init];
    gTextView.text = @"Starting Client";
}

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.rootViewController = [[SampleViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
