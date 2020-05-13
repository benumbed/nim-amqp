## 
## Implements the `basic` class and associated methods
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

const CLASS_ID: uint16 = 60

type AMQPBasicError* = object of AMQPError

proc basicQosOk*(chan: AMQPChannel)
proc basicConsumeOk*(chan: AMQPChannel)
proc basicCancelOk*(chan: AMQPChannel)
# proc basicReturn*(chan: AMQPChannel)
proc basicDeliver*(chan: AMQPChannel)
# proc basicGetOk*(chan: AMQPChannel)
# proc basicGetEmpty*(chan: AMQPChannel)
# proc basicRecoverOk*(chan: AMQPChannel)

var basicMethodMap* = MethodMap()
basicMethodMap[11] = basicQosOk
basicMethodMap[21] = basicConsumeOk
basicMethodMap[31] = basicCancelOk
# basicMethodMap[50] = basicReturn
basicMethodMap[60] = basicDeliver
# basicMethodMap[71] = basicGetOk
# basicMethodMap[72] = basicGetEmpty
# basicMethodMap[111] = basicRecoverOk


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
        raise newException(AMQPBasicError, sendRes.result)

    if callback != nil:
        callback(chan)


proc basicQos*(chan: AMQPChannel, prefetchCount: uint16, global: bool) =
    ## Sets QoS parameters on the server.
    ## 
    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(10)))

    stream.write(swapEndian(uint32(0)))
    stream.write(swapEndian(uint16(prefetchCount)))
    stream.write(uint8(global))

    debug "Setting QoS params", prefetchSize=0, prefetchCount=prefetchCount, global=global
    chan.sendFrame(stream, callback=chan.frames.handler)


proc basicQosOk*(chan: AMQPChannel) =
    ## Handles a 'basic.qos-ok' from the server
    debug "Successful QoS request"


proc basicConsume*(chan: AMQPChannel, queueName: string, consumerTag: string, noLocal: bool, noAck: bool, 
                    exclusive: bool, noWait: bool, arguments = FieldTable()) =
    ## Starts a consumer
    ## 
    if queueName.len > 255:
        raise newException(AMQPBasicError, "Queue name must be 255 characters or less")
    elif consumerTag.len > 255:
        raise newException(AMQPBasicError, "consumer-tag must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(20)))

    stream.write(swapEndian(uint16(0)))

    # queue
    stream.write(uint8(queueName.len))
    stream.write(queueName)

    # exchange
    stream.write(uint8(consumerTag.len))
    stream.write(consumerTag)

    # bit fields need to be packed into a uint8
    let bitFields = (uint8(noLocal)) or (uint8(noAck) shl 1) or (uint8(exclusive) shl 2) or 
                    (uint8(noWait) shl 3)
    stream.write(uint8(bitFields))

    let args = arguments.toWire.readAll()
    stream.write(swapEndian(uint32(args.len)))
    stream.write(args)

    debug "Starting a consumer", queue=queueName, consumerTag=consumerTag, noLocal=noLocal, noAck=noAck, 
        exclusive=exclusive, noWait=noWait
    chan.sendFrame(stream, callback=chan.frames.handler)


proc basicConsumeOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.bind request
    ##
    let stream = chan.curFrame.payloadStream
    
    let tagSize = stream.readUint8()
    let tag = stream.readStr(int(tagSize))
    debug "Started consumer", tag=tag


proc basicCancel*(chan: AMQPChannel, consumerTag: string, noWait: bool) =
    ## Unbind a queue from an exchange, provided `routingKey` matches
    ## 
    if consumerTag.len > 255:
        raise newException(AMQPBasicError, "consumer-tag must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(30)))

    # consumer-tag
    stream.write(uint8(consumerTag.len))
    stream.write(consumerTag)

    stream.write(uint8(noWait))

    debug "Canceling consumer", consumerTag=consumerTag
    chan.sendFrame(stream, callback=chan.frames.handler)


proc basicCancelOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.unbind request
    ##
    let stream = chan.curFrame.payloadStream

    let tagSize = stream.readUint8()
    let tag = stream.readStr(int(tagSize))
    debug "Canceled consumer", tag=tag


proc basicPublish*(chan: AMQPChannel, exchangeName: string, routingKey: string, mandatory: bool, immediate: bool) =
    ## Publishes a message to an exchange of `exchangeName` using `routingKey`
    ## 
    if exchangeName.len > 255:
        raise newException(AMQPBasicError, "Exchange name must be 255 characters or less")
    elif routingKey.len > 255:
        raise newException(AMQPBasicError, "Routing key name must be 255 characters or less")

    let stream = newStringStream()

    # Class and Method
    stream.write(swapEndian(CLASS_ID))
    stream.write(swapEndian(uint16(40)))

    stream.write(swapEndian(uint16(0)))

    # exchange
    stream.write(uint8(exchangeName.len))
    stream.write(exchangeName)

    # routing-key
    stream.write(uint8(routingKey.len))
    stream.write(routingKey)

    # bit fields need to be packed into a uint8
    let bitFields = (uint8(mandatory)) or (uint8(immediate) shl 1)
    stream.write(uint8(bitFields))

    debug "Sending basicPublish", exchange=exchangeName, mandatory=mandatory, immediate=immediate
    chan.sendFrame(stream)


proc basicReturn*(chan: AMQPChannel, replyCode: uint16, replyText: string, exchangeName: string, routingKey: string) =
    ## 'Returns' a message that could not be processed to the server
    ## 
    
proc basicDeliver(chan: AMQPChannel) = 
    ## Handles a basic.deliver from the server
    ##
    let stream = chan.curFrame.payloadStream
    
    # consumer-tag
    let conTagSize = stream.readUint8()
    let consumerTag = stream.readStr(int(conTagSize))
    # delivery-tag
    let deliveryTag = swapEndian(stream.readUint64())
    # redelivered
    let redelivered = bool(stream.readUint8())
    # exchange-name
    let exchNameSize = stream.readUint8()
    let exchangeName = stream.readStr(int(exchNameSize))
    # routing-key
    let keySize = stream.readUint8()
    let routingKey = stream.readStr(int(keySize))

    debug "basic.deliver", consumerTag=consumerTag, deliveryTag=deliveryTag, redelivered=redelivered, 
        exchangeName=exchangeName, routingKey=routingKey