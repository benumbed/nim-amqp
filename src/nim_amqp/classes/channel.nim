## 
## Implements the `channel` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import tables

import ../endian
import ../errors
import ../types

type AMQPChannelError* = object of AMQPError

proc channelOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16)

var channelMethodMap* = MethodMap()
channelMethodMap[11] = channelOpenOk


proc sendFrame(conn: AMQPConnection, payload: string, channel: uint16 = 0, callback: FrameHandlerProc = nil) = 
    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(channel),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(payload))),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPChannelError, sendRes.result)

    if callback != nil:
        callback(conn)




proc channelOpen*(conn: AMQPConnection, channelNum: uint16) =
    ## Requests for the server to open a new channel, `channelNum` (channel.open)
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(uint16(20)))
    stream.write(swapEndian(uint16(10)))

    stream.write(uint8(len("")))
    stream.write("")
    stream.setPosition(0)

    sendFrame(conn, stream.readAll(), channel=channelNum, callback=conn.frameHandler)


proc channelOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'connection.ok' from the server
    if channel in conn.openChannels:
        raise newException(AMQPChannelError, fmt"New channel {channel} was already tracked in connection.  This is a code bug!")
    conn.openChannels.add(channel)
