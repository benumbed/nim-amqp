## 
## Utilities for managing AMQP frames
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import nativesockets
import net
import streams
import strformat
import tables

import ./content
import ./endian
import ./errors
import ./types
import ./utils
import ./classes/basic
import ./classes/channel
import ./classes/connection
import ./classes/exchange
import ./classes/queue
import ./classes/tx

type AMQPFrameError* = object of AMQPError

proc handleMethod(chan: AMQPChannel)
proc handleHeartbeat(chan: AMQPChannel)


proc sendFrame*(chan: AMQPChannel, frame: AMQPFrame = nil): StrWithError =
    ## Sends a pre-formatted AMQP frame to the server
    ##
    let conn = chan.conn
    let frame = if isnil frame: chan.curFrame else: frame
    let stream = newStringStream()

    stream.write(frame.frameType)
    stream.write(frame.channel)

    # TODO: Should only read from the stream in chunks that match the size we negotiated with the server. Extra chunks
    #       require more sends (trigger another sendFrame if the stream isn't at end, or we haven't written the entire
    #       payload string)
    case frame.payloadType:
    of ptStream:
        let payloadStr = frame.payloadStream.readAll()
        stream.write(swapEndian(uint32(payloadStr.len)))
        if payloadStr.len > 0:
            stream.write(payloadStr)
    of ptString:
        stream.write(frame.payloadSize)
        if frame.payloadSize > 0:
            stream.write(frame.payloadString)
    
    # Note to future self: write treats 0xCE as 32b, that's why we need the cast
    stream.write(uint8(0xCE))
    stream.setPosition(0)

    try:
        conn.sock.send(stream.readAll())
    except OSError as e:
        return (fmt"Failed to send AMQP frame: {e.msg}", true)
    finally:
        stream.close()
    
    return ("", false)


proc handleFrame*(chan: AMQPChannel, blocking = true) =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5.
    ##
    chan.curFrame = AMQPFrame(payloadType: ptStream)
    let conn = chan.conn
    let frame = chan.curFrame
    frame.payloadStream = newStringStream()

    # We only block if requsted AND there's no data buffered AND the connection to the server has been fully 
    # established/negotiated
    if blocking and chan.active and chan.conn.ready and not chan.conn.sock.hasDataBuffered:
        var sockFd = @[chan.conn.sock.getFd]
        discard selectRead(sockFd, -1)
    
    var initialData: Stream
    try:
        initialData = newStringStream(conn.sock.recv(8, conn.readTimeout))
    except TimeoutError:
        if not chan.active or not chan.conn.ready:
            raise
        return

    if initialData.atEnd and initialData.getPosition() == 0:
        raise newException(AMQPSocketClosedError, "Server unexpectedly closed the connection")

    # If this is the first 'frame' we've handled, we have to make sure the server's not attempting to do a 
    # version renegotiation
    if chan.active and not chan.conn.ready and initialData.peekStr(4) == "AMQP":
        raise newException(AMQPVersionError, 
                fmt"Server does not support {conn.meta.version}, sent: {initialData.readAll().readRawAMQPVersion()}")

    # TODO: Handle errors, see 2.3.7 in the spec
    #  This will involve looking for a closed connection, then reading error codes/strings

    initialData.setPosition(0)

    frame.frameType = initialData.readUint8()
    initialData.readNumericEndian(frame.channel)
    initialData.readNumericEndian(frame.payloadSize)

    if frame.payloadSize != 0:
        # We've already fetched 8 bytes above (7+1), so we skip adding an extra byte of fetch here for 0xCE
        let data = conn.sock.recv(int(frame.payloadSize), conn.readTimeout)

        # Ensure the frame-end octet matches the spec
        if byte(data[frame.payloadSize-1]) != 0xCE:
            raise newException(AMQPFrameError, "Corrupt frame, missing 0xCE ending marker")

        frame.payloadStream.write(initialData.readUint8)
        frame.payloadStream.write(data[0..(frame.payloadSize-1)])   # We don't write the 0xCE to the stream
        frame.payloadStream.setPosition(0)

    case frame.frameType:
        of FRAME_METHOD:
            chan.handleMethod()
        of FRAME_CONTENT_HEADER:
            chan.handleContentHeader()
        of FRAME_CONTENT_BODY:
            chan.handleContentBody()
        of FRAME_HEARTBEAT:
            chan.handleHeartbeat()
        else:
            raise newException(AMQPFrameError, fmt"Got unexpected frame type '{frame.frameType}'")


proc handleHeartbeat(chan: AMQPChannel) = 
    ## Handles a heartbeat from the server (just sends a heartbeat frame back, no error checking ATM)
    ##
    chan.curFrame = AMQPFrame(payloadType: ptString, frameType: FRAME_HEARTBEAT, channel: 0, payloadString: "")
    let res = chan.sendFrame()
    if res.error:
        error "Problem sending AMQP heartbeat", error=res.result
    else:
        debug "Sent AMQP heartbeat"


proc handleMethod(chan: AMQPChannel) = 
    ## Method dispatcher
    ##
    let frame = chan.curFrame
    let classId = swapEndian(frame.payloadStream.readUint16())
    let methodId = swapEndian(frame.payloadStream.readUint16())

    case classId:
        of uint16(10):
            connectionMethodMap[methodId](chan)
        of uint16(20):
            channelMethodMap[methodId](chan)
        of uint16(40):
            exchangeMethodMap[methodId](chan)
        of uint16(50):
            queueMethodMap[methodId](chan)
        of uint16(60):
            basicMethodMap[methodId](chan)
        of uint16(70):
            txMethodMap[methodId](chan)
        else:
            raise newAMQPException(AMQPFrameError, fmt"Got unknown class ID '{classId}'", classID, methodID)
