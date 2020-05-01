## 
## Implements the `exchange` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import tables

import ../endian
import ../errors
import ../field_table
import ../types

const CLASS_ID: uint16 = 40

type AMQPExchangeError* = object of AMQPError

proc exchangeDeclareOk*(chan: AMQPChannel)
proc exchangeDeleteOk*(chan: AMQPChannel)

var exchangeMethodMap* = MethodMap()
exchangeMethodMap[11] = exchangeDeclareOk
exchangeMethodMap[21] = exchangeDeleteOk


proc sendFrame(chan: AMQPChannel, payloadStrm: Stream, callback: FrameHandlerProc = nil) = 
    payloadStrm.setPosition(0)
    let payload = payloadStrm.readAll()

    chan.curFrame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(chan.number),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(payload.len)),
        payloadString: payload
    )

    let sendRes = chan.frames.sender(chan)
    if sendRes.error:
        raise newException(AMQPExchangeError, sendRes.result)

    if callback != nil:
        callback(chan)


proc exchangeDeclare*(chan: AMQPChannel, exchangeName: string, exchangeType: string, passive: bool, durable: bool, 
                      autoDelete: bool, internal: bool, noWait: bool, arguments = FieldTable()) =
    ## Requests for the server to create a new exchange, `exchangeName` (exchange.declare)
    ## 
    if exchangeName.len > 255:
        raise newException(AMQPExchangeError, "Exchange name must be 255 characters or less")
    elif exchangeType.len > 255:
        raise newException(AMQPExchangeError, "Exchange type must be 255 characters or less")
    
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(10)))

    stream.write(swapEndian(uint16(0)))

    # exchange
    stream.write(uint8(exchangeName.len))
    stream.write(exchangeName)

    # type
    stream.write(uint8(exchangeType.len))
    stream.write(exchangeType)
    
    # bit fields need to be packed into a uint8
    let bitFields = (uint8(passive)) or (uint8(durable) shl 1) or (uint8(autoDelete) shl 2) or 
                    (uint8(internal) shl 3) or (uint8(noWait) shl 4)
    stream.write(uint8(bitFields))

    let args = arguments.toWire.readAll()
    stream.write(swapEndian(uint32(args.len)))
    stream.write(args)

    debug "Creating exchange", exchange=exchangeName
    chan.sendFrame(stream, callback=chan.frames.handler)


proc exchangeDeclareOk*(chan: AMQPChannel) =
    ## Handles a 'exchange.declare-ok' from the server
    debug "Created exchange"


proc exchangeDelete*(chan: AMQPChannel, exchangeName: string, ifUnused: bool, noWait: bool) =
    ## Deletes an exchange on the server (exchange.delete)
    if exchangeName.len > 255:
        raise newException(AMQPExchangeError, "Exchange name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(20)))

    stream.write(swapEndian(uint16(0)))

    # exchange
    stream.write(uint8(exchangeName.len))
    stream.write(exchangeName)

    # bit fields (if-unused, no-wait)
    let bitFields = (uint8(ifUnused)) or (uint8(noWait) shl 1)
    stream.write(uint8(bitFields))

    debug "Deleting exchange", exchange=exchangeName
    chan.sendFrame(stream, callback=chan.frames.handler)
    

proc exchangeDeleteOk*(chan: AMQPChannel) =
    ## Handles a 'exchange.delete-ok' from the server
    debug "Deleted exchange"