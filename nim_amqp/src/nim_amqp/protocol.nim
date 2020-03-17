## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net

import ./utils

let AMQP_VERSION = "AMQP\0\0\9\1"

type AMQPError* = object of Exception
type AMQPProtocolError* = object of AMQPError

type AMQPClass* = ref object of RootObj
    classId*: uint16
    className*: string
    
type AMQPMethod* = ref object of AMQPClass
    methodId*: uint16
    methodName*: string

type AMQPMethodCallback = (proc(payload: string): ref AMQPMethod)


proc readFrame*(sock: Socket, callback: AMQPMethodCallback, read_timeout: int=500): ref AMQPMethod =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5

    # FIXME: This does not belong here, it should only be called during connection setup
    let sent = sock.trySend(AMQP_VERSION)
    if not sent:
        raise newException(AMQPProtocolError, "Failed to send AMQP version string")
    
    # Read only the header
    let header = sock.recv(7, read_timeout)
    if header.len() == 0:
        raise newException(AMQPProtocolError, "Response from server was empty")

    let frame_type = int(header[0])
    let channel = extractUint16(header, 1)
    let payload_size = extractUint32(header, 3)

    # Frame-end is a single octet that must be set to 0xCE
    let payload_plus_frame_end = sock.recv(int(payload_size)+1, read_timeout)
    # Ensure the frame-end octet matches the spec
    if byte(payload_plus_frame_end[payload_size]) != 0xCE:
        raise newException(AMQPProtocolError, "Corrupt frame, missing 0xCE ending marker")

    let payload = payload_plus_frame_end[0..(payload_size-1)]

    # TODO, dispatch based on the frame type? It's all static anyway, and easy to put into a lookup table

    return callback(payload)


proc readTLSFrame*(): string = 
    ## Reads an AMQP frame from a TLS encrypted session
    raise newException(Exception, "not implemented")