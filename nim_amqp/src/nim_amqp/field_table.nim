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

import ./utils
import ./errors

# Maps field-table value types from the AMQP standard
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
    ftShortInt = 'U',
    ftNoField = 'V',
    ftShortShortInt = 'b',
    ftDouble = 'd',
    ftFloat = 'f',
    ftLongUint = 'i',
    ftLongLongUint = 'l',
    ftShortString = 's',
    ftBool = 't',
    ftShortUint = 'u',

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
        of ftLongLongUint: uint64Val*: uint64
        of ftFloat: floatVal*: float32
        of ftDouble: doubleVal*: float64
        of ftDecimalValue: decimalVal*: FieldTableDecimal
        of ftShortString: shortStringVal*: string
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
        of ftLongLongUint: result = $this.uint64Val
        of ftFloat: result = $this.floatVal
        of ftDouble: result = $this.doubleVal
        of ftDecimalValue: result = "0.0"
        of ftShortString: result = $this.shortStringVal
        of ftLongString: result = $this.longStringVal
        of ftFieldArray: result = $this.arrayVal
        of ftFieldTable:
            let table = this.tableVal.toStrSeq().join("\p\t")
            result = fmt("\p\t{table}")
        of ftTimestamp: result = $this.timestampVal
        of ftNoField: result = $this.noField
        of ftBadField: result = $this.badField

proc toWire(this: FieldTable): Stream = 
    ## Converts a FieldTable structure to it's wire format and returns the resulting string
    result.setPosition(0)
    let lenSz = len(this)
    echo fmt"Table size from len: {lenSz}"

    # keySize|key|valType(char)|<val size>|value
    # TODO: flip these to Big Endian
    for key, value in this:
        result.write(key.len())
        result.write(key)
        result.write(value.valType)
        if value.valType == ftFieldTable:
            result.write(toWire(value.tableVal).readAll())
            continue

        
        # Some types require us to write a size first
        if value.valType in [ftDecimalValue, ftShortString, ftLongString]:
            continue

        # case value.valType:
        #     of ftBool: result.write(byte(value.boolVal))
        #     of ftShortShortInt: result.write(value.int8Val)
        #     of ftShortShortUint: result.write(value.uint8Val)
        #     of ftShortInt: result.write(intEndian(value.int16Val, cpuEndian, bigEndian))
        #     of ftShortUint: result.write(uintEndian(value.uint16Val, cpuEndian, bigEndian))
        #     of ftLongInt: result.write(intEndian(value.int32Val, cpuEndian, bigEndian))
        #     of ftLongUint: result.write(uintEndian(value.uint32Val, cpuEndian, bigEndian))
        #     of ftLongLongInt: result.write(intEndian(value.int64Val, cpuEndian, bigEndian))
        #     of ftLongLongUint: result.write(uintEndian(value.uint64Val, cpuEndian, bigEndian))
        #     of ftFloat: result = $this.floatVal
        #     of ftDouble: result = $this.doubleVal
        #     of ftDecimalValue: result = "0.0"
        #     of ftShortString: result = $this.shortStringVal
        #     of ftLongString: result = $this.longStringVal
        #     of ftFieldArray: result = $this.arrayVal
        #     of ftFieldTable:
        #         let table = this.tableVal.toStrSeq().join("\p\t")
        #         result = fmt("\p\t{table}")
        #     of ftTimestamp: result = $this.timestampVal
        #     of ftNoField: result = $this.noField
        #     of ftBadField: result = $this.badField
        #     result.write(len(value.))


        

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


# TODO: Use newfound knowledge around generics and templates to maybe clean up this mess?
# Maybe FieldTableValues can have their own loaders/readers based on type?
proc extractFieldTableValue(stream: Stream, valType: FieldTableValueType): FieldTableValue =
    ## Extracts a field-table value of `valType` from `stream` into a Nim type or data-structure
    new(result)
    case valType:
        of ftBool:
            result = FieldTableValue(valType: valType, boolVal: bool(stream.readChar()))
        of ftShortShortInt:
            result = FieldTableValue(valType: valType, int8Val: stream.readInt8())
        of ftShortShortUint:
            result = FieldTableValue(valType: valType, uInt8Val: stream.readUint8())
        of ftShortInt:
            result = FieldTableValue(valType: valType, int16Val: stream.readAndReturnXintEndian(result.int16Val))
        of ftShortUint:
            result = FieldTableValue(valType: valType, uInt16Val: stream.readAndReturnXintEndian(result.uInt16Val))
        of ftLongInt:
            result = FieldTableValue(valType: valType, int32Val: stream.readAndReturnXintEndian(result.int32Val))
        of ftLongUint:
            result = FieldTableValue(valType: valType, uInt32Val: stream.readAndReturnXintEndian(result.uInt32Val))
        of ftLongLongInt:
            result = FieldTableValue(valType: valType, int64Val: stream.readAndReturnXintEndian(result.int64Val))
        of ftLongLongUint:
            result = FieldTableValue(valType: valType, uInt64Val: stream.readAndReturnXintEndian(result.uInt64Val))
        of ftFloat:
            result = FieldTableValue(valType: valType, floatVal: stream.readFloatEndian())
        of ftDouble: 
            result = FieldTableValue(valType: valType, doubleVal: stream.readFloat64Endian())
        of ftDecimalValue:
            result = FieldTableValue(valType: valType, decimalVal: FieldTableDecimal(decimalLoc: stream.readUint8(), 
                                    value: stream.readUint32Endian()))
        of ftShortString:
            result = FieldTableValue(valType: valType, shortStringVal: stream.readStr(int(stream.readUint8())))
        of ftLongString:
            result = FieldTableValue(valType: valType, longStringVal: stream.readStr(int(stream.readUint32Endian())))
        # FIXME: Not Implemented
        of ftFieldArray:
            raise newException(AMQPNotImplementedError, "Field arrays have not be implemented!")
            # result = FieldTableValue(valType: valType, arrayVal: @[])
        of ftFieldTable:
            result = FieldTableValue(valType: valType, tableVal: extractFieldTable(newStringStream(stream.readStr(
                                    int(stream.readUint32Endian())))))
        of ftTimestamp:
            result = FieldTableValue(valType: valType, timestampVal: stream.readAndReturnXintEndian(result.timestampVal))
        of ftNoField:
            result = FieldTableValue(valType: valType, noField: true)
        of ftBadField:
            result = FieldTableValue(valType: valType, badField: true)
