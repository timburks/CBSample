//
//  AppDelegate.m
//  CBSample
//
//  Created by Tim Burks on 7/3/12.
//  Copyright (c) 2012 Tim Burks. All rights reserved.
//

#import "AppDelegate.h"

#define VCARD_SERVICE @"CA8D534F-CA8D-CA8D-CA8D-740381000555"
#define VCARD_CHARACTERISTIC @"CA8D919E-CA8D-CA8D-CA8D-740381000555"

UITextView *gTextView;

@interface VCardService : NSObject
@end

@interface VCardService () <CBPeripheralManagerDelegate>
{
    CBPeripheralManager *manager;
    CBMutableService *vcardService;
    CBMutableCharacteristic *vcardCharacteristic;
}
@end

@implementation VCardService

- (id) init
{
    self = [super init];
    if (self) {
        manager = [[CBPeripheralManager alloc]
                   initWithDelegate:self queue:nil];
    }
    return self;
}

- (void) setupService
{
    CBUUID *cbuuidService = [CBUUID UUIDWithString:VCARD_SERVICE];
    CBUUID *cbuuidPipe = [CBUUID UUIDWithString:VCARD_CHARACTERISTIC];
    
    vcardCharacteristic = [[CBMutableCharacteristic alloc]
                           initWithType:cbuuidPipe
                           properties:CBCharacteristicPropertyNotify
                           value:nil
                           permissions:0];
    
    vcardService = [[CBMutableService alloc]
                    initWithType:cbuuidService
                    primary:YES];
    
    vcardService.characteristics =
    [NSArray arrayWithObject:vcardCharacteristic];
    
    [manager addService:vcardService];
}

- (void) advertise
{
    CBUUID *cbuuidService = [CBUUID UUIDWithString:VCARD_SERVICE];
    NSArray *services = [NSArray arrayWithObject:cbuuidService];
    NSDictionary *advertisingDict = [NSDictionary
                                     
                                     dictionaryWithObject:services
                                     forKey:CBAdvertisementDataServiceUUIDsKey];
    [manager startAdvertising:advertisingDict];
}

- (void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self setupService];
            break;
            
        default:
            NSLog(@"CBPeripheralManager changed state");
            break;
    }
}

static int count = 0;

- (NSData *) getFirstChunk
{
    count = 0;
    return [@"Testing..." dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *) getNextChunk
{
    switch (count++) {
        case 0: return [@"one" dataUsingEncoding:NSUTF8StringEncoding];
        case 1: return [@"two" dataUsingEncoding:NSUTF8StringEncoding];
        case 2: return [@"three" dataUsingEncoding:NSUTF8StringEncoding];
        default:
            return nil;
    }
}

- (void) peripheralManager:(CBPeripheralManager *) peripheral
                   central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"sending chunks");
    NSData *nextChunk = [self getFirstChunk];
    while (nextChunk) {
        [manager updateValue:nextChunk
           forCharacteristic:vcardCharacteristic
        onSubscribedCentrals:nil];
        nextChunk = [self getNextChunk];
    }
    NSData *eom = [@"ENDVAL" dataUsingEncoding:NSUTF8StringEncoding];
    [manager updateValue:eom
       forCharacteristic:vcardCharacteristic
    onSubscribedCentrals:nil];
}
@end

@interface VCardClient : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;

- (void) startScan;
@end

@implementation VCardClient

- (id) init {
    if (self = [super init]) {
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        [self startScan];
    }
    return self;
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
    NSArray *services = nil; // [NSArray arrayWithObject:[CBUUID UUIDWithString:VCARD_SERVICE]];
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
    [self isLECapableHardware];
}

// Invoked when the central discovers peripheral while scanning.
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)aPeripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"RSSI %@", RSSI);
    
    self.peripheral = aPeripheral;
    
    // Retrieve already known devices
    [self.manager retrievePeripherals:[NSArray arrayWithObject:(id)aPeripheral.UUID]];
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %u - %@", [peripherals count], peripherals);
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
    NSLog(@"connected");
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void) centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
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
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void) peripheral:(CBPeripheral *)aPeripheral
didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:VCARD_SERVICE]]) {
            NSLog(@"VCARD SERVICE FOUND");
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Discovered characteristics for %@ with error: %@",
              service.UUID, [error localizedDescription]);
        return;
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:VCARD_SERVICE]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            NSLog(@"discovered characteristic %@", characteristic.UUID);
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:VCARD_CHARACTERISTIC]])
            {
                NSLog(@"Found a VCard Characteristic");
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

/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void) peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:VCARD_CHARACTERISTIC]])
    {
        NSString *vcard = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"vcard = %@", vcard);
        
        gTextView.text = [NSString stringWithFormat:@"%@\n%@", vcard, [gTextView text]];
        if ([vcard isEqualToString:@"ENDVAL"]) {
            // let's disconnect
            [self.manager cancelPeripheralConnection:self.peripheral];
        }
    }
}

@end


@interface VCardViewController : UIViewController
@property (nonatomic, strong) VCardService *service;
@property (nonatomic, strong) VCardClient *client;
@property (nonatomic, strong) UITextView *textView;
@end

@implementation VCardViewController

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
    self.service = [[VCardService alloc] init];
    [self.service advertise];
    gTextView.text = @"Starting Service";
}

- (void) startClient:(id) sender
{
    self.client = [[VCardClient alloc] init];
    gTextView.text = @"Starting Client";
}

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.rootViewController = [[VCardViewController alloc] init];
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
