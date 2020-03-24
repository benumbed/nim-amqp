## 
## Tests for the `methods` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import unittest

import nim_amqp/methods
import nim_amqp/protocol


test "extractMethod correctly parses a method frame":
    let conn = newAMQPConnection("localhost", readTimeout=100)
    let meth = conn.readFrame().extractMethod()

    check:
        meth.classId == 10  # connection
        meth.methodId == 10 # start