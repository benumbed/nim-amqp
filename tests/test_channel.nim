## 
## Tests for the `channel` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/frames
import nim_amqp/types
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/protocol

let conn = newAMQPConnection("localhost", "guest", "guest")
let chan = conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame)
chan.connectionOpen("/")

suite "AMQP Channel tests":
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


    test "Can open and close channels":
        const chanNum = 10
        let testChan = conn.newAMQPChannel(number=chanNum, frames.handleFrame, frames.sendFrame)
        testChan.channelOpen()

        check:
            testChan.active == true
            testChan.flow == true
            testChan.number == chanNum

        testChan.channelClose()

        check:
            testChan.active == false
            testChan.number == chanNum


chan.connectionClose()