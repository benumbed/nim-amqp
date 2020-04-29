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


proc negotiateVersion*(comm: AMQPCommunication)


proc newAMQPConnection*(host, username, password: string, port = 5672, connectTimeout = 500, readTimeout = 500, 
                       amqpVersion = "0.9.1"): AMQPCommunication =
    result.conn = new(AMQPConnection)
    result.chan = AMQPChannel()
    result.chan.curFrame = AMQPFrame(payloadType: ptStream)
    result.tracker = AMQPChannelTracker()

    result.conn.sock = newSocket(buffered=true)
    result.conn.sock.connect(host, Port(port), timeout=connectTimeout)
    result.conn.readTimeout = readTimeout
    result.conn.meta.version = amqpVersion
    result.conn.username = username
    result.conn.password = password

    result.conn.frames.handler = handleFrame
    result.conn.frames.sender = sendFrame

    result.negotiateVersion()



proc negotiateVersion(comm: AMQPCommunication) =
    let conn = comm.conn
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
    conn.frames.handler(data)
