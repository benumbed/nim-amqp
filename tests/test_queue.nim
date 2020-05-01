## 
## Tests for the `queue` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/field_table
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

chan.exchangeDeclare(exchName, "direct", false, true, false, false, false, FieldTable(), channelNum)

suite "AMQP Queue tests":
    test "Can create a new queue":
        chan.queueDeclare("unit-test-queue", false, true, false, true, false, FieldTable(), channelNum)

    test "Can delete a queue":
        chan.queueDeclare("unit-test-queue-delete", false, true, false, true, false, FieldTable(), channelNum)
        chan.queueDelete("unit-test-queue-delete", false, true, false, channelNum)

    test "Can bind to exchange":
        const queueName = "unit-test-queue-bind"
        chan.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        chan.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)

        chan.queueDelete(queueName, false, true, false, channelNum)

    test "Can bind multiple times without error":
        const queueName = "unit-test-queue-multibind"
        chan.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        chan.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        chan.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        chan.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)

        chan.queueDelete(queueName, false, true, false, channelNum)

    test "Can unbind queue from exchange":
        const queueName = "unit-test-queue-unbind"
        chan.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        chan.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        chan.queueUnBind(queueName, exchName, "banana", FieldTable(), channelNum)

        chan.queueDelete(queueName, false, true, false, channelNum)

    test "Can purge queue":
        const queueName = "unit-test-queue-unbind"
        chan.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        chan.queuePurge(queueName, false, channelNum)

        chan.queueDelete(queueName, false, true, false, channelNum)

chan.exchangeDelete("queue-tests-exchange", false, false, channelNum)
chan.channelCloseClient()
chan.connectionCloseClient()