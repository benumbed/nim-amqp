## 
## Tests for the `queue` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/protocol
import nim_amqp/field_table

const exchName = "queue-tests-exchange"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
conn.connectionOpen("/")
conn.channelOpen(channelNum)
conn.exchangeDeclare(exchName, "direct", false, true, false, false, false, FieldTable(), channelNum)

suite "AMQP Queue tests":
    test "Can create a new queue":
        conn.queueDeclare("unit-test-queue", false, true, false, true, false, FieldTable(), channelNum)

    test "Can delete a queue":
        conn.queueDeclare("unit-test-queue-delete", false, true, false, true, false, FieldTable(), channelNum)
        conn.queueDelete("unit-test-queue-delete", false, true, false, channelNum)

    test "Can bind to exchange":
        const queueName = "unit-test-queue-bind"
        conn.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        conn.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)

        conn.queueDelete(queueName, false, true, false, channelNum)

    test "Can bind multiple times without error":
        const queueName = "unit-test-queue-multibind"
        conn.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        conn.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        conn.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        conn.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)

        conn.queueDelete(queueName, false, true, false, channelNum)

    test "Can unbind queue from exchange":
        const queueName = "unit-test-queue-unbind"
        conn.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        conn.queueBind(queueName, exchName, "banana", false, FieldTable(), channelNum)
        conn.queueUnBind(queueName, exchName, "banana", FieldTable(), channelNum)

        conn.queueDelete(queueName, false, true, false, channelNum)

    test "Can purge queue":
        const queueName = "unit-test-queue-unbind"
        conn.queueDeclare(queueName, false, true, false, true, false, FieldTable(), channelNum)

        conn.queuePurge(queueName, false, channelNum)

        conn.queueDelete(queueName, false, true, false, channelNum)

conn.exchangeDelete("queue-tests-exchange", false, false, channelNum)
conn.channelClose(1)
conn.connectionClose()