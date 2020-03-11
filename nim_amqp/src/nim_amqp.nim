## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import strformat
import net
import os

when isMainModule:
    # let ssl_ctx = net.newContext()
    # var sock = asyncnet.newAsyncSocket()
    var sock = newSocket(buffered=true)
    # asyncnet.wrapSocket(ssl_ctx, sock)

    sock.connect("localhost", Port(5672), 5)

    let header = "AMQP\0\0\9\1\c\l"
    let sent = sock.trySend(header)

    echo "buffered: ", sock.hasDataBuffered()

    let data = sock.recv(8, 500)
    let cr = int(data[3])
    echo fmt"Data: {data[1]:#x} 7: {cr:#x}"

    sock.close()

    # asyncnet.close(sock)
    
    # asyncnet.close(sock)