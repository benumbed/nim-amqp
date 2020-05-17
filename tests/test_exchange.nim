## 
## Tests for the `exchange` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange

let conn = newAMQPConnection("localhost", "guest", "guest")
let zeroChan = conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame)
zeroChan.connectionOpen("/")

let chan = conn.newAMQPChannel(number=10, frames.handleFrame, frames.sendFrame)
chan.channelOpen()

suite "AMQP Exchange tests":
    test "Can create a new exchange":
        chan.exchangeDeclare("unit-test-exchange", "direct", false, true, true, false, false)

    test "Can delete an exchange":
        chan.exchangeDeclare("unit-test-delete-exchange", "direct", false, true, true, false, false)
        chan.exchangeDelete("unit-test-delete-exchange", false, false)

chan.channelClose()
zeroChan.connectionClose()