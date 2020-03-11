## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import net
from asyncnet import nil

when isMainModule:
    let ssl_ctx = net.newContext()
    var sock = asyncnet.newAsyncSocket()
    asyncnet.wrapSocket(ssl_ctx, sock)

    let con_futr = asyncnet.connect(sock, "172.29.42.39", Port(5672))

    echo "SSL: ", asyncnet.isSsl(sock)
    
    # asyncnet.close(sock)