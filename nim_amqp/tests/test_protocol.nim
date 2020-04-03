## 
## Tests for the `protocol` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import unittest

import nim_amqp/protocol


test "correctly reads AMQP version from server on error":
    expect AMQPVersionError:
        discard newAMQPConnection("localhost", "nouser", "nopass", amqpVersion="0.9.0")


test "times out on non-response from server":
    expect TimeoutError:
        discard newAMQPConnection("localhost", "nouser", "nopass", amqpVersion="0.9", readTimeout=100)

