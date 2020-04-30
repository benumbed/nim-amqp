## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import strformat

import ./errors
import ./frames
import ./types
import ./utils

type AMQPProtocolError* = object of AMQPError
type AMQPVersionError* = object of AMQPError

proc negotiateVersion(conn: AMQPConnection)


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 500, readTimeout = 500, 
                       amqpVersion = "0.9.1"): AMQPConnection =
    new(result)

    result.sock = newSocket(buffered=true)
    result.sock.connect(host, Port(port), timeout=connectTimeout)
    result.readTimeout = readTimeout
    result.meta.version = amqpVersion
    result.username = username
    result.password = password

    result.negotiateVersion()


proc negotiateVersion(conn: AMQPConnection) =
    let sent = conn.sock.trySend(wireAMQPVersion(conn.meta.version))
    if not sent:
        raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # Read only the header, unless it's a version response, then we're missing a byte (will be handled elsewhere)
    var data = conn.sock.recv(7, conn.readTimeout)

    if data[0..3] == "AMQP":
        data.add(conn.sock.recv(1, conn.readTimeout))
        raise newException(AMQPVersionError, 
            fmt"Server does not support {conn.meta.version}, sent: {data.readRawAMQPVersion()}")
    
    # Handle the rest of the connection initiation
    let chan = conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame)
    chan.frames.handler(chan, preFetched=data)
