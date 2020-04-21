## 
## Tests for the `exchange` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest
import tables

import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/protocol
import nim_amqp/field_table

let conn = newAMQPConnection("localhost", "guest", "guest")
conn.connectionOpen("/")
conn.channelOpen(1)

suite "AMQP Exchange tests":
    test "Can create a new exchange":
        conn.exchangeDeclare("unit-test-exchange", "direct", false, true, true, false, false, FieldTable(), 1)

    test "Can delete an exchange":
        conn.exchangeDeclare("unit-test-delete-exchange", "direct", false, true, true, false, false, FieldTable(), 1)
        conn.exchangeDelete("unit-test-delete-exchange", false, false, 1)

conn.channelClose(1)
conn.connectionClose()