## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams
import strformat

import ./errors
import ./frames
import ./types
import ./utils

type AMQPProtocolError* = object of AMQPError
type AMQPVersionError* = object of AMQPError


proc negotiateVersion*(conn: AMQPConnection, amqpVersion: string, readTimeout=500)


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 100, readTimeout = 500, amqpVersion = "0.9.1"): AMQPConnection =
    result.sock = newSocket(buffered=true)
    result.sock.connect(host, Port(5672), timeout=connectTimeout)
    result.readTimeout = readTimeout
    result.version = amqpVersion
    result.stream = newStringStream()
    result.username = username
    result.password = password

    result.negotiateVersion(amqpVersion, readTimeout)
    result.handleFrame()


proc negotiateVersion(conn: AMQPConnection, amqpVersion: string, readTimeout=500) =
    let sent = conn.sock.trySend(wireAMQPVersion(amqpVersion))
    if not sent:
        raise newException(AMQPVersionError, "Failed to send AMQP version string")

    # Read only the header, unless it's a version response, then we're missing a byte (will be handled elsewhere)
    let rec = conn.sock.recv(7, readTimeout)
    conn.stream.write(rec)
    conn.stream.flush()
    conn.stream.setPosition(0)

    if conn.stream.peekStr(4) == "AMQP":
        conn.stream.setPosition(7)
        conn.stream.write(conn.sock.recv(1, readTimeout))
        conn.stream.setPosition(0)
        raise newException(AMQPVersionError, fmt"Server does not support {amqpVersion}, sent: {conn.stream.readStr(8).readRawAMQPVersion()}")
