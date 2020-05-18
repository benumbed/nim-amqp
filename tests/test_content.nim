## 
## Tests for the `content` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import unittest

import nim_amqp
import nim_amqp/content
import nim_amqp/types
import nim_amqp/classes/basic

const exchName = "content-tests-exchange"
const queueName = "content-tests-queue"
const routingKey = "content-test"

let chan = connect("localhost", "guest", "guest", port=5671, useTls=true).createChannel()
chan.createExchange(exchName, "direct")
chan.createAndBindQueue(queueName, exchName, routingKey)

suite "Content library tests (pub/sub)":
    test "Can consume a message from a queue":
        var props = AMQPBasicProperties()
        props.contentType = "application/json"
        props.deliveryMode = 2

        let content = "{\"somekey\": \"someval\"}"
        chan.publish(content, exchName, routingKey, properties=props)


        chan.basicConsume(queueName, routingKey, false, false, false, false)
        # basic.deliver
        chan.frames.handler(chan)
        # content header (will chain to body)
        chan.frames.handler(chan)

        check:
            chan.curContent.body.readAll() == content
            chan.curContent.header.propertyList.contentType == props.contentType
            chan.curContent.header.propertyList.deliveryMode == props.deliveryMode

        chan.basicAck(chan.curContent.metadata.deliveryTag)


    test "Can create a message to publish":
        var props = AMQPBasicProperties()
        props.contentType = "application/json"
        props.deliveryMode = 2
        props.headers = FieldTable()

        var header = AMQPContentHeader()
        header.propertyList = props
        header.classId = 60

        let content = "{\"somekey-publish\": \"someval2\"}"
        header.bodySize = uint64(content.len)

        chan.basicPublish(exchName, routingKey, false, false)
        chan.sendContentHeader(header)
        chan.sendContentBody(newStringStream(content))

chan.removeQueue(queueName)
chan.removeExchange(exchName)
chan.disconnect()
