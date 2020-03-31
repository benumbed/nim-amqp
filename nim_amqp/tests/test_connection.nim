## 
## Tests for the `connection` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
# import net
# import tables
# import unittest

# import nim_amqp/protocol
# import nim_amqp/field_table
# import nim_amqp/classes/connection


# test "correctly builds connection.start from wire":
#     let conn = newAMQPConnection("localhost", readTimeout=100)

#     let meth = conn.readFrame().extractMethod()
#     let conn_start = meth.extractConnectionStart()
#     let capabilities = conn_start.serverProperties["capabilities"].tableVal

#     check:
#         conn_start.versionMajor == 0
#         conn_start.versionMinor == 9
#         conn_start.mechanisms == @["PLAIN", "AMQPLAIN"]
#         # FIXME: Going to have to figure out how to support non-US locales in the tests
#         conn_start.locales == @["en_US"]
#         # This depends on using RabbitMQ for the test suite, because that's what I use
#         conn_start.serverProperties.hasKey("product")
#         conn_start.serverProperties["product"].longStringVal == "RabbitMQ"
#         capabilities.hasKey("direct_reply_to")
#         capabilities.hasKey("basic.nack")

#         conn_start.classId == 10  # connection
#         conn_start.methodId == 10 # start

# test "connection.start-ok":
#     let startOk = newMethodConnectionStartOk()
#     startOk.response = ""
#     startOk.mechanism = "PLAIN"
#     startOk.locale = "en_US"

#     let startOkWire = startOk.toWire()