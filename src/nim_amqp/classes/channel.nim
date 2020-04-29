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

proc channelOpenOk*(chan: var AMQPChannel, stream: Stream)
proc channelFlowOk*(chan: var AMQPChannel, stream: Stream)
proc channelClose*(chan: var AMQPChannel, stream: Stream)
proc channelCloseOk*(chan: var AMQPChannel)
proc channelCloseOk*(chan: var AMQPChannel, stream: Stream)

####
### ME: Working on tying state together, like tracking channels and such, the AMQPCommunication tuple is gross
####

var channelMethodMap*: Table[uint16, proc(chan: var AMQPChannel, stream: Stream)]
channelMethodMap[11] = channelOpenOk
channelMethodMap[21] = channelFlowOk
channelMethodMap[40] = channelClose
channelMethodMap[41] = channelCloseOk


proc sendFrame(chan: AMQPChannel, payload: string, callback: FrameHandlerProc = nil) = 
    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(chan.number),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(payload))),
        payloadString: payload
    )

    let sendRes = chan.conn.frames.sender(chan.conn, frame)
    if sendRes.error:
        raise newException(AMQPChannelError, sendRes.result)

    if callback != nil:
        callback(chan.conn)




proc channelOpen*(chan: AMQPChannel) =
    ## Requests for the server to open a new channel, `channelNum` (channel.open)
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(10)))

    stream.write(uint8(len("")))
    stream.write("")
    stream.setPosition(0)

    debug "Opening channel", channel=chan.number
    chan.sendFrame(stream.readAll(), callback=chan.conn.frames.handler)


proc channelOpenOk*(chan: var AMQPChannel, stream: Stream) =
    ## Handles a 'channel.open-ok' from the server
    ##
    chan.active = true
    chan.flow = true

    debug "Opened channel", channel=chan.number


proc channelFlow*(chan: AMQPChannel, flow: bool) =
    ## Requests for the server to stop the flow of messages to this channel
    ## NOTE: RabbitMQ does not support flow control using channel.flow
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(20)))

    stream.write(uint8(flow))
    stream.setPosition(0)

    debug "Sending channel flow control request", channel=chan.number, flow=flow
    chan.sendFrame(stream.readAll(), callback=chan.conn.frames.handler)


proc channelFlowOk*(chan: var AMQPChannel, stream: Stream) =
    ## Handles a 'connection.flow-ok' from the server
    ## NOTE: RabbitMQ does not support flow control using channel.flow
    ##
    chan.flow = bool(stream.readUint8())
    
    if not chan.active:
        raise newException(AMQPChannelError, fmt"Recieved a flow control message for a channel that is not active ({chan.number})")

    debug "Server confirmed flow control request", channel=chan.number, flow=chan.flow


proc channelClose*(chan: AMQPChannel, reply_code: uint16 = 200, reply_text="Normal shutdown", 
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

    debug "Closing channel", channel=chan.number
    chan.sendFrame(stream.readAll(), callback=chan.conn.frames.handler)


proc channelClose*(chan: var AMQPChannel, stream: Stream) = 
    ## Server is requesting the client to close a channel (channel.close)
    ##
    let code = swapEndian(stream.readUint16())
    let reason = stream.readStr(int(stream.readUint8()))

    let class = swapEndian(stream.readUint16())
    let meth = swapEndian(stream.readUint16())

    debug "Server requested to close channel", code=code, reason=reason, class=class, meth=meth
    chan.channelCloseOk()


proc channelCloseOk*(chan: var AMQPChannel) =
    ## Send a 'channel.close-ok' to the server
    ## 
    let stream = newStringStream()

    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(41)))

    stream.setPosition(0)

    debug "Telling server it's ok to close channel", channel=chan.number
    chan.active = false
    chan.sendFrame(stream.readAll(), callback=chan.conn.frames.handler)


proc channelCloseOk*(chan: var AMQPChannel, stream: Stream) = 
    ## Server responding to a channel close (channel.close-ok)
    ##
    chan.active = false
    debug "Successfully closed channel", channel=chan.number
