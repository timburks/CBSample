//
//  SampleService.m
//
//  Created by Tim Burks on 8/10/12.
//  Copyright (c) 2012 Tim Burks. All rights reserved.
//

#import "SampleService.h"
#import "Common.h"

@interface SampleService () <CBPeripheralManagerDelegate>
@property (nonatomic, strong) CBPeripheralManager *manager;
@property (nonatomic, strong) CBMutableService *sampleService;
@property (nonatomic, strong) CBMutableCharacteristic *sampleCharacteristic;
@property (nonatomic, strong) CBMutableCharacteristic *writableCharacteristic;
@end

@implementation SampleService

- (id) init
{
    self = [super init];
    if (self) {
        self.manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void) disconnect {
    // shuts down all public services
    [self.manager removeAllServices];
}

- (void) dealloc
{
    [self disconnect];
}

#pragma mark - Session setup

- (void) setupService
{
    self.sampleCharacteristic = [[CBMutableCharacteristic alloc]
                                 initWithType:[CBUUID UUIDWithString:NOTIFY_CHARACTERISTIC]
                                 properties:CBCharacteristicPropertyNotify
                                 value:nil
                                 permissions:0];
    
    self.writableCharacteristic = [[CBMutableCharacteristic alloc]
                                   initWithType:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC]
                                   properties:CBCharacteristicPropertyWrite
                                   value:nil
                                   permissions:CBAttributePermissionsWriteable];
    
    self.sampleService = [[CBMutableService alloc]
                          initWithType:[CBUUID UUIDWithString:SAMPLE_SERVICE]
                          primary:YES];
    self.sampleService.characteristics = [NSArray arrayWithObjects:
                                          self.sampleCharacteristic,
                                          self.writableCharacteristic,
                                          nil];
    
    [self.manager addService:self.sampleService];
}

- (void) advertise
{
    NSArray *services = [NSArray arrayWithObject:[CBUUID UUIDWithString:SAMPLE_SERVICE]];
    NSDictionary *advertisement = [NSDictionary dictionaryWithObjectsAndKeys:
                                   services, CBAdvertisementDataServiceUUIDsKey,
                                   @"CBSample", CBAdvertisementDataLocalNameKey,
                                   nil];
    [self.manager startAdvertising:advertisement];
}

#pragma mark - Messages to clients

static int count = 0;

- (void) resetChunks {
    count = 0;
}

- (void) stepChunks {
    count++;
}

- (NSData *) currentChunk
{
    // each chunk is at most 20 bytes (WWDC 12 session 705 40:33ff)
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
    NSLog(@"sending from service %@", [self.sampleService description]);
    
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

#pragma mark - CBPeripheralManagerDelegate methods
/*!
 *  @method peripheralManagerDidUpdateState:
 *
 *  @param peripheral   The peripheral manager whose state has changed.
 *
 *  @discussion         Invoked whenever the peripheral manager's state has been updated. Commands should only be issued when the state is
 *                      <code>CBPeripheralManagerStatePoweredOn</code>. A state below <code>CBPeripheralManagerStatePoweredOn</code>
 *                      implies that advertisement has stopped and any connected centrals have been disconnected. If the state moves below
 *                      <code>CBPeripheralManagerStatePoweredOff</code>, advertisement is stopped and must be explicitly restarted, and the
 *                      local database is cleared and all services must be re-added.
 *
 *  @see                state
 *
 */
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
    NSLog(@"peripheralManagerDidStartAdvertising:%@ error:%@", peripheral, [error localizedDescription]);
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
    NSLog(@"peripheralManager:%@ didAddService:%@ error:%@",
          peripheral, service, [error localizedDescription]);
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
    gTextView.text = [NSString stringWithFormat:@"%@\n%@", [gTextView text], @"disconnected"];
    
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
    NSLog(@"peripheralManager:%@ didReceiveWriteRequests:%@", peripheral, requests);
    
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


