## 
## Implements the `basic` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import tables

import ../content
import ../endian
import ../errors
import ../field_table
import ../types

const CLASS_ID: uint16 = 60

type AMQPBasicError* = object of AMQPError

proc basicQosOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc basicConsumeOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc basicCancelOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
# proc basicReturn*(conn: AMQPConnection, stream: Stream, channel: uint16)
# proc basicDeliver*(conn: AMQPConnection, stream: Stream, channel: uint16)
# proc basicGetOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
# proc basicGetEmpty*(conn: AMQPConnection, stream: Stream, channel: uint16)
# proc basicRecoverOk*(conn: AMQPConnection, stream: Stream, channel: uint16)

var basicMethodMap* = MethodMap()
basicMethodMap[11] = basicQosOk
basicMethodMap[21] = basicConsumeOk
basicMethodMap[31] = basicCancelOk
# basicMethodMap[50] = basicReturn
# basicMethodMap[60] = basicDeliver
# basicMethodMap[71] = basicGetOk
# basicMethodMap[72] = basicGetEmpty
# basicMethodMap[111] = basicRecoverOk


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
        raise newException(AMQPBasicError, sendRes.result)

    if callback != nil:
        callback(conn)


proc basicQos*(conn: AMQPConnection, prefetchCount: uint16, global: bool, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc basicQosOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Handles a 'basic.qos-ok' from the server
    debug "Successful QoS request"


proc basicConsume*(conn: AMQPConnection, queueName: string, consumerTag: string, noLocal: bool, noAck: bool, 
                    exclusive: bool, noWait: bool, arguments: FieldTable, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc basicConsumeOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.bind request
    ##
    let tagSize = stream.readUint8()
    let tag = stream.readStr(int(tagSize))
    debug "Started consumer", tag=tag


proc basicCancel*(conn: AMQPConnection, consumerTag: string, noWait: bool, channel: uint16) =
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
    sendFrame(conn, stream, channel=channel, callback=conn.frameHandler)


proc basicCancelOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.unbind request
    ## 
    let tagSize = stream.readUint8()
    let tag = stream.readStr(int(tagSize))
    debug "Canceled consumer", tag=tag


proc basicPublish*(conn: AMQPConnection, exchangeName: string, routingKey: string, mandatory: bool, immediate: bool, 
                    channel: uint16) =
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

    debug "Publishing message", exchange=exchangeName, mandatory=mandatory, immediate=immediate
    sendFrame(conn, stream, channel=channel)


proc basicPublishOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## Server responding to a successful queue.purge request
    ## 
    debug "Published message"

