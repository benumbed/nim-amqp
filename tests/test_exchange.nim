## 
## Tests for the `exchange` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/field_table
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange

let conn = newAMQPConnection("localhost", "guest", "guest")
conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen("/")

let chan = conn.newAMQPChannel(number=10, frames.handleFrame, frames.sendFrame)
chan.channelOpen()

suite "AMQP Exchange tests":
    test "Can create a new exchange":
        chan.exchangeDeclare("unit-test-exchange", "direct", false, true, true, false, false, FieldTable(), 1)

    test "Can delete an exchange":
        chan.exchangeDeclare("unit-test-delete-exchange", "direct", false, true, true, false, false, FieldTable(), 1)
        chan.exchangeDelete("unit-test-delete-exchange", false, false, 1)

chan.channelCloseClient()
chan.connectionCloseClient()