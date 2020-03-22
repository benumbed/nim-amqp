## 
## Describes an AMQP field-table
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import tables


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

type FieldTableDecimal* = object
    decimalLoc: uint8
    value: uint32

type FieldTableValue* = ref object
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
    of ftFloat: floatVal*: float
    of ftDouble: doubleVal*: float64
    of ftDecimalValue: decimalVal*: FieldTableDecimal
    of ftShortString: shortStringVal*: string
    of ftLongString: longStringVal*: string
    of ftFieldArray: arrayVal*: seq[FieldTableValue]
    of ftFieldTable: tableVal*: string
    of ftTimestamp: timestampVal*: uint64
    of ftNoField: noField*: byte
    of ftBadField: badField*: byte

type FieldTable* = ref OrderedTable[string, FieldTableValue]    