## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import strformat
import system

import nim_amqp/methods
import nim_amqp/protocol
import nim_amqp/classes/connection

proc connect(host: string, port = 5672, saslMechanism = "PLAIN"): AMQPConnection =
    ## Creates a new AMQP connection
    result = newAMQPConnection(host, port)
    let meth = result.readFrame().extractMethod()
    let connStart = meth.extractConnectionStart()

    if not (saslMechanism in connStart.mechanisms):
        raise newException(AMQPError, fmt"Invalid SASL mechanism specified, server provides: {connStart.mechanisms}")

when isMainModule:
    # let ssl_ctx = net.newContext()
    # var sock = asyncnet.newAsyncSocket()
    var sock = newSocket(buffered=true)
    sock.connect("localhost", Port(5672), 5)
    # asyncnet.wrapSocket(ssl_ctx, sock)

    let frame = sock.readFrame()

    sock.close()
