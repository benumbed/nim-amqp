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
# The spec body says the frame type is 4, but the grammar says 8, RabbitMQ followed the grammar, so do we
const FRAME_HEARTBEAT* = uint8(8)

const AMQP_CLASS_CONNECTION*: uint16 = 10
const AMQP_CLASS_CHANNEL*: uint16 = 20
const AMQP_CLASS_EXCHANGE*: uint16 = 40
const AMQP_CLASS_QUEUE*: uint16 = 50
const AMQP_CLASS_BASIC*: uint16 = 60
const AMQP_CLASS_TX*: uint16 = 90

const AMQP_FRAME_END*: uint8 = 0xCE

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
    FrameSenderProc* = proc (conn: AMQPChannel, frame: AMQPFrame = nil, expectResponse = false): StrWithError

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
        connectTimeout*: int
        maxReconnectAttempts*: int
        host*: string
        port*: Port
        tls*: bool
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
        curContent*: ContentData
        frames*: AMQPFrameHandling
        messageCallback*: ConsumerMsgCallback
        returnCallback*: MessageReturnCallback

    AMQPBasicProperties* = object
        contentType*: string         # MIME type
        contentEncoding*: string     # MIME encoding
        headers*: FieldTable
        deliveryMode*: DeliveryMode # non-persistent (1) or persistent (2)
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

    DeliveryMode* = enum
        Transient = 1'u8,
        Persistent = 2'u8

    AMQPContentHeader* = object
        classId*: uint16            # Not used when publishing data to the server (ignored)
        weight*: uint16             # This is unused
        bodySize*: uint64
        propertyFlags*: uint16
        propertyList*: AMQPBasicProperties

    ContentMetadata* = object
        consumerTag*: string
        deliveryTag*: uint64
        redelivered*: bool
        exchangeName*: string
        routingKey*: string

    ContentData* = object
        header*: AMQPContentHeader
        body*: Stream
        bodyLen*: uint64
        metadata*: ContentMetadata

    ConsumerMsgCallback* = proc(chan: AMQPChannel, message: ContentData)
    MessageReturnCallback* = proc(chan: AMQPChannel, replyCode: uint16, replyText: string, exchangeName: string, 
                                routingKey: string)


type DispatchMethod* = proc(chan: AMQPChannel)
type MethodMap* = Table[uint16, DispatchMethod]
type DispatchMap* = Table[uint16, MethodMap]
