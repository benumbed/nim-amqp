## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import strutils
import system

import ./types
import ./endian

proc readRawAMQPVersion*(ver: string): string {.inline.} = 
    fmt"{ver[0..3]}{int(ver[4])}{int(ver[5])}{int(ver[6])}{int(ver[7])}"

proc wireAMQPVersion*(ver: string): string {.inline.} =
    ## Converts a dotted-style version string to the proper AMQP wire version
    result = "AMQP"
    result.add(char(0))
    for tok in ver.split("."):
        result.add(char(tok.parseUInt()))


proc singleLine*(this: string): string =
    ## Takes a multi-line string collapses it
    var toks: seq[string]

    for tok in this.split("\n"):
        toks.add(tok.strip())

    result = toks.join(" ")


proc constructFrame(chan: AMQPChannel, frameType: uint8, payload: Stream|string): AMQPFrame =
    when type(payload) is Stream:
        payload.setPosition(0)

        chan.curFrame = AMQPFrame(
            frameType: frameType,
            channel: swapEndian(chan.number),
            payloadType: ptStream,
            payloadStream: payload
        )
    else:
        chan.curFrame = AMQPFrame(
            frameType: frameType,
            channel: swapEndian(chan.number),
            payloadType: ptString,
            payloadString: payload,
            payloadSize: swapEndian(uint32(payload.len))
        )

proc constructMethodFrame*(chan: AMQPChannel, payload: Stream|string): AMQPFrame =
    ## Constructs a new AMQP method frame from the provided variables
    ##
    ## `payloadStream`: The stream to use to construct the frame payload
    ## `callback`: Not sure if this is still needed TBD
    ##
    return chan.constructFrame(FRAME_METHOD, payload)


proc constructContentFrame*(chan: AMQPChannel, contentFrameType: uint8, payload: Stream|string): AMQPFrame =
    ## Constructs a new AMQP method frame from the provided variables
    ##
    ## `contentFrameType`: Either FRAME_CONTENT_HEADER or FRAME_CONTENT_BODY
    ## `payload`: Stream or string to use as the payload
    ## `callback`: Not sure if this is still needed TBD
    ##
    if (contentFrameType != FRAME_CONTENT_HEADER) and (contentFrameType != FRAME_CONTENT_BODY):
        raise newException(AMQPError, "constructContentFrame only accepts content frame types")
    
    return chan.constructFrame(contentFrameType, payload)