## 
## Tests for the `connection` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/connection


suite "Connection module tests":
    test "Correct SASL credentials do not raise":
        discard newAMQPConnection("localhost", "guest", "guest")

    test "Incorrect SASL credentials raise":
        expect AMQPConnectionError:
            discard newAMQPConnection("localhost", "baduser", "badpass")

    test "Can connect to a vhost":
        let conn = newAMQPConnection("localhost", "guest", "guest")
        let chan = conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame)
        chan.connectionOpen("/")
        chan.connectionClose()
