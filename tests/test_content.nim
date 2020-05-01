## 
## Tests for the `content` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/classes/basic
import nim_amqp/content
import nim_amqp/field_table

const exchName = "content-tests-exchange"
const queueName = "content-tests-queue"

let chan = connect("localhost", "guest", "guest").createChannel()

chan.exchangeDeclare(exchName, "direct", false, true, false, false, false)
chan.queueDeclare(queueName, false, true, false, true, false)
chan.queueBind(queueName, exchName, "content-test", false)

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


chan.queueUnBind(queueName, exchName, "content-test")
chan.exchangeDelete(exchName, false, false)
chan.channelClose()
chan.connectionClose(reply_text="Test Shutdown")