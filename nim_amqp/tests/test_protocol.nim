## 
## Tests for the `protocol` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import unittest

import streams

import nim_amqp/protocol


# test "correctly reads AMQP version from server on error":
#     expect AMQPVersionError:
#         discard newAMQPConnection("localhost", "nouser", "nopass", amqpVersion="0.9.0")


# test "times out on non-response from server":
#     expect TimeoutError:
#         discard newAMQPConnection("localhost", "nouser", "nopass", amqpVersion="0.9", readTimeout=100)


test "SASL":
    # var strm = newStringStream("The first line\nthe second line\nthe thirdline")
    # doAssert strm.readAll() == "The first line\nthe second line\nthe third line"
    # doAssert strm.atEnd() == true
    # strm.close()

    # let stream = newStringStream()

    # stream.write("blahw")
    # stream.setPosition(0)

    # let str = stream.readAll()
    # echo stream.len

    let conn = newAMQPConnection("localhost", "guest", "guest", readTimeout=5000)