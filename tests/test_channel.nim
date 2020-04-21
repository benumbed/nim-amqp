## 
## Tests for the `channel` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest
import tables

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/protocol

let conn = newAMQPConnection("localhost", "guest", "guest")
conn.connectionOpen("/")

suite "AMQP Channel tests":
    test "Can open a new channel to the server":
        conn.channelOpen(1)

        check:
            1 in conn.openChannels


    # RabbitMQ does not support flow control using channel.flow
    # test "Can pause and resume flow on an active channel":
    #     conn.channelOpen(12)
    #     conn.channelFlow(false, 12)

    #     check:
    #         conn.openChannels[12].flow == false

    #     conn.channelFlow(true, 12)

    #     check:
    #         conn.openChannels[1].flow == true

    #     conn.channelClose(12)


    test "Can close an opened channel":
        conn.channelOpen(10)

        check:
            10 in conn.openChannels

        conn.channelClose(10)

        check:
            10 notin conn.openChannels


conn.connectionClose()