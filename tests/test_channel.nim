## 
## Tests for the `channel` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/protocol

suite "AMQP Channel tests":
    test "Can open a new channel to the server":
        let conn = newAMQPConnection("localhost", "guest", "guest")

        conn.connectionOpen("/")
        conn.channelOpen(1)

        check:
            1 in conn.openChannels

        conn.connectionClose()