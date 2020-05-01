## 
## Tests for the `content` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/classes/basic
import nim_amqp/content
import nim_amqp/field_table
import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types

const exchName = "content-tests-exchange"
const queueName = "content-tests-queue"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen("/")

let chan = conn.newAMQPChannel(number=channelNum, frames.handleFrame, frames.sendFrame)
chan.channelOpen()
chan.exchangeDeclare(exchName, "direct", false, true, false, false, false, FieldTable(), channelNum)
chan.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)
chan.queueBind(queueName, exchName, "content-test", false, FieldTable(), channelNum)

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

    #     conn.basicPublish(exchName, "content-test", false, false, channelNum)
    #     conn.sendContentHeader(header, channelNum)
    #     conn.sendContentBody(content, channelNum)


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

        chan.basicPublish(exchName, "content-test", false, false, channelNum)
        chan.sendContentHeader(header, channelNum)
        chan.sendContentBody(content, channelNum)


chan.queueUnBind(queueName, exchName, "content-test", FieldTable(), channelNum)
chan.exchangeDelete(exchName, false, false, channelNum)
chan.channelClose()
chan.connectionClose(reply_text="Test Shutdown")