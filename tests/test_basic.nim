## 
## Tests for the `basic` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/classes/basic


const exchName = "queue-tests-exchange"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
let zeroChan = conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame)
zeroChan.connectionOpen("/")

let chan = conn.newAMQPChannel(number=channelNum, frames.handleFrame, frames.sendFrame)
chan.channelOpen()

chan.exchangeDeclare(exchName, "direct", false, true, false, false, false)


suite "AMQP Basic tests":
    test "Can set QoS parameters":
        chan.basicQos(256, false)

    test "Can start a consumer":
        let qName = "unit-test-basic-consume"
        chan.queueDeclare(qName, false, true, false, true, false)
        chan.basicConsume(qName, false, false, false, false)

    test "Can cancel a consumer":
        let qName = "unit-test-basic-consume-cancel"
        chan.queueDeclare(qName, false, true, false, true, false)
        chan.basicConsume(qName, false, false, false, false)
        chan.basicCancel("consumer-cancel-test", false)

chan.exchangeDelete("queue-tests-exchange", false, false)
chan.channelClose()
zeroChan.connectionClose()
