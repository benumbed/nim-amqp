## 
## Tests for the `content` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp
import nim_amqp/content
import nim_amqp/types
import nim_amqp/classes/basic

const exchName = "content-tests-exchange"
const queueName = "content-tests-queue"

let chan = connect("localhost", "guest", "guest").createChannel()
chan.createExchange(exchName, "direct")
chan.createAndBindQueue(queueName, exchName, "content-test")

suite "Content library tests (pub/sub)":
    # test "Can consume a message from a queue":
    #     var props = AMQPBasicProperties()
    #     props.contentType = "application/json"
    #     props.deliveryMode = 2
    #     props.headers = FieldTable()

    #     var header = AMQPContentHeader()
    #     header.propertyList = props
    #     header.classId = 60

    #     let content = "{\"somekey\": \"someval\"}"

    #     header.bodySize = uint64(content.len)

    #     conn.basicPublish(exchName, "content-test", false, false)
    #     conn.sendContentHeader(header)
    #     conn.sendContentBody(content)


    test "Can create a message to publish":
        var props = AMQPBasicProperties()
        props.contentType = "application/json"
        props.deliveryMode = 2
        props.headers = FieldTable()

        var header = AMQPContentHeader()
        header.propertyList = props
        header.classId = 60

        let content = "{\"somekey\": \"someval\"}"

        header.bodySize = uint64(content.len)

        chan.basicPublish(exchName, "content-test", false, false)
        chan.sendContentHeader(header)
        chan.sendContentBody(content)

chan.removeExchange(exchName)
chan.disconnect()
