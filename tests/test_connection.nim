## 
## Tests for the `connection` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/protocol
import nim_amqp/classes/connection

suite "Connection module tests":
    test "Correct SASL credentials do not raise":
        let conn = newAMQPConnection("localhost", "guest", "guest")
        conn.connectionClose()

    test "Incorrect SASL credentials raise":
        expect AMQPConnectionError:
            discard newAMQPConnection("localhost", "baduser", "badpass")

    test "Can connect to a vhost":
        let conn = newAMQPConnection("localhost", "guest", "guest")

        conn.connectionOpen("/")
        conn.connectionClose()
