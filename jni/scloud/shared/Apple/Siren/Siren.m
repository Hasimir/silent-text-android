/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal 
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  Siren.m
//  SilentText
//
//  Sirens try to capture JSON and the Argonauts.
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "AppConstants.h"
#import "Siren.h"
#import "NSString+SCUtilities.h"
#import "NSData+SCUtilities.h"
#import "XMPPMessage+XEP_0033.h"
#import "XMPPMessage+SilentCircle.h"

#import "StorageCipher.h"
#include "SirenHash.h"

 
NSString *const kCloudKeyKey = @"cloud_key";
NSString *const kCloudLocatorKey = @"cloud_url";
NSString *const kConversationIDKey = @"conversation_id";
NSString *const kFYEOKey = @"fyeo";
NSString *const kMessageKey = @"message";
NSString *const kPlainTextKey = @"plain_text";

NSString *const kRequestReceiptKey = @"request_receipt";
NSString *const kReceivedIDKey = @"received_id";
NSString *const kReceivedTimeKey = @"received_time";

NSString *const kRequestResendKey = @"request_resend";
NSString *const kRequestBurnKey = @"request_burn";
NSString *const kShredAfterKey = @"shred_after";
NSString *const kLocationKey = @"location";
NSString *const kPingKey = @"ping";

NSString *const kVcardKey = @"vcard";

NSString *const kThumbNailKey = @"thumbnail";
NSString *const kMediaTypeKey = @"media_type";

NSString *const kPingRequest = @"PING";
NSString *const kPingResponse = @"PONG";

NSString *const kSirenSigKey = @"siren_sig";
NSString *const kMulticastkeyKey = @"multicast_key";




static const NSUInteger kNumSirenKeys = 20;

@interface Siren ()

@property (strong, nonatomic, readwrite) NSString *json;
@property (strong, nonatomic, readwrite) NSData   *jsonData;
@property (strong, nonatomic, readwrite) XMPPMessage *chatMessage;
@property (strong, nonatomic) NSMutableDictionary *info;
@property ( nonatomic) BOOL  badData;

@end

@implementation Siren

@synthesize json = _json;
@synthesize jsonData = _jsonData;

// XMPPMessage properties.
@synthesize chatMessage = _chatMessage;
@dynamic body;
@dynamic from, fromStr;
@dynamic scimp;
@dynamic to, toStr;
@dynamic chatMessageID;

@dynamic cloudKey;
@dynamic cloudLocator;
@dynamic conversationID;
@dynamic fyeo;
@dynamic plainText;
@dynamic message;
@dynamic receivedID;
@dynamic receivedTime;
@dynamic requestResend;
@dynamic requestBurn;
@dynamic shredAfter;
@dynamic ping;
@dynamic location;
@dynamic thumbnail;
@dynamic mediaType;
@dynamic vcard;
@dynamic signature;
@dynamic multicastKey;


@synthesize info = _info;
 
NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.
static const long kNumDateFormatters = 1l;
static dispatch_semaphore_t _siren_df_semaphore  = NULL;
static NSDateFormatter *    _siren_dateFormatter = nil;
static NSArray*  _siren_hashableItems = nil;

+ (void) initialize {
	
	if (self == Siren.class) {
		
		_siren_df_semaphore = dispatch_semaphore_create(kNumDateFormatters);
		
        // Quinn "The Eskimo" pointed me to: 
        // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
        // The contained advice recommends all internet time formatting to use US POSIX standards.
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
        
		_siren_dateFormatter = NSDateFormatter.new;
        
        [_siren_dateFormatter setLocale: enUSPOSIXLocale];
        [_siren_dateFormatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
		[_siren_dateFormatter setDateFormat: kZuluTimeFormat];
        
        _siren_hashableItems = [[NSArray arrayWithObjects:
                         kMessageKey, kCloudKeyKey,kCloudLocatorKey,kFYEOKey,
                         kShredAfterKey,kRequestBurnKey, kRequestResendKey ,kLocationKey,
                                 kVcardKey, kThumbNailKey,kMediaTypeKey,  nil]  sortedArrayUsingSelector:@selector(compare:)  ];

    }
    
} // +initialize


#pragma mark - Accessor methods.

- (id)copyWithZone:(NSZone *)zone
{
      NSData *jsonData = [self jsonData];
     Siren *siren = [Siren sirenWithJSONData: jsonData];
    
 	return siren;
}



- (NSString *) json {
    
    if (_json) { return _json; }
    
    NSData   *jsonData = self.jsonData;
    NSString *json     = [NSString.alloc initWithBytes: jsonData.bytes 
                                                length: jsonData.length 
                                              encoding: NSUTF8StringEncoding];
    self.json = json;
    
    return json;
    
} // -json


- (NSData *) jsonData {
    
    if (_jsonData) { return _jsonData; }
    
    NSError *error = nil;
    
    NSData *data = ([NSJSONSerialization  isValidJSONObject: self.info] ? 
                    [NSJSONSerialization dataWithJSONObject: self.info options: 0UL error: &error] : 
                    nil);
    if (error) {
        
        self.badData = YES;
     }
    self.jsonData = data;
    self.json = nil;

    return data;
    
} // -jsonData


- (Siren *) nilJSON {
    
    self.json     = nil;
    self.jsonData = nil;
    self.chatMessage = nil;
    
    return self;
    
} // -nilJSON


#pragma mark XMPPMessage accessor methods.


- (NSString *) body {
    
    return [[self.chatMessage elementForName: kXMPPBody] stringValue];
    
} // -body


- (XMPPJID *) from {
    
    NSString *jidString = self.fromStr;
    
    return jidString ? [XMPPJID jidWithString: jidString] : nil;
    
} // -from


- (NSString *) fromStr {
    
    return [[self.chatMessage attributeForName: kXMPPFrom] stringValue];
    
} // -fromStr


- (NSString *) scimp {
    
    return [[self.chatMessage elementForName: kXMPPX xmlns: kSCPPNameSpace] stringValue];
    
} // -scimp


- (XMPPJID *) to {
    
    NSString *jidString = self.toStr;
    
    return jidString ? [XMPPJID jidWithString: jidString] : nil;
    
} // -to


- (NSString *) toStr {
    
    return [[self.chatMessage attributeForName: kXMPPTo] stringValue];
    
} // -toStr


- (NSString *) chatMessageID {
    
    return [[self.chatMessage attributeForName: kXMPPID] stringValue];
    
} // -chatMessageID


#pragma mark JSON accessor methods.


- (NSString *) cloudKey {
    
    NSString *cloudKey = [self.info valueForKey: kCloudKeyKey];
    
    return [cloudKey isKindOfClass: NSString.class] ? cloudKey : nil;
    
} // -cloudKey


- (void) setCloudKey: (NSString *) cloudKey {
    
    [self nilJSON];
    
    [self.info setValue: cloudKey forKey: kCloudKeyKey];
    
} // -setCloudKey:


- (NSString *) cloudLocator {
    
    NSString *cloudLocator = [self.info valueForKey: kCloudLocatorKey];
    
    return [cloudLocator isKindOfClass: NSString.class] ? cloudLocator : nil;
    
} // -cloudLocator


- (void) setCloudLocator: (NSString *) cloudLocator {
    
    [self nilJSON];
    
    [self.info setValue: cloudLocator forKey: kCloudLocatorKey];
    
} // -setcloudLocator:


- (NSString *) mediaType {
    
    NSString *mediaType = [self.info valueForKey: kMediaTypeKey];
    
    return [mediaType isKindOfClass: NSString.class] ? mediaType : nil;
    
} // -mediaType


- (void) setMediaType:(NSString *)mediaType{
    
    [self nilJSON];
    
    [self.info setValue: mediaType forKey: kMediaTypeKey];
    
} // -setMediaType:



- (NSString *) vcard {
    
    NSString *vcard = [self.info valueForKey: kVcardKey];
    
    return [vcard isKindOfClass: NSString.class] ? vcard : nil;

       
} // -thumbnail

 

- (void) setVcard:(NSString *)thumbnail  {
    
    [self nilJSON];
    
    [self.info setValue: thumbnail forKey: kVcardKey];

  } // -setThumbnail:


- (NSString *) signature {
    
    NSString *signature = [self.info valueForKey: kSirenSigKey];
    
    return [signature isKindOfClass: NSString.class] ? signature : nil;
    
    
} // -thumbnail

 
- (void) setSignature:(NSString *)signature  {
    
    [self nilJSON];
    
    [self.info setValue: signature forKey: kSirenSigKey];
    
} // -setThumbnail:


- (NSString *) multicastKey {
    
    NSString *mcKey = [self.info valueForKey: kMulticastkeyKey];
    
    return [mcKey isKindOfClass: NSString.class] ? mcKey : nil;
    
    
} // -thumbnail



- (void) setMulticastKey:(NSString *)mcKey
{
    
    [self nilJSON];
    
    [self.info setValue: mcKey forKey: kMulticastkeyKey];
    
} // -setThumbnail:


 



- (NSString *) conversationID {
    
    NSString *conversationID = [self.info valueForKey: kConversationIDKey];
    
    return [conversationID isKindOfClass: NSString.class] ? conversationID : nil;
    
} // -conversationID


- (void) setConversationID: (NSString *) conversationID {
    
    [self nilJSON];
    
    [self.info setValue: conversationID forKey: kConversationIDKey];
    
} // -setConversationID:



- (NSString *) ping {
    
    NSString *ping = [self.info valueForKey: kPingKey];
    
    return [ping isKindOfClass: NSString.class] ? ping : nil;
    
} // -ping


- (void) setPing: (NSString *) ping {
    
    [self nilJSON];
    
    [self.info setValue: ping forKey: kPingKey];
    
} // -setPing:


- (NSString *) location {
    
    NSString *location = [self.info valueForKey: kLocationKey];
    
    return [location isKindOfClass: NSString.class] ? location : nil;
    
} // -location


- (void) setLocation: (NSString *) location {
    
    [self nilJSON];
    
    [self.info setValue: location forKey: kLocationKey];
    
} // -setLocation:




- (NSData *) thumbnail {
    
    NSData* data = NULL;
    
     if([[self.info valueForKey: kThumbNailKey] isKindOfClass: NSString.class])
    {
        NSString *thumbnailString = [self.info valueForKey: kThumbNailKey];
         data = [thumbnailString base64Decoded];
    }
   
   return  data;
    
} // -thumbnail




- (void) setThumbnail:(NSData *)thumbnail  {
    
    [self nilJSON];
        
    [self.info setValue: [thumbnail base64Encoded] forKey: kThumbNailKey];
    
} // -setThumbnail:





 

- (BOOL) isFyeo {
    
    NSNumber *fyeo = [self.info valueForKey: kFYEOKey];
    
    return [fyeo isKindOfClass: NSNumber.class] ? fyeo.boolValue : NO;
    
} // -isFyeo


- (BOOL) fyeo {
    
    return self.isFyeo;
    
} // -fyeo


- (void) setFyeo: (BOOL) fyeo {
    
    [self nilJSON];
    
    if (fyeo) {
        
        [self.info setValue: [NSNumber numberWithBool: fyeo] 
                     forKey: kFYEOKey];
    }
    else {
        
        [self.info setValue: nil forKey: kFYEOKey];
    }
    
} // -setFyeo:


- (NSString *) message {
    
    NSString *message = [self.info valueForKey: kMessageKey];
    
    return [message isKindOfClass: NSString.class] ? message : nil;
    
} // -message


- (void) setMessage: (NSString *) message {
    
    [self nilJSON];
    
    [self.info setValue: message forKey: kMessageKey];
    
} // -setMessage:


- (BOOL) isPlainText {
    
    NSNumber *plainText = [self.info valueForKey: kPlainTextKey];
    
    return [plainText isKindOfClass: NSNumber.class] ? plainText.boolValue : NO;
    
} // -isPlainText


- (BOOL) plainText {
    
    return self.isPlainText;
    
} // -plainText


- (void) setPlainText: (BOOL) plainText {
    
    [self nilJSON];
    
    [self.info setValue: [NSNumber numberWithBool: plainText] 
                 forKey: kPlainTextKey];
    
} // -setPlainText:


- (NSString *) receivedID {
    
    NSString *receivedID = [self.info valueForKey: kReceivedIDKey];
    
    return [receivedID isKindOfClass: NSString.class] ? receivedID : nil;
    
} // -receivedID


- (void) setReceivedID: (NSString *) receivedID {
    
    [self nilJSON];
    
    [self.info setValue: receivedID forKey: kReceivedIDKey];
    
} // -setReceivedID:


- (NSDate *) receivedTime {
    
    NSString *receivedTime = [self.info valueForKey: kReceivedTimeKey];

    if ([receivedTime isKindOfClass: NSString.class]) {
        
        NSDate *date = nil;
        
        dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
            
            date = [_siren_dateFormatter dateFromString: receivedTime];
        }
        dispatch_semaphore_signal(_siren_df_semaphore);
        
        return date;
    }
    return nil;
    
} // -receivedTime


- (void) setReceivedTime: (NSDate *) receivedTime {
    
    [self nilJSON];
    
    NSString *receivedString = nil;

    if (receivedTime) {
        
        dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
            
            receivedString = [_siren_dateFormatter stringFromDate: receivedTime];
        }
        dispatch_semaphore_signal(_siren_df_semaphore);
    }
    [self.info setValue: receivedString forKey: kReceivedTimeKey];
    
} // -setReceivedTime:




- (BOOL) isRequestReceipt {
    
    NSNumber *requestReceipt = [self.info valueForKey: kRequestReceiptKey];
    
    return [requestReceipt isKindOfClass: NSNumber.class] ? requestReceipt.boolValue : NO;
    
} // -isRequestReceipt


- (BOOL) requestReceipt {
    
    return self.isRequestReceipt;
    
} // -requestReceipt


- (void) setRequestReceipt: (BOOL) requestReceipt {
    
    [self nilJSON];
    
    [self.info setValue: [NSNumber numberWithBool: requestReceipt] 
                 forKey: kRequestReceiptKey];
    
} // -setRequestReceipt:


- (NSString *) requestResend {
    
    NSString *requestResend = [self.info valueForKey: kRequestResendKey];
    
    return [requestResend isKindOfClass: NSString.class] ? requestResend : nil;
    
} // -requestResend


- (void) setRequestResend: (NSString *) requestResend {
    
    [self nilJSON];
    
    [self.info setValue: requestResend forKey: kRequestResendKey];
    
} // -setRequestResend:


- (NSString *) requestBurn {
    
    NSString *requestBurn = [self.info valueForKey: kRequestBurnKey];
    
    return [requestBurn isKindOfClass: NSString.class] ? requestBurn : nil;
    
} // -requestBurn


- (void) setRequestBurn: (NSString *) requestBurn {
    
    [self nilJSON];
    
    [self.info setValue: requestBurn forKey: kRequestBurnKey];
    
} // -setRequestResend:


- (uint32_t) shredAfter {
    
    NSNumber *timeInterval = [self.info valueForKey: kShredAfterKey];
    
    return [timeInterval isKindOfClass: NSNumber.class] ? timeInterval.unsignedIntValue : 0;
    
} // -shredAfter


- (void) setShredAfter: (uint32_t) shredAfter {
    
    [self nilJSON];
    
    if (shredAfter > 0) {
        
        [self.info setValue: [NSNumber numberWithUnsignedInt: shredAfter] 
                     forKey: kShredAfterKey];
    }
    else if (shredAfter <= 0) {
        
        [self.info setValue: nil forKey: kShredAfterKey];
    }
    
} // -setShredAfter:


#pragma mark - Initializer methods.


+ (Siren *) sirenWithJSONData: (NSData *) jsonData {
    
    return [self.class.alloc initWithJSONData: jsonData];
    
} // +sirenWithJSONData:


+ (Siren *) sirenWithJSON: (NSString *) json {
    
    return [self.class.alloc initWithJSON: json];
    
} // +sirenWithJSON:


+ (Siren *) sirenWithChatMessage: (XMPPMessage *) message {
    
    return [self.class.alloc initWithChatMessage: message];
    
} // +sirenWithChatMessage:


- (Siren *) initWithJSONData: (NSData *) jsonData {
    
//    DDGTrace();
    
    self = [super init];
    
    if (self) {
        
        self.badData = NO;
        
        if (jsonData) {
            
            self.jsonData = jsonData;
            
            NSError *error = nil;
            NSMutableDictionary *info = nil;
            
            info = [NSJSONSerialization JSONObjectWithData: jsonData 
                                                   options: NSJSONReadingMutableContainers 
                                                     error: &error];
            if (error) {
                
                self.badData = YES;
                info = nil;
                [self nilJSON];
            }
            self.info = info ? info : [NSMutableDictionary dictionaryWithCapacity: kNumSirenKeys];
        }
        else {
            
            self.info = [NSMutableDictionary dictionaryWithCapacity: kNumSirenKeys]; // The number of different JSON keys.
        }
    }
    return self;
    
} // -initWithJSONData:


- (BOOL) mayContainJSON: (NSString *) json {
    
    json = [json stringByTrimmingCharactersInSet: NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    if (json.length > 2) { // There must be something in between the [] or {}.
        
        unichar firstChar = [json characterAtIndex: 0];
        unichar  lastChar = [json characterAtIndex: json.length - 1];
        
        return (firstChar == '{' && lastChar == '}') || (firstChar == '[' && lastChar == ']');
    }
    return NO;
    
} // -mayContainJSON:


- (Siren *) initWithJSON: (NSString *) json {

    
    if (json) {
        
        if ([self mayContainJSON: json]) {
            
            const char *utf8String = json.UTF8String;
            
            NSData *data = [NSData dataWithBytesNoCopy: (void *)utf8String 
                                                length: strlen( utf8String) 
                                          freeWhenDone: NO];
            
            Siren *siren = [self initWithJSONData: data];
            
            _json     = json; // Assign the ivar directly; i.e. don't force a reparse of the string.
            _jsonData = nil;  // As the data actually belongs to the string, release the NSData shell.
            
            return siren;
        }
        else {
            
            // Convert the string into proper JSON.
            return [self initWithJSON: [NSString stringWithFormat: 
                                        @"{\"%@\":\"%@\",\"%@\":true}", 
                                        kMessageKey, json, kPlainTextKey]];
        }
    }
    return [self initWithJSONData: nil];
    
} // -initWithJSON:


- (Siren *) initWithChatMessage:  (XMPPMessage *) message {
    
    self.chatMessage = message;
    
    NSString *json = [[message elementForName: kSCPPSiren xmlns: kSCPPNameSpace] stringValue];
    
    return [self initWithJSON: json ? json : [[message elementForName: kXMPPBody] stringValue]];
    
} // -initWithChatMessage:


- (Siren *) init {
    
    return [self initWithJSONData: nil];
    
} // -init


#pragma mark - Instance methods.


- (NSString *) description {
    
    if (self.chatMessage) {
        
        return [NSString stringWithFormat: 
                @"Dictionary: %@; \n\tChat Message:\n%@", 
                self.info.description, self.chatMessage.compactXMLString];
    }
    return self.info.description;
    
} // -description


- (XMPPMessage *) chatMessageToJID: (XMPPJID *) jid
{    
    XMPPMessage  *message = [XMPPMessage messageWithType: kXMPPChat to: jid];
    
    [message addAttributeWithName: kXMPPID stringValue: [XMPPStream generateUUID]];
    
    NSXMLElement * bodyElement = [NSXMLElement.alloc initWithName: kXMPPBody];
    [message addChild: bodyElement];
    
     NSXMLElement *sirenElement = [NSXMLElement.alloc initWithName: kSCPPSiren URI: kSCPPNameSpace];
    sirenElement.stringValue = self.json;
     
    [message addChild: sirenElement];
    

    self.chatMessage = message;
    
    return message;
    
} // -chatMessageToJID


- (XMPPMessage *) chatMessageToJID: (XMPPJID *) jid withPush:(BOOL)withPush withBadge:(BOOL)withBadge
{
    XMPPMessage  *message = [XMPPMessage messageWithType: kXMPPChat to: jid];
    
    [message addAttributeWithName: kXMPPID stringValue: [XMPPStream generateUUID]];
    
    NSXMLElement * bodyElement = [NSXMLElement.alloc initWithName: kXMPPBody];
    [message addChild: bodyElement];
    
    NSXMLElement *sirenElement = [NSXMLElement.alloc initWithName: kSCPPSiren URI: kSCPPNameSpace];
    sirenElement.stringValue = self.json;
     
    [sirenElement addAttributeWithName: kXMPPNotifiable stringValue: withPush?@"true":@"false"];
    [sirenElement addAttributeWithName: kXMPPBadge stringValue:  withBadge?@"true":@"false"];
    
    [message addChild: sirenElement];
     
    self.chatMessage = message;
    
    return message;
    
}


- (XMPPMessage *) multicastChatMessageToJIDs: (NSArray *) jids forThread:(NSString*)threadElement domain:(NSString*)domain
{
    
    NSString* module = [NSString stringWithFormat:@"multicast.%@", domain?domain:@"silentcircle.com"];
    
    XMPPMessage  *message = [XMPPMessage multicastMessageWithType: kXMPPChat jids: jids module:module];
      
    [message addAttributeWithName: kXMPPID stringValue: [XMPPStream generateUUID]];
    
    NSXMLElement * bodyElement = [NSXMLElement.alloc initWithName: kXMPPBody];
    [message addChild: bodyElement];

    if(threadElement)
    {
        message.threadElement  = threadElement;
    }

    NSXMLElement *sirenElement = [NSXMLElement.alloc initWithName: kSCPPSiren URI: kSCPPNameSpace];
    sirenElement.stringValue = self.json;
    [message addChild: sirenElement];
    
    self.chatMessage = message;
    
    return message;
   
}

- (BOOL) isValid
{
    return !self.badData;
}

-(NSData*) sigSHA256Hash
{
    NSData* hashValue = NULL;
    uint8_t hashBytes[32];
    
    if(IsntSCLError( Siren_ComputeHash(kHASH_Algorithm_SHA256,  self.json.UTF8String, hashBytes)))
    {
        hashValue = [NSData dataWithBytes:hashBytes length:32];
    };
            
    return hashValue;
}


@end
