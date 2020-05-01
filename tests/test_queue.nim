## 
## Tests for the `queue` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue

const exchName = "queue-tests-exchange"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen("/")

let chan = conn.newAMQPChannel(number=channelNum, frames.handleFrame, frames.sendFrame)
chan.channelOpen()

chan.exchangeDeclare(exchName, "direct", false, true, false, false, false)

suite "AMQP Queue tests":
    test "Can create a new queue":
        chan.queueDeclare("unit-test-queue", false, true, false, true, false)

    test "Can delete a queue":
        chan.queueDeclare("unit-test-queue-delete", false, true, false, true, false)
        chan.queueDelete("unit-test-queue-delete", false, true, false)

    test "Can bind to exchange":
        const queueName = "unit-test-queue-bind"
        chan.queueDeclare(queueName, false, true, false, true, false)

        chan.queueBind(queueName, exchName, "banana", false)

        chan.queueDelete(queueName, false, true, false)

    test "Can bind multiple times without error":
        const queueName = "unit-test-queue-multibind"
        chan.queueDeclare(queueName, false, true, false, true, false)

        chan.queueBind(queueName, exchName, "banana", false)
        chan.queueBind(queueName, exchName, "banana", false)
        chan.queueBind(queueName, exchName, "banana", false)

        chan.queueDelete(queueName, false, true, false)

    test "Can unbind queue from exchange":
        const queueName = "unit-test-queue-unbind"
        chan.queueDeclare(queueName, false, true, false, true, false)

        chan.queueBind(queueName, exchName, "banana", false)
        chan.queueUnBind(queueName, exchName, "banana")

        chan.queueDelete(queueName, false, true, false)

    test "Can purge queue":
        const queueName = "unit-test-queue-unbind"
        chan.queueDeclare(queueName, false, true, false, true, false)

        chan.queuePurge(queueName, false)

        chan.queueDelete(queueName, false, true, false)

chan.exchangeDelete("queue-tests-exchange", false, false)
chan.channelClose()
chan.connectionClose()