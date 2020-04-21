## 
## Implements the `channel` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import strformat
import tables

import ../endian
import ../errors
import ../types

const CLASS_ID: uint16 = 20

type AMQPChannelError* = object of AMQPError

proc channelOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc channelFlowOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc channelClose*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc channelCloseOk*(conn: AMQPConnection, channel: uint16)
proc channelCloseOk*(conn: AMQPConnection, stream: Stream, channel: uint16)

var channelMethodMap* = MethodMap()
channelMethodMap[11] = channelOpenOk
channelMethodMap[21] = channelFlowOk
channelMethodMap[40] = channelClose
channelMethodMap[41] = channelCloseOk


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
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(10)))

    stream.write(uint8(len("")))
    stream.write("")
    stream.setPosition(0)

    debug "Opening channel", channel=channelNum
    sendFrame(conn, stream.readAll(), channel=channelNum, callback=conn.frameHandler)


proc channelOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'channel.open-ok' from the server
    if channel in conn.openChannels:
        raise newException(AMQPChannelError, fmt"New channel {channel} was already tracked in connection.  This is a code bug!")
    conn.openChannels.add(channel, AMQPChannelMeta(active: true, flow: true))
    debug "Opened channel", channel=channel


proc channelFlow*(conn: AMQPConnection, flow: bool, channel: uint16) =
    ## Requests for the server to open a new channel, `channelNum` (channel.open)
    ## NOTE: RabbitMQ does not support flow control using channel.flow
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(20)))

    stream.write(uint8(flow))
    stream.setPosition(0)

    debug "Sending channel flow control request", channel=channel, flow=flow
    sendFrame(conn, stream.readAll(), channel=channel, callback=conn.frameHandler)


proc channelFlowOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'connection.flow-ok' from the server
    ## NOTE: RabbitMQ does not support flow control using channel.flow
    if channel notin conn.openChannels:
        raise newException(AMQPChannelError, fmt"Recieved a flow control message for a channel that is not tracked ({channel})")
    elif not conn.openChannels[channel].active:
        raise newException(AMQPChannelError, fmt"Recieved a flow control message for a channel that is not active ({channel})")

    conn.openChannels[channel].flow = stream.readBool()
    debug "Server confirmed flow control", channel=channel, flow=conn.openChannels[channel].flow


proc channelClose*(conn: AMQPConnection, channelNum: uint16, reply_code: uint16 = 200, reply_text="Normal shutdown", 
                    classId, methodId: uint16 = 0) = 
    ## Requests for the the server to close a channel (channel.close)
    ## 
    let stream = newStringStream()

    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(40)))

    stream.write(swapEndian(reply_code))
    stream.write(uint8(len(reply_text)))
    stream.write(reply_text)

    stream.write(swapEndian(classId))
    stream.write(swapEndian(methodId))

    stream.setPosition(0)

    debug "Closing channel", channel=channelNum
    sendFrame(conn, stream.readAll(), channelNum, callback=conn.frameHandler)


proc channelClose*(conn: AMQPConnection, stream: Stream, channel: uint16) = 
    ## Server is requesting the client to close a channel (channel.close)
    ##
    let code = swapEndian(stream.readUint16())
    let reason = stream.readStr(int(stream.readUint8()))

    let class = swapEndian(stream.readUint16())
    let meth = swapEndian(stream.readUint16())

    debug "Server requested to close channel", code=code, reason=reason, class=class, meth=meth
    channelCloseOk(conn, channel)


proc channelCloseOk*(conn: AMQPConnection, channel: uint16) =
    ## Send a 'channel.close-ok' to the server
    ## 
    let stream = newStringStream()

    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(41)))

    stream.setPosition(0)

    debug "Telling server it's ok to close channel", channel=channel
    sendFrame(conn, stream.readAll(), channel, callback=conn.frameHandler)


proc channelCloseOk*(conn: AMQPConnection, stream: Stream, channel: uint16) = 
    ## Server responding to a channel close (channel.close-ok)
    ##
    debug "Successfully closed channel", channel=channel
    conn.openChannels.del(channel)
