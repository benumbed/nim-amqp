## 
## Describes an AMQP field-table
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import strutils
import system
import tables

import ./endian
import ./errors

# Maps field-table value types from the AMQP standard
# type FieldTableValueType_ActualAMQP091* = enum
#     ftBadField = 0
#     ftFieldArray = 'A',
#     ftShortShortUint = 'B',
#     ftDecimalValue = 'D',
#     ftFieldTable = 'F',
#     ftLongInt = 'I',
#     ftLongLongInt = 'L',
#     ftLongString = 'S',
#     ftTimestamp = 'T',
#     ftShortInt = 'U',
#     ftNoField = 'V',
#     ftShortShortInt = 'b',
#     ftDouble = 'd',
#     ftFloat = 'f',
#     ftLongUint = 'i',
#     ftLongLongUint = 'l',
#     ftShortString = 's',
#     ftBool = 't',
#     ftShortUint = 'u'

# ^v Because RabbitMQ's devs apparently can't get along with the AMQP 0-9-1 architects
# I'll have to figure out how to handle servers that actually honor the 0-9-1 spec down the road
type FieldTableValueType* = enum
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

type
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
        decimalLoc: uint8
        value: uint32

# ----------------------------------------------------------------------------------------------------------------------
# Forward Declarations
# ----------------------------------------------------------------------------------------------------------------------
proc `$`*(this: FieldTableValue): string
proc extractFieldTableValue(stream: Stream, valType: FieldTableValueType): FieldTableValue


# ----------------------------------------------------------------------------------------------------------------------
# String reprs
# ----------------------------------------------------------------------------------------------------------------------
proc toStrSeq(this: FieldTable): seq[string] =
    result.insert("\p")
    for key,value in this:
        result.insert(fmt("{key} = {value}"))

proc `$`*(this: FieldTable): string =
    result = this.toStrSeq.join("\p")

proc `$`*(this:FieldTableDecimal): string =
    var digits = $this.value
    result = fmt"{digits[0..(this.decimalLoc-1)]}.{this.decimalLoc..(len(digits)-1)}"

proc `$`*(this: FieldTableValue): string =
    case this.valType:
        of ftBool: result = $this.boolVal
        of ftShortShortInt: result = $this.int8Val
        of ftShortShortUint: result = $this.uint8Val
        of ftShortInt: result = $this.int16Val
        of ftShortUint: result = $this.uint16Val
        of ftLongInt: result = $this.int32Val
        of ftLongUint: result = $this.uint32Val
        of ftLongLongInt: result = $this.int64Val
        # of ftLongLongUint: result = $this.uint64Val
        of ftFloat: result = $this.floatVal
        of ftDouble: result = $this.doubleVal
        of ftDecimalValue: 
            if this.decimalVal.decimalLoc == 0:
                result = $this.decimalVal.value
            
            let valStr = $this.decimalVal.value
            result = [valStr[0..(this.decimalVal.decimalLoc-1)], ".", valStr[this.decimalVal.decimalLoc..(
                     sizeof(valStr)-1)]].join()
        # of ftShortString: result = $this.shortStringVal
        of ftLongString: result = $this.longStringVal
        of ftFieldArray: result = $this.arrayVal
        of ftFieldTable:
            let table = this.tableVal.toStrSeq().join("\p\t")
            result = fmt("\p\t{table}")
        of ftTimestamp: result = $this.timestampVal
        of ftNoField: result = $this.noField
        of ftBadField: result = $this.badField


proc toWire*(this: FieldTable): Stream = 
    ## Converts a FieldTable structure to it's wire format and returns the resulting string
    result = newStringStream()

    # keySize|key|valType(char)|<val size>|value
    for key, value in this:
        result.write(uint8(len(key)))
        result.write(key)
        result.write(value.valType)

        # Recurse for a value that has field-table type
        if value.valType == ftFieldTable:
            result.write(value.tableVal.toWire().readAll())
            continue

        case value.valType:
            of ftBool: result.write(byte(value.boolVal))
            of ftShortShortInt: result.write(value.int8Val)
            of ftShortShortUint: result.write(value.uint8Val)
            of ftShortInt: result.write(swapEndian(value.int16Val))
            of ftShortUint: result.write(swapEndian(value.uint16Val))
            of ftLongInt: result.write(swapEndian(value.int32Val))
            of ftLongUint: result.write(swapEndian(value.uint32Val))
            of ftLongLongInt: result.write(swapEndian(value.int64Val))
            # of ftLongLongUint: result.write(swapEndian(value.uint64Val))
            of ftFloat: result.write(swapEndian(value.floatVal))
            of ftDouble: result.write(swapEndian(value.doubleVal))
            of ftDecimalValue: 
                result.write(value.decimalVal.decimalLoc)
                result.write(value.decimalVal.value)
            # of ftShortString: 
            #     result.write(uint8(len(value.shortStringVal)))
            #     result.write(value.shortStringVal)
            of ftLongString:
                result.write(swapEndian(uint32(len(value.longStringVal))))
                result.write(value.longStringVal)
            # TODO: FieldArrays are not implemented
            # of ftFieldArray: result = $this.arrayVal
            of ftTimestamp: result.write(swapEndian(value.timestampVal))
            else:
                discard
    
    result.setPosition(0)
        

# ----------------------------------------------------------------------------------------------------------------------
# Readers/Extractors
# ----------------------------------------------------------------------------------------------------------------------

proc extractFieldTable*(stream: Stream): FieldTable =
    ## Extracts a field-table out of `stream`
    new(result)

    while not stream.atEnd():
        let key = stream.readStr(stream.readInt8())
        let valType = FieldTableValueType(stream.readChar())

        result[key] = stream.extractFieldTableValue(valType)


proc extractFieldTableValue(stream: Stream, valType: FieldTableValueType): FieldTableValue =
    ## Extracts a field-table value of `valType` from `stream` into a Nim type or data-structure
    result = FieldTableValue(valType: valType)

    case result.valType:
        of ftBool:
            result.boolVal = bool(stream.readChar())
        of ftShortShortInt:
            result.int8Val = stream.readInt8()
        of ftShortShortUint:
            result.uint8Val = stream.readUint8()
        of ftShortInt:
            stream.readNumericEndian(result.int16Val)
        of ftShortUint:
            stream.readNumericEndian(result.uInt16Val)
        of ftLongInt:
            stream.readNumericEndian(result.int32Val)
        of ftLongUint:
            stream.readNumericEndian(result.uInt32Val)
        of ftLongLongInt:
            stream.readNumericEndian(result.int64Val)
        # of ftLongLongUint:
        #     stream.readNumericEndian(result.uInt64Val)
        of ftFloat:
            stream.readNumericEndian(result.floatVal)
        of ftDouble:
            stream.readNumericEndian(result.doubleVal)
        of ftDecimalValue:
            result.decimalVal = FieldTableDecimal(decimalLoc: stream.readUint8(), value: stream.readUint32Endian())
        # of ftShortString:
        #     result.shortStringVal = stream.readStr(int(stream.readUint8()))
        of ftLongString:
            result.longStringVal = stream.readStr(int(stream.readUint32Endian()))
        # FIXME: Not Implemented
        of ftFieldArray:
            raise newException(AMQPNotImplementedError, "Field arrays have not been implemented!")
            # result = FieldTableValue(valType: valType, arrayVal: @[])
        of ftFieldTable:
            result.tableVal = extractFieldTable(newStringStream(stream.readStr(int(stream.readUint32Endian()))))
        of ftTimestamp:
            stream.readNumericEndian(result.timestampVal)
        of ftNoField:
            result.noField = true
        of ftBadField:
            result.badField = true
