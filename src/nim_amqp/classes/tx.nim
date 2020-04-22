## 
## Implements the `tx` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import ../types

var txMethodMap* = MethodMap()

const CLASS_ID: uint16 = 90