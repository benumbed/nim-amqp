## 
## Tests for the `connection` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import unittest

import nim_amqp/connection
import nim_amqp/methods
import nim_amqp/protocol


test "correctly builds connection.start from wire":
    var sock = newSocket(buffered=true)
    sock.connect("localhost", Port(5672), timeout=100)

    let meth = sock.readFrame().extractMethod()
    let conn_start = meth.extractConnectionStart()

    check:
        conn_start.versionMajor == 0
        conn_start.versionMinor == 9
        conn_start.mechanisms == @["PLAIN", "AMQPLAIN"]

        conn_start.classId == 10  # connection
        conn_start.methodId == 10 # start

    sock.close()