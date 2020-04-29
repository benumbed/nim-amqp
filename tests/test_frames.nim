## 
## Tests for the `frames` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/protocol
import nim_amqp/classes/connection

let conn = newAMQPConnection("localhost", "guest", "guest")

suite "Tests for the frames module":

    test "Can send heartbeat to server":
        

conn.connectionClose()