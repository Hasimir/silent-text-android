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
//  Created by Vinnie Moscaritolo on 2/18/13.
//  Copyright (c) 2013 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SCimp.h>

#import "XMPPFramework.h"
#import "XMPPSilentCircle.h"

@protocol XMPPStreamManagerDelegate;

@interface XMPPStreamManager : NSObject <XMPPStreamDelegate, XMPPReconnectDelegate>

@property (strong, nonatomic) id<XMPPSilentCircleStorageDelegate> xmppSilentCircleStorage;
@property (strong, nonatomic) XMPPSilentCircle *xmppSilentCircle;
@property (strong, nonatomic) XMPPStream *xmppStream;

@property (strong,  nonatomic) id<XMPPStreamManagerDelegate> delegate;


- (id)initWithDelegate:(id)aDelegate;

- (BOOL) connectAsJID: (XMPPJID*)JID  password:(NSString*)password;

- (void) setStreamParams: (NSDictionary*) paramDict;

- (void) disconnect;
- (void) disconnectAfterSending;

-(BOOL) isConnected;

@end


@protocol XMPPStreamManagerDelegate  <NSObject>
@required

- (void)xmppSilentCircle:(XMPPStreamManager *)sender willGoOnline:(XMPPJID*)JID ;
- (void)xmppSilentCircle:(XMPPStreamManager *)sender willGoOffline:(XMPPJID*)JID ;
- (void)xmppSilentCircle:(XMPPStreamManager *)sender didSecureWithCertificate:(NSData *)serverCertificateData;

@end
