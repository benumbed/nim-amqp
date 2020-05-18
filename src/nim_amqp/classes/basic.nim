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
import ../utils

type AMQPBasicError* = object of AMQPError

proc basicQosOk*(chan: AMQPChannel)
proc basicConsumeOk*(chan: AMQPChannel)
proc basicCancelOk*(chan: AMQPChannel)
proc basicReturn*(chan: AMQPChannel)
proc basicDeliver*(chan: AMQPChannel)
# proc basicGetOk*(chan: AMQPChannel)
# proc basicGetEmpty*(chan: AMQPChannel)
# proc basicRecoverOk*(chan: AMQPChannel)

var basicMethodMap* = MethodMap()
basicMethodMap[11] = basicQosOk
basicMethodMap[21] = basicConsumeOk
basicMethodMap[31] = basicCancelOk
basicMethodMap[50] = basicReturn
basicMethodMap[60] = basicDeliver
# basicMethodMap[71] = basicGetOk
# basicMethodMap[72] = basicGetEmpty
# basicMethodMap[111] = basicRecoverOk


proc basicQos*(chan: AMQPChannel, prefetchCount: uint16, global: bool) =
    ## Sets QoS parameters on the server.
    ## 
    let stream = newStringStream()
    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(10))

    stream.write(swapEndian(uint32(0)))
    stream.write(swapEndian(uint16(prefetchCount)))
    stream.write(uint8(global))

    debug "Setting QoS params", prefetchSize=0, prefetchCount=prefetchCount, global=global

    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


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
    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(20))

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
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc basicConsumeOk*(chan: AMQPChannel) =
    ## Server responding to a successful queue.bind request
    ##
    let stream = chan.curFrame.payloadStream
    
    let tagSize = stream.readUint8()
    let tag = stream.readStr(int(tagSize))
    debug "Started consumer", tag=tag


proc basicCancel*(chan: AMQPChannel, consumerTag: string, noWait: bool) =
    ## Cancels a consumer
    ## 
    if consumerTag.len > 255:
        raise newException(AMQPBasicError, "consumer-tag must be 255 characters or less")

    let stream = newStringStream()
    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(30))

    # consumer-tag
    stream.write(uint8(consumerTag.len))
    stream.write(consumerTag)

    stream.write(uint8(noWait))

    debug "Canceling consumer", consumerTag=consumerTag
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc basicCancelOk*(chan: AMQPChannel) =
    ## Server responding to a successful basic.cancel request
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
    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(40))

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

    debug "Sending basic.publish", exchange=exchangeName, mandatory=mandatory, immediate=immediate
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream))


proc basicReturn*(chan: AMQPChannel) =
    ## 'Returns' a message that could not be processed to the server.  If `chan.returnCallback` is not set, only a 
    ## warning will be logged.
    ##
    let stream = chan.curFrame.payloadStream

    let replyCode = swapEndian(stream.readUint16)
    let replyText = stream.readStr(int(stream.readUint8))
    let exchange = stream.readStr(int(stream.readUint8))
    let routingKey = stream.readStr(int(stream.readUint8))

    warn "Recieved returned message", replyCode=replyCode, replyText=replyText, exchange=exchange, routingKey=routingKey

    if not isnil chan.returnCallback:
        chan.returnCallback(chan, replyCode=replyCode, replyText=replyText, exchangeName=exchange, 
                            routingKey=routingKey)
    
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

    let meta = ContentMetadata(
        consumerTag: consumerTag, deliveryTag: deliveryTag, redelivered: redelivered, exchangeName: exchangeName, 
        routingKey: routingKey
    )
    chan.curContent = ContentData(header: AMQPContentHeader(), body: newStringStream(), metadata: meta)


proc basicAck*(chan: AMQPChannel, deliveryTag: uint64, multiple: bool = false) =
    ## Acknowledges one or more messages
    ## 
    ## `deliveryTag`: The tag of the message to acknowledge.  If `multiple` is true, this ack means all unacked messages
    ##                up to and including the one matching the tag.  If `deliveryTag` is zero and `multiple` is true, 
    ##                then the server will mark all unacked messages as acked.
    ## `multiple`: Acknowledge multiple messages
    ##
    let stream = newStringStream()

    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(80))

    # exchange
    stream.write(swapEndian(deliveryTag))
    stream.write(uint8(multiple))

    debug "Sending basic.ack", deliveryTag=deliveryTag, multiple=multiple
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream))


proc basicReject*(chan: AMQPChannel, deliveryTag: uint64, requeue: bool = false) =
    ## Rejects a message delivered to a consumer
    ## 
    ## `deliveryTag`: The tag of the message being rejected.
    ## `requeue`: Tell the server to re-queue the message
    ##
    let stream = newStringStream()

    writeMethodInfo(stream, AMQP_CLASS_BASIC, uint16(80))

    # exchange
    stream.write(swapEndian(deliveryTag))
    stream.write(uint8(requeue))

    debug "Sending basic.reject", deliveryTag=deliveryTag, requeue=requeue
    
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream))