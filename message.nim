import streams, endians

type
    Message = string

proc newMessage*(msg: string): Message =
    ## Message to be send across the socket, adds the header to the message string.
    
    var size = uint32(msg.len)
    var bigEndianSize: uint32
    swapEndian32(bigEndianSize.addr, size.addr)
    var byteStream = newStringStream("")
    byteStream.writeData(bigEndiansize.addr, 4)
    byteStream.write(msg)
    byteStream.setPosition(0)
    return Message(byteStream.readAll())

proc readHeader*(msg: Message): int =
    assert(msg.len == 4)
    var bytestream = newStringStream(msg)
    var bigEndianSize,size: uint32
    discard bytestream.readData(bigEndianSize.addr, 4)
    swapEndian32(size.addr, bigEndianSize.addr)
    return int(size)
    