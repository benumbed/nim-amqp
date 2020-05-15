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

    FieldTableValueType* = enum
        ftBadField = 0
        ftFieldArray = 'A',
        ftShortShortUint = 'B',
        ftDecimalValue = 'D',
        ftFieldTable = 'F',
        ftLongInt = 'I',
        ftLongLongInt = 'L',
        ftLongString = 'S',
        ftTimestamp = 'T',
        ftNoField = 'V',
        ftShortShortInt = 'b',
        ftDouble = 'd',
        ftFloat = 'f',
        ftLongUint = 'i',
        # ftLongLongUint = 'L',
        ftShortInt = 's',
        # ftShortString = 's',
        ftBool = 't',
        ftShortUint = 'u'

    FieldTable* = ref OrderedTable[string, FieldTableValue]
    
    FieldTableValue* = ref object
        case valType*: FieldTableValueType
        of ftBool: boolVal*: bool
        of ftShortShortInt: int8Val*: int8
        of ftShortShortUint: uint8Val*: uint8
        of ftShortInt: int16Val*: int16
        of ftShortUint: uint16Val*: uint16
        of ftLongInt: int32Val*: int32
        of ftLongUint: uint32Val*: uint32
        of ftLongLongInt: int64Val*: int64
        # of ftLongLongUint: uint64Val*: uint64
        of ftFloat: floatVal*: float32
        of ftDouble: doubleVal*: float64
        of ftDecimalValue: decimalVal*: FieldTableDecimal
        # of ftShortString: shortStringVal*: string
        of ftLongString: longStringVal*: string
        of ftFieldArray: arrayVal*: seq[FieldTableValue]
        of ftFieldTable: tableVal*: FieldTable
        of ftTimestamp: timestampVal*: uint64
        of ftNoField: noField*: bool
        of ftBadField: badField*: bool
        
    FieldTableDecimal* = object
        decimalLoc*: uint8
        value*: uint32

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
        curContentHeader*: AMQPContentHeader
        curContentBody*: Stream
        curContentBodyLen*: uint64  # Needed because the body's most likely a stream
        frames*: AMQPFrameHandling
        messageCallback*: ConsumerMsgCallback

    AMQPBasicProperties* = object
        contentType*: string         # MIME type
        contentEncoding*: string     # MIME encoding
        headers*: FieldTable
        deliveryMode*: uint8         # non-persistent (1) or persistent (2)
        priority*: uint8 
        correlationId*: string
        replyTo*: string
        expiration*: string
        messageId*: string
        timestamp*: uint64
        messageType*: string         # `type`
        userId*: string
        appId*: string
        reserved*: string            # Must be empty

    AMQPContentHeader* = object
        classId*: uint16
        # This is unused
        weight*: uint16
        bodySize*: uint64
        propertyFlags*: uint16
        propertyList*: AMQPBasicProperties

    ConsumerMsgCallback* = proc(chan: AMQPChannel, header: AMQPContentHeader, body: Stream)


type DispatchMethod* = proc(chan: AMQPChannel)
type MethodMap* = Table[uint16, DispatchMethod]
type DispatchMap* = Table[uint16, MethodMap]
