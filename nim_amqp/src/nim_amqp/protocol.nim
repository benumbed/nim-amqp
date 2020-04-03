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


proc negotiateVersion*(conn: AMQPConnection, amqpVersion: string, readTimeout=500)


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 500, readTimeout = 500, 
                       amqpVersion = "0.9.1"): AMQPConnection =
    new(result)
    result.sock = newSocket(buffered=true)
    result.sock.connect(host, Port(port), timeout=connectTimeout)
    result.readTimeout = readTimeout
    result.version = amqpVersion
    result.username = username
    result.password = password

    result.frameHandler = handleFrame
    result.frameSender = sendFrame

    result.negotiateVersion(amqpVersion, readTimeout)


proc negotiateVersion(conn: AMQPConnection, amqpVersion: string, readTimeout=500) =
    let sent = conn.sock.trySend(wireAMQPVersion(amqpVersion))
    if not sent:
        raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # Read only the header, unless it's a version response, then we're missing a byte (will be handled elsewhere)
    var data = conn.sock.recv(7, readTimeout)

    if data[0..3] == "AMQP":
        data.add(conn.sock.recv(1, readTimeout))
        raise newException(AMQPVersionError, 
            fmt"Server does not support {amqpVersion}, sent: {data.readRawAMQPVersion()}")
    
    conn.version = amqpVersion

    # Handle the rest of the connection initiation
    conn.frameHandler(conn, data)
