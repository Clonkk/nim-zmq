# Nim wrapper of 0mq
# Generated by c2nim with modifications and enhancement
# from Andreas Rumpf, Erwan Ameil
# Generated from zmq version 4.2.0
# Original licence follows:

#
#    Copyright (c) 2007-2013 Contributors as noted in zeromq's AUTHORS file
#
#    This file is part of 0MQ.
#
#    0MQ is free software; you can redistribute it and/or modify it under
#    the terms of the GNU Lesser General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    0MQ is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

## Nim ZeroMQ wrapper. This package contains the low level C wrappers as well as some higher level constructs.
##
## The low-level C bindings can be found in `zmq/bindings <./zmq/bindings.html>`_
##
## The high-level Connections API can be found in `zmq/connections <./zmq/connections.html>`_
##
## The high-level Polling API can be found in `zmq/poller <./zmq/poller.html>`_
##
## The Async API can be found in `zmq/asynczmq <./zmq/asynczmq.html>`_
##
runnableExamples:
  import zmq
  import std/[asyncdispatch, asyncfutures]

  proc client () {.async.} =
    var requester = zmq.connect("tcp://localhost:5555", REQ)
    echo("Connecting...")
    for i in 0..10:
      echo("Sending hello... (" & $i & ")")
      send(requester, "Hello")
      var reply = await receiveAsync(requester)
      echo("Received: ", reply)

    send(requester, "STOPSERVER")
    close(requester)

  proc server() : Future[int] {.async.} =
    var responder = zmq.listen("tcp://*:5555", REP)
    while true:
      var request = await receiveAsync(responder)
      if request == "STOPSERVER": break
      echo("Received: ", request)
      send(responder, "World")
      inc(result)
    close(responder)

  let r = server()
  asyncCheck client()
  let res = waitFor r
  echo "Server processed ", $(res), " requests"


## Based on std/asyncdispatch, ``receiveAsync``, ``sendAsync`` allows for asynchrone behaviour
## When using asynchrone procs, be careful of the internal state of the ZMQ Socket.
## Some Socket (such as REP/REQ) cannot send two message in a row without a receive (or vice-versa)
runnableExamples:
  import std/asyncdispatch
  import zmq

  const N_TASK = 5

  proc pusher(nTask: int): Future[void] {.async.} =
    var pusher = listen("tcp://localhost:15555", PUSH)
    defer: pusher.close()

    for i in 1..nTask:
      let task = "task-" & $i
      # unlilke `pusher.send(task)`
      # this allow other async tasks to run
      await pusher.sendAsync(task)

  proc puller(id: int): Future[void] {.async.} =
    const connStr = "tcp://localhost:15555"
    var puller = connect(connStr, PULL)
    defer: puller.close()

    for i in 1 .. N_TASK:
      let task = await puller.receiveAsync()
      echo "Pull socket n°", $id, " received ", task
      await sleepAsync(100)

  when isMainModule:
    asyncCheck pusher(N_TASK)
    for i in 1..1:
      asyncCheck puller(i)

    while hasPendingOperations():
      poll()

## Find more examples in the ``examples`` and ``tests`` folder

import zmq/bindings
export bindings

import zmq/connections
export connections

import zmq/poller
export poller

import zmq/asynczmq
export asynczmq
