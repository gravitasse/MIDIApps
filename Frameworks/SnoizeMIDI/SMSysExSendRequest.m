#import "SMSysExSendRequest.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMEndpoint.h"
#import "SMSystemExclusiveMessage.h"


@interface SMSysExSendRequest (Private)

static void completionProc(MIDISysexSendRequest *request);
- (void)_completionProc;

@end


@implementation SMSysExSendRequest

DEFINE_NSSTRING(SMSysExSendRequestFinishedNotification);

+ (SMSysExSendRequest *)sysExSendRequestWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(SMDestinationEndpoint *)endpoint;
{
    return [[[self alloc] initWithMessage:aMessage endpoint:endpoint] autorelease];
}

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(SMDestinationEndpoint *)endpoint;
{
    if (![super init])
        return nil;

    OBASSERT(aMessage != nil);
    
    message = [aMessage retain];
    fullMessageData = [[message fullMessageData] retain];

    request.destination = [endpoint endpointRef];
    request.data = (Byte *)[fullMessageData bytes];
    request.bytesToSend = [fullMessageData length];
    request.complete = FALSE;
    request.completionProc = completionProc;
    request.completionRefCon = self;

    return self;
}

- (id)init;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [message release];
    message = nil;
    [fullMessageData release];
    fullMessageData = nil;

    [super dealloc];
}

- (SMSystemExclusiveMessage *)message;
{
    return message;
}

- (void)send;
{
    OSStatus status;

    // Retain ourself, so we are guaranteed to stick around while the send is happening.
    // When we are notified that the request is finished, we will release ourself.
    [self retain];
    
    status = MIDISendSysex(&request);
    if (status) {
        NSLog(@"MIDISendSysex() returned error: %ld", status);
        [self release];
    }
}

- (BOOL)cancel;
{
    if (request.complete)
        return NO;

    request.complete = TRUE;
    return YES;
}

- (unsigned int)bytesRemaining;
{
    return request.bytesToSend;
}

- (unsigned int)totalBytes;
{
    return [fullMessageData length];
}

- (unsigned int)bytesSent;
{
    unsigned int totalBytes, bytesRemaining;

    totalBytes = [self totalBytes];
    bytesRemaining = [self bytesRemaining];
    OBASSERT(totalBytes >= bytesRemaining);

    return totalBytes - bytesRemaining;
}

- (BOOL)wereAllBytesSent;
{
    return ([self bytesRemaining] == 0);
}

@end


@implementation SMSysExSendRequest (Private)

static void completionProc(MIDISysexSendRequest *request)
{
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];    
    [(SMSysExSendRequest *)(request->completionRefCon) _completionProc];
    [pool release];
}

- (void)_completionProc;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMSysExSendRequestFinishedNotification object:self];
    [self release];
}

@end
