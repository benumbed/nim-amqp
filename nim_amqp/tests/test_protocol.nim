## 
## Tests for the `protocol` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams
import unittest

import nim_amqp/protocol


test "correctly reads AMQP version from server on error":
    expect AMQPVersionError:
        discard newAMQPConnection("localhost", amqpVersion="0.9.0")


test "times out on non-response from server":
    expect TimeoutError:
        discard newAMQPConnection("localhost", amqpVersion="0.9", readTimeout=100)


test "returns frame structure on successful version negotiation":
    let conn = newAMQPConnection("localhost", readTimeout=100)

    let frame = conn.readFrame()

    check:
        frame.frameType == 1
        frame.channel == 0
    
    discard frame.payload.readStr(int(frame.payloadSize))
    check:
        frame.payload.atEnd()