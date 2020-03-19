## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import system

import nim_amqp/connection
import nim_amqp/protocol

when isMainModule:
    # let ssl_ctx = net.newContext()
    # var sock = asyncnet.newAsyncSocket()
    var sock = newSocket(buffered=true)
    sock.connect("localhost", Port(5672), 5)
    # asyncnet.wrapSocket(ssl_ctx, sock)

    let frame = sock.readFrame()

    sock.close()
