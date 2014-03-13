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

#ifndef Included_SCimpPriv_h	/* [ */
#define Included_SCimpPriv_h

#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCkeys.h"
#include "SCimp.h"

#include <pthread.h> 
#include <sys/types.h>


#if DEBUG 
#define DEBUG_PROTOCOL 1
#define DEBUG_STATES  1
#define DEBUG_PACKETS 1
#define DEBUG_CRYPTO   1
#endif

#define validateSCimpContext( s )		\
ValidateParam( scimpContextIsValid( s ) )


#define SCIMP_KEY_LEN           64
#define SCIMP_MAC_LEN           8
#define SCIMP_HASH_LEN          32

#define SCIMP_HTOTAL_BITS       256
#define SCIMP_HASH_PATH_BITS    256

#define SCIMP_TAG_LEN           8
#define SCIMP_RCV_QUEUE_SIZE    16
#define SCIMP_RCV_QUEUE_GARBAGE_TOLERANCE   4

#define SCIMP_STATE_TAG_LEN     16          /* used for saving state */
#define DEFAULT_MESSAGE_FORMAT_USE_JSON 1

#define PK_ALLOC_SIZE 256

#define kSCimpProtocolVersion1   0x01
#define kSCimpProtocolVersion2  0x02

#pragma pack(push, 1)

enum SCimpMsg_Type_
{
    kSCimpMsg_Invalid    = 0,
    kSCimpMsg_Commit     = 10,
    kSCimpMsg_DH1        = 11,
    kSCimpMsg_DH2        = 12,
    kSCimpMsg_Confirm    = 13,
    

    kSCimpMsg_Data       = 20,
    kSCimpMsg_PubData    = 21,
    kSCimpMsg_PKstart    = 22,
    kSCimpMsg_PKdh1      = 23,
    kSCimpMsg_PKdh2      = 24,
    kSCimpMsg_PKconfirm  = 25,

    kSCimpMsg_ClearText   = 30,
    
    ENUM_FORCE( SCimpMsg_Type_ )
};
ENUM_TYPEDEF( SCimpMsg_Type_, SCimpMsg_Type   );


typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
    uint8_t        sasMethod;
    
    char           *locator;
    uint8_t        *pk;
    size_t         pkLen;

    uint8_t        Hpki[SCIMP_HASH_LEN];

    uint16_t       seqNum;
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg;
    size_t         msgLen;

} SCimpMsg_PKstart;


typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
    uint8_t        sasMethod;
    uint8_t        Hpki[SCIMP_HASH_LEN];
    uint8_t        Hcs[SCIMP_MAC_LEN];
} SCimpMsg_Commit;


typedef struct  {
    uint8_t        *pk;
    size_t         pkLen;
    uint8_t        Hcs[SCIMP_MAC_LEN];
} SCimpMsg_DH1;

typedef struct  {
    uint8_t        *pk;
    size_t         pkLen;
    uint8_t        Maci[SCIMP_MAC_LEN];
} SCimpMsg_DH2;

typedef struct  {
    uint8_t        Macr[SCIMP_MAC_LEN];
} SCimpMsg_Confirm;

typedef struct  {
    uint16_t       seqNum;
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg; 
    size_t         msgLen;
    
 } SCimpMsg_Data;


typedef struct  {
    uint8_t        *msg; 
    size_t         msgLen;
} SCimpMsg_ClearTxt;

typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
     
    char           *locator;
    uint8_t         *esk;
    size_t          eskLen;
    
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg;
    size_t         msgLen;
} SCimpMsg_PubData;

#pragma pack(pop)
 
typedef struct SCimpMsg  * SCimpMsgPtr;

typedef struct SCimpMsg 
{
    SCimpMsgPtr             next;
    SCimpMsg_Type           msgType;
    void*                   userRef;
     union
    {
        SCimpMsg_Commit     commit;
        SCimpMsg_PKstart    pkstart;
        SCimpMsg_DH1        dh1;
        SCimpMsg_DH2        dh2;
        SCimpMsg_Confirm    confirm;
        SCimpMsg_Data       data;
        SCimpMsg_ClearTxt   clearTxt;
        SCimpMsg_PubData    pubData;
     };
    
}SCimpMsg;


/*____________________________________________________________________________
 SCimp Context	
 ____________________________________________________________________________*/


enum SCimpTransition_
{
    kSCimpTrans_NULL             = 0,
    kSCimpTrans_StartDH,            
    kSCimpTrans_RCV_PKStart,
  
    kSCimpTrans_RCV_Commit,
    kSCimpTrans_RCV_DH1,
    kSCimpTrans_RCV_DH2 ,
    kSCimpTrans_RCV_Confirm ,
    kSCimpTrans_SND_Confirm,
 
    kSCimpTrans_SND_Data,
    kSCimpTrans_RCV_Data,

    kSCimpTrans_RCV_ClearText,
    kSCimpTrans_RCV_PubData,

    kSCimpTrans_Complete ,
    kSCimpTrans_Reset ,
    kSCimpTrans_StartPubKey,
    
    ENUM_FORCE( SCimpTransitionType_ )
};

ENUM_TYPEDEF( SCimpTransition_, SCimpTransition   );


#define TRANS_QUEUESIZE       10

typedef struct  {
    SCimpTransition trans;
    SCimpMsg        *msg;
} TransItem;

typedef struct {
    TransItem q[TRANS_QUEUESIZE+1];		 
    int first;                          
    int last;                       
    int count;                      
} TransQueue;


typedef struct SCimpContext    SCimpContext;

typedef SCLError (*SCIMPSerializeHandler)
        ( SCimpContext *ctx, SCimpMsg *msg,  uint8_t **outData, size_t *outSize);
typedef 
SCLError (*SCIMPDeserializeHandler)
        ( SCimpContext *ctx,  uint8_t *inData, size_t inSize, SCimpMsg **msg);

#define kSCimpContextMagic		0x53436950  
#define kSCimpVersion            0x01
#define kSCimpBlobVersion        0x08



struct SCimpContext
{
    uint32_t                 magic;
    uint8_t                  version;        /* protocol version */
    
    TransQueue               transQueue;     /* state transition Queue */
    pthread_mutex_t          mp;             /* state Mutext */
    
    /* stuff we need to maintain state */
    SCimpState              state;          /* State of this end */
    SCimpMethod             method;         
    SCimpCipherSuite        cipherSuite;
    SCimpSAS                sasMethod;
    SCimpMsgFormat          msgFormat;
    uint8_t                 SessionID[SCIMP_HASH_LEN];  /* H(meStr ||youStr) */
   
    uint8_t                 rcvIndex;                  /* last rcv key calculated */
    struct
    {
        uint8_t             key[SCIMP_KEY_LEN];     /* Key used for Receiving messages */
        uint64_t            index;                  /* message index for Receiving messages */
       }Rcv[SCIMP_RCV_QUEUE_SIZE];
    
    uint8_t                 Ksnd[SCIMP_KEY_LEN];    /* Key used forsending messages */
    uint64_t                Isnd;                   /* message index for Sending messages */
    uint16_t                Ioffset;                /* seq number offset, used in Symmetric key mode only */
    
    uint8_t                 Cs[SCIMP_KEY_LEN];   /* Cached shared secret */
    uint8_t                 Cs1[SCIMP_KEY_LEN];  /* possible  next  shared secret */
    
    bool                    isInitiator;    /* this is the initiator */
    bool                    hasCs;          /* has existing shared secret */
    bool                    csMatches;      /* hashes of cached shared secret match */
    
    bool                    hasKeys;          /* calculated new keys */
    char*                   meStr;          /* My identifying Info String*/
    char*                   youStr;
     bool                    wantsTransEvents;   /* application wants transition events */
      
    /* stuff needed to complete KEYING  - can be jetisoned after keying*/
    uint8_t                 Kdk2    [SCIMP_HASH_PATH_BITS / 8];
    size_t                  KdkLen;
    uint8_t *               ctxStr;
    size_t                  ctxStrLen;

    ECC_ContextRef          privKey0;        /* our private key used to initiate a public Key packett */
    ECC_ContextRef          privKeyDH;        /* our private key for for DH work */
    ECC_ContextRef          pubKey;         /* other party public key */
    char*                   pubKeyLocator;  /* other parties public key locator */

    HASH_ContextRef         HtotalState;            /* hash context of SCimp packets */
    uint8_t                 Hcs[SCIMP_MAC_LEN];     /* Hash shared secret from other party */
    uint8_t                 Hpki[SCIMP_HASH_LEN];   /* Hash of Initiators's public Key */
    uint8_t                 MACi[SCIMP_MAC_LEN];    /* MAC of Initiator  */
    uint8_t                 MACr[SCIMP_MAC_LEN];    /* MAC of REsponder  */
    uint64_t                SAS ;                   /* Short Auth String  20 bits */
    
    /* for SCIMP2  pubkey keying */
    SCKeyContextRef         scKey;
      
    ScimpEventHandler       handler;        /* event callback handler */
    void*                   userValue;      
    
    SCIMPSerializeHandler       serializeHandler;
    SCIMPDeserializeHandler     deserializeHandler;
};

void scResetSCimpContext(SCimpContext *ctx, bool resetAll);
bool isValidSASMethod( SCimpSAS method );
bool isValidCipherSuite(SCimpContext* ctx, SCimpCipherSuite suite );
int  scSCimpCipherBits(SCimpCipherSuite  suite);
int sECCDH_Bits(SCimpCipherSuite  suite);
SCLError  sComputeKeysSymmetric(SCimpContext* ctx, const char* threadStr, SCKeyContextRef key);
SCLError sMakeHash(SCimpCipherSuite suite, const unsigned char *in, unsigned long inlen, unsigned long outLen, uint8_t *out);

#define SERIALIZE_SCIMP(_CTX, _MSG, _OUT, _LEN) (ctx->serializeHandler)(_CTX, _MSG, _OUT, _LEN)
#define DESERIALIZE_SCIMP(_CTX, _IN, _LEN, _MSG) (ctx->deserializeHandler)(_CTX, _IN, _LEN, _MSG)


SCLError scSendPublicDataInternal(SCimpContext*     ctx,
                              SCKeyContextRef   pubKey,
                                 uint8_t        *in,
                                 size_t         inLen,
                                 void*          userRef );

SCLError scSendScimpDataInternal(SCimpContext* ctx,
                                 uint8_t     *in, 
                                 size_t     inLen,
                                 void*      userRef );

SCLError scSendScimpPKstartInternal(SCimpContext* ctx,
                                    uint8_t     *in,
                                    size_t     inLen,
                                    void*      userRef);

SCLError scTriggerSCimpTransition(SCimpContextRef scimp, 
                                   SCimpTransition trans, SCimpMsg* msg);

bool    scimpContextIsValid( const SCimpContext * ref);
bool    isScimpSymmetric(SCimpContext* ctx);

SCLError scEventOutput(
                  SCimpContextRef   ctx,
                  uint8_t*            data, 
                  size_t              dataLen);

SCLError scEventKeyed( SCimpContextRef   ctx);

SCLError scEventReKeying( SCimpContextRef   ctx);

SCLError scEventWarning(
                       SCimpContextRef   ctx,
                       SCLError          warning,
                       void*             userRef
                       );


SCLError scEventError(
                      SCimpContextRef   ctx,
                      SCLError          error,
                      void*             userRef
                      );

SCLError scEventNull(    SCimpContextRef   ctx );

SCLError scEventTransition(SCimpContextRef   ctx, SCimpState state );

SCLError scEventAdviseSaveState( SCimpContextRef   ctx);

void scimpFreeMessageContent(SCimpMsg *msg);

#if SUPPORT_XML_MESSAGE_FORMAT

SCLError scimpSerializeMessageXML( SCimpContext *ctx, SCimpMsg *msg,  uint8_t **outData, size_t *outSize);

SCLError scimpDeserializeMessageXML( SCimpContext *ctx,  uint8_t *inData, size_t inSize, SCimpMsg **msg);

#endif


SCLError scimpSerializeMessageJSON( SCimpContext *ctx, SCimpMsg *msg,  uint8_t **outData, size_t *outSize);

SCLError scimpDeserializeMessageJSON( SCimpContext *ctx,  uint8_t *inData, size_t inSize, SCimpMsg **msg);

SCLError scimpSerializeStateJSON(uint8_t* stateInfo, size_t statelen, 
                                  uint8_t *tag, size_t tagLen, 
                                  uint8_t **outData, size_t *outSize);

SCLError scimpDeserializeStateJSON(uint8_t *inData, size_t inSize, 
                                    uint8_t *outTag, size_t *outTagLen, 
                                    uint8_t **outData, size_t *outSize);

 

#endif /* Included_SCimpPriv_h */ /* ] */
