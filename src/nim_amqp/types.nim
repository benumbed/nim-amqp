## 
## Global types
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import net
import streams
import tables

import ./errors

type AMQPFramePayloadType* = enum
    ptStream,
    ptString

type AMQPFrame* = ref object
    frameType*: uint8
    channel*: uint16
    payloadSize*: uint32
    case payloadType*: AMQPFramePayloadType
    of ptStream: payloadStream*: Stream
    of ptString: payloadString*: string

type AMQPChannelMeta* = object
    active*: bool
    flow*: bool

type
    FrameHandlerProc* = proc(conn: AMQPConnection, preFetched: string = "")

    AMQPConnection* = ref object
        readTimeout*: int
        sock*: Socket
        version*: string
        locales*: seq[string]
        mechanisms*: seq[string]
        username*: string
        password*: string
        connectionReady*: bool
        frameHandler*: FrameHandlerProc
        frameSender*: proc (conn: AMQPConnection, frame: AMQPFrame): StrWithError
        isRMQCompatible*: bool
        openChannels*: Table[uint16, AMQPChannelMeta]


type DispatchMethod* = proc(conn: AMQPConnection, stream: Stream, channel: uint16)
type MethodMap* = Table[uint16, DispatchMethod]
type DispatchMap* = Table[uint16, MethodMap]