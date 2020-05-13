## 
## Global types
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import asyncnet
import net
import streams
import tables

import ./errors

# Frame types (AMQP 0-9-1 -- 4.2.3)
const FRAME_METHOD* = uint8(1)
const FRAME_CONTENT_HEADER* = uint8(2)
const FRAME_CONTENT_BODY* = uint8(3)
const FRAME_HEARTBEAT* = uint8(4)


type AMQPFramePayloadType* = enum
    ptStream,
    ptString

# AMQP 0-9-1 -- 2.3.5
type AMQPFrame* = ref object
    frameType*: uint8
    channel*: uint16
    payloadSize*: uint32
    case payloadType*: AMQPFramePayloadType
    of ptStream: payloadStream*: Stream
    of ptString: payloadString*: string

type
    FrameHandlerProc* = proc(chan: AMQPChannel, blocking = true)
    FrameSenderProc* = proc (conn: AMQPChannel): StrWithError

    AMQPTuning* = object
        channelMax*: uint16
        frameMax*: uint32
        heartbeat*: uint16

    AMQPConnectionMeta* = object
        version*: string
        locales*: seq[string]
        mechanisms*: seq[string]
        isRMQCompatible*: bool

    AMQPFrameHandling* = object
        handler*: FrameHandlerProc
        sender*: FrameSenderProc

    AMQPConnectionObj = ref object of RootObj
        readTimeout*: int
        username*: string
        password*: string
        ready*: bool
        meta*: AMQPConnectionMeta
        tuning*: AMQPTuning

    AMQPAsyncConnection* = ref object of AMQPConnectionObj
        sock*: AsyncSocket

    AMQPConnection* = ref object of AMQPConnectionObj
        sock*: Socket

    AMQPChannel* = ref AMQPChannelObj
    AMQPChannelObj = object
        conn*: AMQPConnection
        number*: uint16
        active*: bool
        flow*: bool
        curFrame*: AMQPFrame
        frames*: AMQPFrameHandling


type DispatchMethod* = proc(chan: AMQPChannel)
type MethodMap* = Table[uint16, DispatchMethod]
type DispatchMap* = Table[uint16, MethodMap]
