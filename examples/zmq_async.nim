import asyncdispatch
import zmq

proc receiveAsync*(conn: ZConnection): Future[string] =
  ## Similar to `receive()`, but `receiveAsync()` allows other async tasks to run.
  let fut = newFuture[string]("receiveAsync")
  result = fut

  proc cb(fd: AsyncFD): bool {.closure,gcsafe.} =
    result = true

    # ignore if already finished
    if fut.finished: return 

    try:
      let status = getsockopt[cint](conn, ZSockOptions.EVENTS)
      if (status and ZMQ_POLLIN) == 0:
        # waiting for messages
        addRead(fd, cb)
      else:
        # ready to read
        unregister(fd)
        fut.complete conn.receive(DONTWAIT)
    except:
      unregister(fd)
      fut.fail getCurrentException()

  let fd = getsockopt[cint](conn, ZSockOptions.FD).AsyncFD
  register(fd)
  discard cb(fd)

proc sendAsync*(conn: ZConnection, msg: string, flags: ZSendRecvOptions = DONTWAIT): Future[void] =
  ## `send()` is blocking for some connection types (e.g. PUSH, DEALER). 
  ## `sendAsync()` allows other async tasks to run in those cases.
  let fut = newFuture[void]("sendAsync")
  result = fut

  let status = getsockopt[cint](conn, ZSockOptions.EVENTS)
  if (status and ZMQ_POLLOUT) == 0:
    # wait until queue available
    proc cb(fd: AsyncFD): bool {.closure,gcsafe.} =
      result = true

      # ignore if already finished
      if fut.finished: return 

      try:
        let status = getsockopt[cint](conn, ZSockOptions.EVENTS)
        if (status and ZMQ_POLLOUT) == 0:
          # waiting for messages
          addWrite(fd, cb)
        else:
          conn.send(msg, flags)
          unregister(fd)
          fut.complete()
      except:
        unregister(fd)
        fut.fail getCurrentException()

    let fd = getsockopt[cint](conn, ZSockOptions.FD).AsyncFD
    register(fd)
    discard cb(fd)
  else:
    # can send without blocking
    conn.send(msg, flags)
    fut.complete()

