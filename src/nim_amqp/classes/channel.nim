## 
## Implements the `channel` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import ../endian
import ../errors
import ../types

type AMQPChannelError* = object of AMQPError

var channelMethodMap* = MethodMap()


proc sendFrame(conn: AMQPConnection, payload: string, payloadSize: uint32, callback: FrameHandlerProc = nil) = 
    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(payloadSize),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPChannelError, sendRes.result)

    if callback != nil:
        callback(conn)




proc channelOpen*(conn: AMQPConnection) =
    ## Requests for the server to open a new channel (channel.open)