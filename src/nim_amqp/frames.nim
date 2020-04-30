## 
## Utilities for managing AMQP frames
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams
import strformat
import tables

# import ./class
import ./errors
import ./types
import ./endian
import ./content
import ./classes/basic
import ./classes/channel
import ./classes/connection
import ./classes/exchange
import ./classes/queue
import ./classes/tx

type AMQPFrameError* = object of AMQPError

proc handleMethod(chan: AMQPChannel)


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


proc handleFrame*(chan: AMQPChannel, preFetched: string = "") =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5.
    ## `amqpVersion` must be in dotted notation
    ##
    chan.curFrame = AMQPFrame(payloadType: ptStream)
    let conn = chan.conn
    let frame = chan.curFrame
    let stream = newStringStream(preFetched)
    
    # TODO: Handle errors, see 2.3.7 in the spec
    #  This will involve looking for a closed connection, then reading error codes/strings

    # Version negotiation pre-fetches 7B, so we need to account for that
    if preFetched.len == 0:
        stream.write(conn.sock.recv(7, conn.readTimeout))

    stream.setPosition(0)

    frame.frameType = stream.readUint8()
    stream.readNumericEndian(frame.channel)
    stream.readNumericEndian(frame.payloadSize)

    # Frame-end is a single octet that must be set to 0xCE (thus the +1)
    let payload_plus_frame_end = conn.sock.recv(int(frame.payloadSize)+1, conn.readTimeout)
    
    # Ensure the frame-end octet matches the spec
    if byte(payload_plus_frame_end[frame.payloadSize]) != 0xCE:
        raise newException(AMQPFrameError, "Corrupt frame, missing 0xCE ending marker")

    frame.payloadStream = newStringStream(payload_plus_frame_end[0..(frame.payloadSize-1)])

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
        # of 4:
        else:
            raise newException(AMQPFrameError, fmt"Got unexpected frame type '{frame.frameType}'")


proc handleHeartbeat(chan: AMQPChannel) = 
    ## Handles a heartbeat from the server
    ##
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
            raise newException(AMQPFrameError, fmt"Got unknown class ID '{classId}'")
        
