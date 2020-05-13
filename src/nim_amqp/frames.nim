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


proc waitForFrame*(chan: AMQPChannel, timeout = -1) = 
    ## Blocks while waiting for data on the wire.  If `timeout` is -1, this method will block indefinitely.
    ##
    var sockFd = @[chan.conn.sock.getFd]
    discard selectRead(sockFd, timeout)


proc sendFrame*(chan: AMQPChannel): StrWithError =
    ## Sends a pre-formatted AMQP frame to the server
    ##
    let conn = chan.conn
    let frame = chan.curFrame
    let stream = newStringStream()

    stream.write(frame.frameType)
    stream.write(frame.channel)

    case frame.payloadType:
    of ptStream:
        let payloadStr = frame.payloadStream.readAll()
        stream.write(swapEndian(uint32(len(payloadStr))))
        stream.write(payloadStr)
    of ptString:
        stream.write(frame.payloadSize)
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

    # We've already fetched 8 bytes above (7+1), so we skip adding an extra byte of fetch here for 0xCE
    let data = conn.sock.recv(int(frame.payloadSize), conn.readTimeout)
    
    # Ensure the frame-end octet matches the spec
    if byte(data[frame.payloadSize-1]) != 0xCE:
        raise newException(AMQPFrameError, "Corrupt frame, missing 0xCE ending marker")

    frame.payloadStream.write(initialData.readUint8)
    frame.payloadStream.write(data[0..(frame.payloadSize-1)])   # We don't write the 0xCE to the stream
    frame.payloadStream.setPosition(0)

    case frame.frameType:
        # METHOD
        of 1:
            chan.handleMethod()
        # CONTENT HEADER
        of 2:
            chan.handleContentHeader()
        # CONTENT BODY
        of 3:
            chan.handleContentBody()
        # HEARTBEAT
        of 4:
            chan.handleHeartbeat()
        else:
            raise newException(AMQPFrameError, fmt"Got unexpected frame type '{frame.frameType}'")


proc handleHeartbeat(chan: AMQPChannel) = 
    ## Handles a heartbeat from the server
    ##
    warn "Got a heartbeat but there's no handler yet"
    return


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
