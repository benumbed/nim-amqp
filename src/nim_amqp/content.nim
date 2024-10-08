## 
## Provides structures and methods for working with AMQP content
## See spec section 2.3.5.2 for info on frame format
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import strformat
import strutils
import tables

import ./endian
import ./errors
import ./field_table
import ./types
import ./utils

type AMQPContentError* = object of AMQPError
type AMQPPropertyError* = object of AMQPError


# This is used to set the propertyFlags bitfield properly
const PROPERTY_ORDERING = [
    ("contentType", 15),
    ("contentEncoding", 14),
    ("headers", 13),
    ("deliveryMode", 12),
    ("priority", 11),
    ("correlationId", 10),
    ("replyTo", 9),
    ("expiration", 8),
    ("messageId", 7),
    ("timestamp", 6),
    ("messageType", 5),
    ("userId", 4),
    ("appId", 3),
    ("reserved", 2),
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
        of 15:
            props.contentType = stream.readStr(int(stream.readUint8))
        of 14:
            props.contentEncoding = stream.readStr(int(stream.readUint8))
        of 13:
            props.headers = FieldTable()
            if swapEndian(stream.readUint32) != 0:
                props.headers = stream.extractFieldTable
        of 12:
            props.deliveryMode = (DeliveryMode)stream.readUint8
        of 11:
            props.priority = stream.readUint8
        of 10:
            props.correlationId = stream.readStr(int(stream.readUint8))
        of 9:
            props.replyTo = stream.readStr(int(stream.readUint8))
        of 8:
            props.expiration = stream.readStr(int(stream.readUint8))
        of 7:
            props.messageId = stream.readStr(int(stream.readUint8))
        of 6:
            props.messageId = stream.readStr(int(stream.readUint8))
        of 5:
            props.messageId = stream.readStr(int(stream.readUint8))
        of 4:
            props.timestamp = swapEndian(stream.readUint64)
        of 3:
            props.appId = stream.readStr(int(stream.readUint8))
        of 2:
            props.reserved = stream.readStr(int(stream.readUint8))
        # TODO: AMQP specifies that if the 0 bit is set, than there's another flag short following this one
        else:
            warn "Unknown property ID, ignoring", flagId=flagId

# proc `$`*(this: AMQPBasicProperties) =
#     ## String representation of AMQPBasicProperties
#     ##
#     var i = 15;
#     while i >= 0:
#         let curFlag = uint16(1) shl i
#         let flag = (flags and curFlag) == curFlag
#         if flag:
#             populateProps(result, wireProps, i)
#         i.dec

proc basicPropsFromWire*(wireProps: Stream, flags: uint16): AMQPBasicProperties =
    ## Converts the wire versions of a basic-properties table to a Nim struct
    ##
    # Bit 15 is the first property (4.2.6.1)
    var i = 15;
    while i >= 0:
        let curFlag = uint16(1) shl i
        let flag = (flags and curFlag) == curFlag
        if flag:
            populateProps(result, wireProps, i)
        i.dec


proc toWire*(this: AMQPBasicProperties): (string, uint16) =
    ## Converts basic properties to a format suitable for the wire
    ##
    let stream = newStringStream()
    # The rest of this stuff counts on flags to be zeroed, since this is a bitfield
    var flags: uint16 = 0

    # These are ordered according to the XML-derived spec, see 1.8.1 (Class/Method Spec)
    stream.writeShortStr(this.contentType, "contentType", flags)
    stream.writeShortStr(this.contentEncoding, "contentEncoding", flags)

    if this.headers.len > 0:
        let headers = this.headers.toWire.readAll()
        stream.write(swapEndian(uint32(headers.len)))
        stream.write(headers)
        flags = flags or (uint16(1) shl PROPERTY_ORDERING["headers"])

    stream.writeUint((uint8)this.deliveryMode, "deliveryMode", flags)
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


proc sendContentHeader*(chan: AMQPChannel, header: AMQPContentHeader) =
    ## Sends the content header to the server
    ##
    discard chan.frames.sender(chan, chan.constructContentFrame(FRAME_CONTENT_HEADER, header.toWire))

proc sendContentBody*(chan: AMQPChannel, body: Stream) =
    ## Sends the content body described by the content header
    ##
    discard chan.frames.sender(chan, chan.constructContentFrame(FRAME_CONTENT_BODY, body))


proc handleContentHeader*(chan: AMQPChannel) =
    ## Handles an incoming content header
    ## 
    # NOTE: The content data structure is initialized by basic.deliver (which happens before we get a content header)
    let stream = chan.curFrame.payloadStream

    let classId = swapEndian(stream.readUint16())
    let weight = swapEndian(stream.readUint16())
    let bodySize = swapEndian(stream.readUint64())
    let propFlags = swapEndian(stream.readUint16())

    chan.curContent.header = AMQPContentHeader(classId:classId, weight:weight, bodySize:bodySize, 
                                propertyFlags:propFlags, propertyList:basicPropsFromWire(stream, propFlags))

    debug "Content Header", classId=classId, weight=weight, bodySize=bodySize, propFlags=propFlags

    if bodySize > 0:
        chan.frames.handler(chan)
    # Fixes #3 -- Call the message callback event if the body is blank, since we recieved a content header
    elif not isnil chan.messageCallback:
        chan.messageCallback(chan, chan.curContent)


proc handleContentBody*(chan: AMQPChannel) =
    ## Handles incoming content bodies.  Note that AMQP allows for chunking, so this provides for extending the body
    ##
    let raw = chan.curFrame.payloadStream.readAll().strip()
    if raw[raw.len-1] != char(AMQP_FRAME_END):
        raise newException(AMQPContentError, "Encountered corrupted content body frame, 0xCE terminator not found")
    
    let chunk = raw[0..raw.len-2]
    chan.curContent.bodyLen.inc(chunk.len)
    chan.curContent.body.write(chunk)

    if chan.curContent.bodyLen == chan.curContent.header.bodySize:
        chan.curContent.body.setPosition(0)

    if not isnil chan.messageCallback:
        chan.messageCallback(chan, chan.curContent)
