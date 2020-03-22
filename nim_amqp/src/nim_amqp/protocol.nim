## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams

import ./utils
import ./errors

let AMQP_VERSION = "AMQP\0\0\9\1"

type AMQPProtocolError* = object of AMQPError

type AMQPFrame* = ref object of RootObj
    frameType*: uint8
    channel*: uint16
    payloadSize*: uint32
    payload*: Stream

proc readFrame*(sock: Socket, read_timeout: int=500): AMQPFrame =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5

    # FIXME: This does not belong here, it should only be called during connection setup
    let sent = sock.trySend(AMQP_VERSION)
    if not sent:
        raise newException(AMQPProtocolError, "Failed to send AMQP version string")
    
    # Read only the header
    let header = newStringStream(sock.recv(7, read_timeout))
    if header.atEnd():
        raise newException(AMQPProtocolError, "Response from server was empty")

    new(result)
    result.frameType = header.readUint8()
    result.channel = header.readUint16Endian()
    result.payloadSize = header.readUint32Endian()

    # Frame-end is a single octet that must be set to 0xCE
    let payload_plus_frame_end = sock.recv(int(result.payloadSize)+1, read_timeout)
    # Ensure the frame-end octet matches the spec
    
    if byte(payload_plus_frame_end[result.payloadSize]) != 0xCE:
        raise newException(AMQPProtocolError, "Corrupt frame, missing 0xCE ending marker")

    result.payload = newStringStream(payload_plus_frame_end[0..(result.payloadSize-1)])


proc readTLSFrame*(): string = 
    ## Reads an AMQP frame from a TLS encrypted session
    raise newException(Exception, "not implemented")