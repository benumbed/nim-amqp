# Package

version         = "0.5.9"
author          = "Nick Whalen"
description     = "Implementation of AMQP 0-9-1 in Nim"
license         = "BSD-3-Clause"
srcDir          = "src"


# Tasks

task run_example, "Run example/demo code":
    exec "nim c -r src/nim_amqp_example.nim"

    

# Dependencies

requires "nim >= 1.0.6"
requires "chronicles ~= 0.10.1"

taskRequires "run_example", "argparse ~= 4.0.1"
