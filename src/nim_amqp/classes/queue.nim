## 
## Implements the `queue` class and associated methods
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

const CLASS_ID: uint16 = 50

type AMQPQueueError* = object of AMQPError

proc queueDeclareOk*(chan: AMQPChannel)
proc queueBindOk*(chan: AMQPChannel)
proc queueUnBindOk*(chan: AMQPChannel)
proc queuePurgeOk*(chan: AMQPChannel)
proc queueDeleteOk*(chan: AMQPChannel)

var queueMethodMap* = MethodMap()
queueMethodMap[11] = queueDeclareOk
queueMethodMap[21] = queueBindOk
queueMethodMap[51] = queueUnBindOk
queueMethodMap[31] = queuePurgeOk
queueMethodMap[41] = queueDeleteOk


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
        raise newException(AMQPQueueError, sendRes.result)

    if callback != nil:
        callback(chan)


proc queueDeclare*(chan: AMQPChannel, queueName: string, passive: bool, durable: bool, exclusive: bool, 
                    autoDelete: bool, noWait: bool, arguments = FieldTable()) =
    ## Requests for the server to create a new queue, `queueName` (queue.declare)
    ## 
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")
    
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(10)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)
    
    # bit fields need to be packed into a uint8
    let bitFields = (uint8(passive)) or (uint8(durable) shl 1) or (uint8(exclusive) shl 2) or 
                    (uint8(autoDelete) shl 3) or (uint8(noWait) shl 4)
    stream.write(uint8(bitFields))

    let args = arguments.toWire.readAll()
    stream.write(swapEndian(uint32(args.len)))
    stream.write(args)

    debug "Creating queue", queue=queueName
    chan.sendFrame(stream, callback=chan.frames.handler)


proc queueDeclareOk*(chan: AMQPChannel) =
    ## Handles a 'queue.declare-ok' from the server
    debug "Created queue"


proc queueBind*(chan: AMQPChannel, queueName: string, exchangeName: string, routingKey: string, noWait: bool, 
                arguments = FieldTable()) =
    ## Bind a queue to an exchange with the provided `routingKey`
    ## 
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")
    elif exchangeName.len > 255:
        raise newException(AMQPQueueError, "Exchange name to bind to must be 255 characters or less")
    elif routingKey.len > 255:
        raise newException(AMQPQueueError, "Routing key must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(20)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    # exchange
    stream.write(uint8(exchangeName.len))
    stream.write(exchangeName)

    # routing-key
    stream.write(uint8(routingKey.len))
    stream.write(routingKey)

    stream.write(uint8(noWait))

    let args = arguments.toWire.readAll()
    stream.write(swapEndian(uint32(args.len)))
    stream.write(args)

    debug "Binding queue to exchange", queue=queueName, exchange=exchangeName, routingKey=routingKey
    chan.sendFrame(stream, callback=chan.frames.handler)


proc queueBindOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.bind request
    ## 
    debug "Bound queue to exchange"


proc queueUnBind*(chan: AMQPChannel, queueName: string, exchangeName: string, routingKey: string, 
                    arguments = FieldTable()) =
    ## Unbind a queue from an exchange, provided `routingKey` matches
    ## 
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")
    elif exchangeName.len > 255:
        raise newException(AMQPQueueError, "Exchange name to bind to must be 255 characters or less")
    elif routingKey.len > 255:
        raise newException(AMQPQueueError, "Routing key must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(50)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    # exchange
    stream.write(uint8(exchangeName.len))
    stream.write(exchangeName)

    # routing-key
    stream.write(uint8(routingKey.len))
    stream.write(routingKey)

    let args = arguments.toWire.readAll()
    stream.write(swapEndian(uint32(args.len)))
    stream.write(args)

    debug "Unbinding queue from exchange", queue=queueName, exchange=exchangeName
    chan.sendFrame(stream, callback=chan.frames.handler)


proc queueUnBindOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.unbind request
    ## 
    debug "Unbound queue from exchange"


proc queuePurge*(chan: AMQPChannel, queueName: string, noWait: bool) =
    ## Purges the `queueName` queue
    ## 
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(30)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    stream.write(uint8(noWait))

    debug "Purging queue", queue=queueName
    chan.sendFrame(stream, callback=chan.frames.handler)


proc queuePurgeOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.purge request
    ## 
    debug "Purged queue"


proc queueDelete*(chan: AMQPChannel, queueName: string, ifUnused: bool, ifEmpty: bool, noWait: bool) =
    ## Deletes a queue on the server (queue.delete)
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(40)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    # bit fields (if-unused, if-empty, no-wait)
    let bitFields = (uint8(ifUnused)) or (uint8(ifEmpty) shl 1) or (uint8(noWait) shl 2)
    stream.write(uint8(bitFields))

    debug "Deleting queue", queue=queueName
    chan.sendFrame(stream, callback=chan.frames.handler)
    

proc queueDeleteOk*(chan: AMQPChannel) =
    ## Handles a 'queue.delete-ok' from the server
    ##
    let delMsgs = swapEndian(chan.curFrame.payloadStream.readUint32)
    debug "Deleted queue", numDeletedMsgs=delMsgs

