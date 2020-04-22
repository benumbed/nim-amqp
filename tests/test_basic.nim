## 
## Tests for the `basic` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/classes/basic
import nim_amqp/protocol
import nim_amqp/field_table

const exchName = "queue-tests-exchange"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
conn.connectionOpen("/")
conn.channelOpen(channelNum)
conn.exchangeDeclare(exchName, "direct", false, true, false, false, false, FieldTable(), channelNum)

suite "AMQP Basic tests":
    test "Can set QoS parameters":
        conn.basicQos(256, false, channelNum)

    test "Can start a consumer":
        let qName = "unit-test-basic-consume"
        conn.queueDeclare(qName, false, true, false, true, false, FieldTable(), channelNum)
        conn.basicConsume(qName, "", false, false, false, false, FieldTable(), channelNum)

    test "Can cancel a consumer":
        let qName = "unit-test-basic-consume-cancel"
        conn.queueDeclare(qName, false, true, false, true, false, FieldTable(), channelNum)
        conn.basicConsume(qName, "consumer-cancel-test", false, false, false, false, FieldTable(), channelNum)
        conn.basicCancel("consumer-cancel-test", false, channelNum)

conn.exchangeDelete("queue-tests-exchange", false, false, channelNum)
conn.channelClose(1)
conn.connectionClose()