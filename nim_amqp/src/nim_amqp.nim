## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import strformat
import net
import system
import strutils

when isMainModule:
    # let ssl_ctx = net.newContext()
    # var sock = asyncnet.newAsyncSocket()
    var sock = newSocket(buffered=true)
    # asyncnet.wrapSocket(ssl_ctx, sock)

    sock.connect("localhost", Port(5672), 5)

    let header = "AMQP\0\0\9\1"
    let sent = sock.trySend(header)

    
    let data = sock.recv(64, 500)
    if data.len() == 0:
        echo "Response from server was empty!"
        system.quit(QuitFailure)

    let zero_idx_bytes = 3
    var payload_size: uint32 = 0;
    for i in 0..zero_idx_bytes:
        payload_size = payload_size or (uint32(data[i+zero_idx_bytes]) shl ((zero_idx_bytes-i)*8))

    echo fmt"Payload Size: {payload_size:#x}"

    sock.close()
