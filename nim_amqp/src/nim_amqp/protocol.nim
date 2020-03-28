## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams
import strformat

import ./utils
import ./errors

type AMQPProtocolError* = object of AMQPError
type AMQPVersionError* = object of AMQPError

type AMQPFrame* = object
    frameType*: uint8
    channel*: uint16
    payloadSize*: uint32
    payload*: Stream

type AMQPConnection* = object
    readTimeout*: int
    sock: Socket
    version*: string
    stream*: Stream


proc negotiateVersion*(conn: AMQPConnection, amqpVersion: string, readTimeout=500)


proc newAMQPConnection*(host: string, port = 5672, connectTimeout = 100, readTimeout = 500, amqpVersion = "0.9.1"): AMQPConnection =
    var sock = newSocket(buffered=true)
    sock.connect(host, Port(5672), timeout=connectTimeout)
    result.readTimeout = readTimeout
    result.sock = sock
    result.version = amqpVersion
    result.stream = newStringStream()

    result.negotiateVersion(amqpVersion, readTimeout)


proc negotiateVersion(conn: AMQPConnection, amqpVersion: string, readTimeout=500) =
    let sent = conn.sock.trySend(wireAMQPVersion(amqpVersion))
    if not sent:
        raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # Read only the header, unless it's a version response, then we're missing a byte (will be handled elsewhere)
    let rec = conn.sock.recv(7, readTimeout)
    conn.stream.write(rec)
    conn.stream.flush()
    conn.stream.setPosition(0)

    if conn.stream.peekStr(4) == "AMQP":
        conn.stream.setPosition(7)
        conn.stream.write(conn.sock.recv(1, readTimeout))
        conn.stream.setPosition(0)
        raise newException(AMQPVersionError, fmt"Server does not support {amqpVersion}, sent: {conn.stream.readStr(8).readRawAMQPVersion()}")
    
    conn.stream.setPosition(0)


proc readFrame*(conn: AMQPConnection): AMQPFrame =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5.
    ## `amqpVersion` must be in dotted notation

    # Version negotiation pre-fetches 7B, so we need to account for that
    if conn.stream.atEnd():
        conn.stream.write(conn.sock.recv(7, conn.readTimeout))
        if conn.stream.atEnd():
            raise newException(AMQPProtocolError, "Failed to read frame from server")

    result.frameType = conn.stream.readUint8()
    conn.stream.readNumericEndian(result.channel)
    conn.stream.readNumericEndian(result.payloadSize)

    # Frame-end is a single octet that must be set to 0xCE
    let payload_plus_frame_end = conn.sock.recv(int(result.payloadSize)+1, conn.readTimeout)
    
    # Ensure the frame-end octet matches the spec
    if byte(payload_plus_frame_end[result.payloadSize]) != 0xCE:
        raise newException(AMQPProtocolError, "Corrupt frame, missing 0xCE ending marker")

    result.payload = newStringStream(payload_plus_frame_end[0..(result.payloadSize-1)])


proc readTLSFrame*(): string = 
    ## Reads an AMQP frame from a TLS encrypted session
    raise newException(Exception, "not implemented")

proc writeFrame*(conn: AMQPConnection, frame: AMQPFrame) =
    ## Writes an AMQP frame to a socket