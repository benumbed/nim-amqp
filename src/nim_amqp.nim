## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
# import net
import strformat
import system
import asyncnet, asyncdispatch

import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/connection



proc connect*(host, username, password: string, vhost="/", port = 5672, tuning = AMQPTuning()): AMQPConnection =
    ## Creates a new AMQP connection
    result = newAMQPConnection(host, username, password, port)
    result.tuning = tuning
    result.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen(vhost)

when isMainModule:
    # let ssl_ctx = net.newContext()
    var sock = newAsyncSocket()
    # var sock = newSocket(buffered=true)
    waitFor sock.connect("localhost", Port(5672))
    # asyncnet.wrapSocket(ssl_ctx, sock)

    # let frame = sock.readFrame()

    runForever()

    sock.close()
