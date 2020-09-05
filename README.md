# nimIBApi
This is a Nim (www.nim-lang.org) client for the Interactive Brokers TraderWorkstation/Gateway API. It is a native implementation of the TCP-socket messaging protocol and not a wrapper of the official C++ API, thus avoiding its implementation flaws (like messages potentially getting stuck in an internal buffer).

The client uses Nim's single-threaded async I/O framework to wrap the asyncronous, streaming socket communication and expose a RESTlike API.

## Examples


