## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net

import ./errors
import ./frames
import ./types
import ./utils

type AMQPProtocolError* = object of AMQPError
type AMQPVersionError* = object of AMQPError

proc newAMQPChannel*(conn: AMQPConnection, number: uint16, reciever: FrameHandlerProc, 
                    sender: FrameSenderProc, framePayloadType = ptStream): AMQPChannel =
    ## Creates a new AMQPChannel object
    ##
    new(result)
    result.conn = conn
    result.number = number
    result.active = true
    result.curFrame = AMQPFrame(payloadType: framePayloadType)
    result.curContentHeader = AMQPContentHeader()
    result.frames = AMQPFrameHandling()
    result.frames.handler = reciever
    result.frames.sender = sender


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 500, readTimeout = 500, 
                       amqpVersion = "0.9.1"): AMQPConnection =
    new(result)

    result.sock = newSocket(buffered=true)
    result.sock.connect(host, Port(port), timeout=connectTimeout)
    result.readTimeout = readTimeout
    result.meta.version = amqpVersion
    result.username = username
    result.password = password

    let sent = result.sock.trySend(wireAMQPVersion(result.meta.version))
    if not sent:
        raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # This is to make sure that the resulting data from the server is properly handled
    result.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).handleFrame

    result.ready = true
