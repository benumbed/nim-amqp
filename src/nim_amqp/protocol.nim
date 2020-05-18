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

proc newAMQPChannel*(conn: AMQPConnection, number: uint16, reciever: FrameHandlerProc, 
                    sender: FrameSenderProc, framePayloadType = ptStream): AMQPChannel =
    ## Creates a new AMQPChannel object
    ##
    new(result)
    result.conn = conn
    result.number = number
    result.active = true
    result.curFrame = AMQPFrame(payloadType: framePayloadType)
    result.frames = AMQPFrameHandling()
    result.frames.handler = reciever
    result.frames.sender = sender


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 500, readTimeout = 500, 
                        maxReconnectAttempts = 3, amqpVersion = "0.9.1", tuning=AMQPTuning(), useTls=false): AMQPConnection =
    new(result)

    result.sock = newSocket(buffered=true)
    result.sock.connect(host, Port(port), timeout=connectTimeout)

    if useTls:
        if not defined(ssl):
            raise newException(AMQPProtocolError, "TLS was requested, but not compiled in, recompile with `-d:ssl`")
        let ctxt = newContext(protTLSv1)
        # Wrapping a non-connected socket didn't work, and I wasn't in the mood to figure out why
        ctxt.wrapConnectedSocket(result.sock, handshakeAsClient)
        if not result.sock.isSsl:
            raise newException(AMQPProtocolError, "The the TLS socket thinks it's not a TLS socket")

    result.connectTimeout = connectTimeout
    result.readTimeout = readTimeout
    result.meta.version = amqpVersion
    result.host = host
    result.port = Port(port)
    result.username = username
    result.password = password
    result.tuning = tuning
    result.maxReconnectAttempts = maxReconnectAttempts

    result.sock.send(wireAMQPVersion(result.meta.version))
    # let sent = result.sock.trySend(wireAMQPVersion(result.meta.version))
    # if not sent:
    #     raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # This is to make sure that the resulting data from the server is properly handled
    result.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).handleFrame

    result.ready = true
