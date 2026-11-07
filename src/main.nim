import std/asyncdispatch
import ./server/web_server

proc main() =
  let port = 8080
  waitFor startWebServer(port = port)

when isMainModule:
  main()
