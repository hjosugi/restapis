# Package
version = "0.1.0"
author = "hjosugi"
description = "users REST API (Mummy) + Nim client (std/httpclient)"
license = "MIT"
srcDir = "src"
bin = @["server", "client"]
binDir = "bin"

# Dependencies
requires "nim >= 2.2.0"
requires "mummy >= 0.4.8"
