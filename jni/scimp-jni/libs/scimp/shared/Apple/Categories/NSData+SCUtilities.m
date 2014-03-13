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
//  NSData+SCUtilities.m
//  SilentText
//

#include <tomcrypt.h>

#import "NSData+SCUtilities.h"

@implementation NSData (SCUtilities)

- (NSString *)base64Encoded
{
    NSString* encodedString = NULL;
    
    size_t      len     = 0;
    uint8_t     *oBuf   = NULL;
       
    len =  ((((self.length) + 2) / 3) * 4)+1 ;
      
    oBuf = XMALLOC(len);
    if(oBuf)
    {
       *oBuf= 0;
        
        if( base64_encode(self.bytes, self.length, oBuf, &len) == CRYPT_OK)
        {
            encodedString = [NSString.alloc initWithBytesNoCopy: oBuf
                                                  length: len
                                                encoding: NSUTF8StringEncoding
                                            freeWhenDone: YES];
        }
     
    }
      return encodedString;
}




+ (NSData *)dataFromBase64EncodedString:(NSString *)aString
{
    
    NSData      *dataOut = NULL;
    
    size_t      bufLen =  aString.length ;  // oversize it
    uint8_t     *oBuf =  XMALLOC(bufLen);
    
    if( base64_decode((const unsigned char*) aString.UTF8String,  aString.length, oBuf, &bufLen) == CRYPT_OK)
    {
        dataOut = [NSData.alloc initWithBytesNoCopy: oBuf
                                                     length: bufLen
                                                freeWhenDone: YES];

    }
    
    return dataOut;
}


@end
