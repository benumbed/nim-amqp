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
    var sock = newSocket(buffered=true)
    sock.connect("localhost", Port(5672), timeout=100)

    let frame = sock.readFrame()
    let meth = frame.extractMethod()

    check:
        meth.classId == 10  # connection
        meth.methodId == 10 # start

    sock.close()
