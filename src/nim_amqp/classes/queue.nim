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
import ../utils

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


proc queueDeclare*(chan: AMQPChannel, queueName: string, passive = false, durable = false, exclusive = false, 
                    autoDelete = false, noWait = false, arguments = FieldTable()) =
    ## Requests for the server to create a new queue, `queueName` (queue.declare)
    ## 
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")
    
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(AMQP_CLASS_QUEUE))
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
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc queueDeclareOk*(chan: AMQPChannel) =
    ## Handles a 'queue.declare-ok' from the server
    debug "Created queue"


proc queueBind*(chan: AMQPChannel, queueName: string, exchangeName: string, routingKey: string, noWait = false, 
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
    stream.write(swapEndian(AMQP_CLASS_QUEUE))
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
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


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
    stream.write(swapEndian(AMQP_CLASS_QUEUE))
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
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc queueUnBindOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.unbind request
    ## 
    debug "Unbound queue from exchange"


proc queuePurge*(chan: AMQPChannel, queueName: string, noWait: bool = false) =
    ## Purges the `queueName` queue
    ## 
    ## `queueName`: Name of the queue to purge
    ## `noWait`: Tell server to not send a response
    ##
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(AMQP_CLASS_QUEUE))
    stream.write(swapEndian(uint16(30)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    stream.write(uint8(noWait))

    debug "Purging queue", queue=queueName
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc queuePurgeOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.purge request
    ## 
    debug "Purged queue"


proc queueDelete*(chan: AMQPChannel, queueName: string, ifUnused = false, ifEmpty = false, noWait = false) =
    ## Deletes a queue on the server (queue.delete)
    if queueName.len > 255:
        raise newException(AMQPQueueError, "Queue name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(AMQP_CLASS_QUEUE))
    stream.write(swapEndian(uint16(40)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    # bit fields (if-unused, if-empty, no-wait)
    let bitFields = (uint8(ifUnused)) or (uint8(ifEmpty) shl 1) or (uint8(noWait) shl 2)
    stream.write(uint8(bitFields))

    debug "Deleting queue", queue=queueName
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)
    

proc queueDeleteOk*(chan: AMQPChannel) =
    ## Handles a 'queue.delete-ok' from the server
    ##
    let delMsgs = swapEndian(chan.curFrame.payloadStream.readUint32)
    debug "Deleted queue", numDeletedMsgs=delMsgs

