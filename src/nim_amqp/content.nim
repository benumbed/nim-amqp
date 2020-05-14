## 
## Provides structures and methods for working with AMQP content
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import strformat
import tables

import ./endian
import ./errors
import ./field_table
import ./types

type AMQPContentError* = object of AMQPError
type AMQPPropertyError* = object of AMQPError

# See spec section 2.3.5.2 for info on frame format

# Send header with FRAME_CONTENT_HEADER type
# Send content frames with FRAME_CONTENT_BODY
#   Content frame is literally an AMQP frame with a binary body and the normal 0xCE terminator
#   Content can be split up into multiple frames to accomodate frame-size restrictions
# Remember that headers and content bodies are all contained in AMQP frames


# This is used to set the propertyFlags bitfield properly
const PROPERTY_ORDERING = [
    ("contentType", 15),
    ("contentEncoding", 14),
    ("headers", 13),
    ("deliveryMode", 12),
    ("priority", 12),
    ("correlationId", 11),
    ("replyTo", 10),
    ("expiration", 9),
    ("messageId", 8),
    ("timestamp", 7),
    ("messageType", 6),
    ("userId", 5),
    ("appId", 4),
    ("reserved", 3),
].toOrderedTable


proc writeShortStr(stream: StringStream, sStr: string, propName: string, flags: var uint16) =
    ## Properly writes a shortstr property 
    ## 
    if sStr.len > 255:
        raise newException(AMQPPropertyError, fmt"shortstr property '{propName}'s value must not exceed 255 characters")
    
    let ctLen = sStr.len
    if ctLen > 0:
        stream.write(uint8(ctLen))
        stream.write(sStr)
        # Do not endian the bitfield
        flags = flags or (uint16(1) shl PROPERTY_ORDERING[propName])


proc writeUint[T](stream: StringStream, val: T, propName: string, flags: var uint16) =
    ## Writes a uint-type property (of any bit-length)
    ##
    if val > 0:
        stream.write(swapEndianIfNeeded(val))
        flags = flags or (uint16(1) shl PROPERTY_ORDERING[propName])

proc populateProps(props: var AMQPBasicProperties, stream: Stream, flagId: int) =
    ## Sets a property in the provided data-structure
    case flagId:
        # content_type
        of 15:
            let ctSize = swapEndian(stream.readUint32)
            let ctStr = stream.readStr(int(ctSize))
            props.contentType = ctStr
        else:
            let warning = fmt"Unhandled flag ID {flagId}" 
            warn warning

proc basicPropsFromWire*(wireProps: Stream, flags: uint16): AMQPBasicProperties =
    ## Converts the wire versions of a basic-properties table to a Nim struct
    ##
    var i = 1;
    while i <= 15:
        let curFlag = uint16(1) shl i
        let flag = (flags and curFlag) == curFlag
        echo fmt"bit: {i} state: {flag}"
        if flag:
            populateProps(result, wireProps, i)
        i.inc

proc toWire*(this: AMQPBasicProperties): (string, uint16) =
    ## Converts basic properties to a format suitable for the wire
    ##
    let stream = newStringStream()
    # The rest of this stuff counts on flags to be zeroed, since this is a bitfield
    var flags: uint16 = 0

    # These are orderd according to the XML-derived spec, see 1.8.1 (Class/Method Spec)
    stream.writeShortStr(this.contentType, "contentType", flags)
    stream.writeShortStr(this.contentEncoding, "contentEncoding", flags)

    if this.headers.len > 0:
        let headers = this.headers.toWire.readAll()
        stream.write(swapEndian(uint32(headers.len)))
        stream.write(headers)
        flags = flags or (uint16(1) shl PROPERTY_ORDERING["headers"])

    stream.writeUint(this.deliveryMode, "deliveryMode", flags)
    stream.writeUint(this.priority, "priority", flags)

    stream.writeShortStr(this.correlationId, "correlationId", flags)
    stream.writeShortStr(this.replyTo, "replyTo", flags)
    stream.writeShortStr(this.expiration, "expiration", flags)
    stream.writeShortStr(this.messageId, "messageId", flags)
    stream.writeUint(this.timestamp, "timestamp", flags)
    stream.writeShortStr(this.messageType, "messageType", flags)
    stream.writeShortStr(this.userId, "userId", flags)
    stream.writeShortStr(this.appId, "appId", flags)
    stream.writeShortStr(this.reserved, "reserved", flags)

    stream.setPosition(0)

    result = (stream.readAll, flags)


proc toWire*(this: AMQPContentHeader): string =
    ## Converts AMQPContentHeader to a format usable on the wire
    ## 
    let stream = newStringStream()

    stream.write(swapEndian(this.classId))
    stream.write(swapEndian(this.weight))
    stream.write(swapEndian(this.bodySize))

    let (propList, flags) = this.propertyList.toWire
    stream.write(swapEndian(flags))
    stream.write(propList)

    stream.setPosition(0)

    result = stream.readAll


proc sendFrame(chan: AMQPChannel, frameType: uint8, payload: string, callback: FrameHandlerProc = nil) = 
    chan.curFrame = AMQPFrame(
        frameType: frameType,
        channel: swapEndian(chan.number),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(payload.len)),
        payloadString: payload
    )

    let sendRes = chan.frames.sender(chan)
    if sendRes.error:
        raise newException(AMQPContentError, sendRes.result)

    if callback != nil:
        callback(chan)


proc sendContentHeader*(chan: AMQPChannel, header: AMQPContentHeader) =
    ## Sends the content header to the server
    ## 
    chan.sendFrame(FRAME_CONTENT_HEADER, header.toWire)

proc sendContentBody*(chan: AMQPChannel, body: string) =
    ## Sends the content body described by the content header
    ## 
    chan.sendFrame(FRAME_CONTENT_BODY, body)


proc handleContentHeader*(chan: AMQPChannel) =
    ## Handles an incoming content header
    ## 
    let stream = chan.curFrame.payloadStream

    let classId = swapEndian(stream.readUint16())
    let weight = swapEndian(stream.readUint16())
    let bodySize = swapEndian(stream.readUint64())
    # TODO: Parse the flags
    let propFlags = swapEndian(stream.readUint16())

    discard basicPropsFromWire(stream, propFlags)

    let header = AMQPContentHeader(classId:classId, weight:weight, bodySize:bodySize, propertyFlags:propFlags,
                                    propertyList:AMQPBasicProperties())

    debug "Content Header", classId=classId, weight=weight, bodySize=bodySize, propFlags=propFlags


proc handleContentBody*(chan: AMQPChannel) =
    ## Handles incoming content bodies
    ##
    debug "Content body handler"
    echo chan.curFrame.payloadStream.readAll()
