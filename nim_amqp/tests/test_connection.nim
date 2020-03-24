## 
## Tests for the `connection` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import tables
import unittest

import nim_amqp/connection
import nim_amqp/methods
import nim_amqp/protocol
import nim_amqp/field_table


test "correctly builds connection.start from wire":
    var sock = newSocket(buffered=true)
    sock.connect("localhost", Port(5672), timeout=100)

    let meth = sock.readFrame().extractMethod()
    let conn_start = meth.extractConnectionStart()

    echo conn_start.serverProperties

    let capabilities = conn_start.serverProperties["capabilities"].tableVal

    check:
        conn_start.versionMajor == 0
        conn_start.versionMinor == 9
        conn_start.mechanisms == @["PLAIN", "AMQPLAIN"]
        # This depends on using RabbitMQ for the test suite, because that's what I use
        conn_start.serverProperties.hasKey("product")
        conn_start.serverProperties["product"].longStringVal == "RabbitMQ"
        capabilities.hasKey("direct_reply_to")
        capabilities.hasKey("basic.nack")

        conn_start.classId == 10  # connection
        conn_start.methodId == 10 # start

    sock.close()