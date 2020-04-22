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

proc queueDeclareOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc queueBindOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc queueUnBindOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc queuePurgeOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc queueDeleteOk*(conn: AMQPConnection, stream: Stream, channel: uint16)

var queueMethodMap* = MethodMap()
queueMethodMap[11] = queueDeclareOk
queueMethodMap[21] = queueBindOk
queueMethodMap[51] = queueUnBindOk
queueMethodMap[31] = queuePurgeOk
queueMethodMap[41] = queueDeleteOk


proc sendFrame(conn: AMQPConnection, payloadStrm: Stream, channel: uint16 = 0, callback: FrameHandlerProc = nil) = 
    payloadStrm.setPosition(0)
    let payload = payloadStrm.readAll()

    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(channel),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(payload.len)),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPQueueError, sendRes.result)

    if callback != nil:
        callback(conn)


proc queueDeclare*(conn: AMQPConnection, queueName: string, passive: bool, durable: bool, exclusive: bool, 
                    autoDelete: bool, noWait: bool, arguments: FieldTable, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc queueDeclareOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'queue.declare-ok' from the server
    debug "Created queue"


proc queueBind*(conn: AMQPConnection, queueName: string, exchangeName: string, routingKey: string, noWait: bool, 
                arguments: FieldTable, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc queueBindOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.bind request
    ## 
    debug "Bound queue to exchange"


proc queueUnBind*(conn: AMQPConnection, queueName: string, exchangeName: string, routingKey: string, 
                    arguments: FieldTable, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc queueUnBindOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.unbind request
    ## 
    debug "Unbound queue from exchange"


proc queuePurge*(conn: AMQPConnection, queueName: string, noWait: bool, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc queuePurgeOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.purge request
    ## 
    debug "Purged queue"


proc queueDelete*(conn: AMQPConnection, queueName: string, ifUnused: bool, ifEmpty: bool, noWait: bool, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)
    

proc queueDeleteOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'queue.delete-ok' from the server
    ## 
    let delMsgs = swapEndian(stream.readUint32)
    debug "Deleted queue", numDeletedMsgs=delMsgs

