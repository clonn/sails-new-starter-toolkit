# socket.io-1.2.1
# (from http://socket.io/download/)
not (e) ->
  if "object" is typeof exports and "undefined" isnt typeof module
    module.exports = e()
  else if "function" is typeof define and define.amd
    define [], e
  else
    f = undefined
    (if "undefined" isnt typeof window then f = window else (if "undefined" isnt typeof global then f = global else "undefined" isnt typeof self and (f = self)))
    f.io = e()
  return
(->
  define = undefined
  module = undefined
  exports = undefined
  e = (t, n, r) ->
    s = (o, u) ->
      unless n[o]
        unless t[o]
          a = typeof require is "function" and require
          return a(o, not 0)  if not u and a
          return i(o, not 0)  if i
          throw new Error("Cannot find module '" + o + "'")
        f = n[o] = exports: {}
        t[o][0].call f.exports, ((e) ->
          n = t[o][1][e]
          s (if n then n else e)
        ), f, f.exports, e, t, n, r
      n[o].exports
    i = typeof require is "function" and require
    o = 0

    while o < r.length
      s r[o]
      o++
    s
  (
    1: [
      (_dereq_, module, exports) ->
        module.exports = _dereq_("./lib/")
      {
        "./lib/": 2
      }
    ]
    2: [
      (_dereq_, module, exports) ->
        lookup = (uri, opts) ->
          if typeof uri is "object"
            opts = uri
            uri = `undefined`
          opts = opts or {}
          parsed = url(uri)
          source = parsed.source
          id = parsed.id
          io = undefined
          if opts.forceNew or opts["force new connection"] or false is opts.multiplex
            debug "ignoring socket cache for %s", source
            io = Manager(source, opts)
          else
            unless cache[id]
              debug "new io instance for %s", source
              cache[id] = Manager(source, opts)
            io = cache[id]
          io.socket parsed.path
        url = _dereq_("./url")
        parser = _dereq_("socket.io-parser")
        Manager = _dereq_("./manager")
        debug = _dereq_("debug")("socket.io-client")
        module.exports = exports = lookup
        cache = exports.managers = {}
        exports.protocol = parser.protocol
        exports.connect = lookup
        exports.Manager = _dereq_("./manager")
        exports.Socket = _dereq_("./socket")
      {
        "./manager": 3
        "./socket": 5
        "./url": 6
        debug: 9
        "socket.io-parser": 43
      }
    ]
    3: [
      (_dereq_, module, exports) ->
        Manager = (uri, opts) ->
          return new Manager(uri, opts)  unless this instanceof Manager
          if uri and "object" is typeof uri
            opts = uri
            uri = `undefined`
          opts = opts or {}
          opts.path = opts.path or "/socket.io"
          @nsps = {}
          @subs = []
          @opts = opts
          @reconnection opts.reconnection isnt false
          @reconnectionAttempts opts.reconnectionAttempts or Infinity
          @reconnectionDelay opts.reconnectionDelay or 1e3
          @reconnectionDelayMax opts.reconnectionDelayMax or 5e3
          @timeout (if null is opts.timeout then 2e4 else opts.timeout)
          @readyState = "closed"
          @uri = uri
          @connected = []
          @attempts = 0
          @encoding = false
          @packetBuffer = []
          @encoder = new parser.Encoder
          @decoder = new parser.Decoder
          @autoConnect = opts.autoConnect isnt false
          @open()  if @autoConnect
          return
        url = _dereq_("./url")
        eio = _dereq_("engine.io-client")
        Socket = _dereq_("./socket")
        Emitter = _dereq_("component-emitter")
        parser = _dereq_("socket.io-parser")
        on_ = _dereq_("./on")
        bind = _dereq_("component-bind")
        object = _dereq_("object-component")
        debug = _dereq_("debug")("socket.io-client:manager")
        indexOf = _dereq_("indexof")
        module.exports = Manager
        Manager::emitAll = ->
          @emit.apply this, arguments
          for nsp of @nsps
            @nsps[nsp].emit.apply @nsps[nsp], arguments
          return

        Emitter Manager::
        Manager::reconnection = (v) ->
          return @_reconnection  unless arguments.length
          @_reconnection = !!v
          this

        Manager::reconnectionAttempts = (v) ->
          return @_reconnectionAttempts  unless arguments.length
          @_reconnectionAttempts = v
          this

        Manager::reconnectionDelay = (v) ->
          return @_reconnectionDelay  unless arguments.length
          @_reconnectionDelay = v
          this

        Manager::reconnectionDelayMax = (v) ->
          return @_reconnectionDelayMax  unless arguments.length
          @_reconnectionDelayMax = v
          this

        Manager::timeout = (v) ->
          return @_timeout  unless arguments.length
          @_timeout = v
          this

        Manager::maybeReconnectOnOpen = ->
          if not @openReconnect and not @reconnecting and @_reconnection and @attempts is 0
            @openReconnect = true
            @reconnect()
          return

        Manager::open = Manager::connect = (fn) ->
          debug "readyState %s", @readyState
          return this  if ~@readyState.indexOf("open")
          debug "opening %s", @uri
          @engine = eio(@uri, @opts)
          socket = @engine
          self = this
          @readyState = "opening"
          @skipReconnect = false
          openSub = on_(socket, "open", ->
            self.onopen()
            fn and fn()
            return
          )
          errorSub = on_(socket, "error", (data) ->
            debug "connect_error"
            self.cleanup()
            self.readyState = "closed"
            self.emitAll "connect_error", data
            if fn
              err = new Error("Connection error")
              err.data = data
              fn err
            self.maybeReconnectOnOpen()
            return
          )
          if false isnt @_timeout
            timeout = @_timeout
            debug "connect attempt will timeout after %d", timeout
            timer = setTimeout(->
              debug "connect attempt timed out after %d", timeout
              openSub.destroy()
              socket.close()
              socket.emit "error", "timeout"
              self.emitAll "connect_timeout", timeout
              return
            , timeout)
            @subs.push destroy: ->
              clearTimeout timer
              return

          @subs.push openSub
          @subs.push errorSub
          this

        Manager::onopen = ->
          debug "open"
          @cleanup()
          @readyState = "open"
          @emit "open"
          socket = @engine
          @subs.push on_(socket, "data", bind(this, "ondata"))
          @subs.push on_(@decoder, "decoded", bind(this, "ondecoded"))
          @subs.push on_(socket, "error", bind(this, "onerror"))
          @subs.push on_(socket, "close", bind(this, "onclose"))
          return

        Manager::ondata = (data) ->
          @decoder.add data
          return

        Manager::ondecoded = (packet) ->
          @emit "packet", packet
          return

        Manager::onerror = (err) ->
          debug "error", err
          @emitAll "error", err
          return

        Manager::socket = (nsp) ->
          socket = @nsps[nsp]
          unless socket
            socket = new Socket(this, nsp)
            @nsps[nsp] = socket
            self = this
            socket.on "connect", ->
              self.connected.push socket  unless ~indexOf(self.connected, socket)
              return

          socket

        Manager::destroy = (socket) ->
          index = indexOf(@connected, socket)
          @connected.splice index, 1  if ~index
          return  if @connected.length
          @close()
          return

        Manager::packet = (packet) ->
          debug "writing packet %j", packet
          self = this
          unless self.encoding
            self.encoding = true
            @encoder.encode packet, (encodedPackets) ->
              i = 0

              while i < encodedPackets.length
                self.engine.write encodedPackets[i]
                i++
              self.encoding = false
              self.processPacketQueue()
              return

          else
            self.packetBuffer.push packet
          return

        Manager::processPacketQueue = ->
          if @packetBuffer.length > 0 and not @encoding
            pack = @packetBuffer.shift()
            @packet pack
          return

        Manager::cleanup = ->
          sub = undefined
          sub.destroy()  while sub = @subs.shift()
          @packetBuffer = []
          @encoding = false
          @decoder.destroy()
          return

        Manager::close = Manager::disconnect = ->
          @skipReconnect = true
          @readyState = "closed"
          @engine and @engine.close()
          return

        Manager::onclose = (reason) ->
          debug "close"
          @cleanup()
          @readyState = "closed"
          @emit "close", reason
          @reconnect()  if @_reconnection and not @skipReconnect
          return

        Manager::reconnect = ->
          return this  if @reconnecting or @skipReconnect
          self = this
          @attempts++
          if @attempts > @_reconnectionAttempts
            debug "reconnect failed"
            @emitAll "reconnect_failed"
            @reconnecting = false
          else
            delay = @attempts * @reconnectionDelay()
            delay = Math.min(delay, @reconnectionDelayMax())
            debug "will wait %dms before reconnect attempt", delay
            @reconnecting = true
            timer = setTimeout(->
              return  if self.skipReconnect
              debug "attempting reconnect"
              self.emitAll "reconnect_attempt", self.attempts
              self.emitAll "reconnecting", self.attempts
              return  if self.skipReconnect
              self.open (err) ->
                if err
                  debug "reconnect attempt error"
                  self.reconnecting = false
                  self.reconnect()
                  self.emitAll "reconnect_error", err.data
                else
                  debug "reconnect success"
                  self.onreconnect()
                return

              return
            , delay)
            @subs.push destroy: ->
              clearTimeout timer
              return

          return

        Manager::onreconnect = ->
          attempt = @attempts
          @attempts = 0
          @reconnecting = false
          @emitAll "reconnect", attempt
          return
      {
        "./on": 4
        "./socket": 5
        "./url": 6
        "component-bind": 7
        "component-emitter": 8
        debug: 9
        "engine.io-client": 10
        indexof: 39
        "object-component": 40
        "socket.io-parser": 43
      }
    ]
    4: [
      (_dereq_, module, exports) ->
        on = (obj, ev, fn) ->
          obj.on ev, fn
          destroy: ->
            obj.removeListener ev, fn
            return
        module.exports = on_
      {
        {}
      }
    ]
    5: [
      (_dereq_, module, exports) ->
        Socket = (io, nsp) ->
          @io = io
          @nsp = nsp
          @json = this
          @ids = 0
          @acks = {}
          @open()  if @io.autoConnect
          @receiveBuffer = []
          @sendBuffer = []
          @connected = false
          @disconnected = true
          return
        parser = _dereq_("socket.io-parser")
        Emitter = _dereq_("component-emitter")
        toArray = _dereq_("to-array")
        on_ = _dereq_("./on")
        bind = _dereq_("component-bind")
        debug = _dereq_("debug")("socket.io-client:socket")
        hasBin = _dereq_("has-binary")
        module.exports = exports = Socket
        events =
          connect: 1
          connect_error: 1
          connect_timeout: 1
          disconnect: 1
          error: 1
          reconnect: 1
          reconnect_attempt: 1
          reconnect_failed: 1
          reconnect_error: 1
          reconnecting: 1

        emit = Emitter::emit
        Emitter Socket::
        Socket::subEvents = ->
          return  if @subs
          io = @io
          @subs = [
            on_(io, "open", bind(this, "onopen"))
            on_(io, "packet", bind(this, "onpacket"))
            on_(io, "close", bind(this, "onclose"))
          ]
          return

        Socket::open = Socket::connect = ->
          return this  if @connected
          @subEvents()
          @io.open()
          @onopen()  if "open" is @io.readyState
          this

        Socket::send = ->
          args = toArray(arguments)
          args.unshift "message"
          @emit.apply this, args
          this

        Socket::emit = (ev) ->
          if events.hasOwnProperty(ev)
            emit.apply this, arguments
            return this
          args = toArray(arguments)
          parserType = parser.EVENT
          parserType = parser.BINARY_EVENT  if hasBin(args)
          packet =
            type: parserType
            data: args

          if "function" is typeof args[args.length - 1]
            debug "emitting packet with ack id %d", @ids
            @acks[@ids] = args.pop()
            packet.id = @ids++
          if @connected
            @packet packet
          else
            @sendBuffer.push packet
          this

        Socket::packet = (packet) ->
          packet.nsp = @nsp
          @io.packet packet
          return

        Socket::onopen = ->
          debug "transport is open - connecting"
          @packet type: parser.CONNECT  unless "/" is @nsp
          return

        Socket::onclose = (reason) ->
          debug "close (%s)", reason
          @connected = false
          @disconnected = true
          @emit "disconnect", reason
          return

        Socket::onpacket = (packet) ->
          return  unless packet.nsp is @nsp
          switch packet.type
            when parser.CONNECT
              @onconnect()
            when parser.EVENT
              @onevent packet
            when parser.BINARY_EVENT
              @onevent packet
            when parser.ACK
              @onack packet
            when parser.BINARY_ACK
              @onack packet
            when parser.DISCONNECT
              @ondisconnect()
            when parser.ERROR
              @emit "error", packet.data

        Socket::onevent = (packet) ->
          args = packet.data or []
          debug "emitting event %j", args
          unless null is packet.id
            debug "attaching ack callback to event"
            args.push @ack(packet.id)
          if @connected
            emit.apply this, args
          else
            @receiveBuffer.push args
          return

        Socket::ack = (id) ->
          self = this
          sent = false
          ->
            return  if sent
            sent = true
            args = toArray(arguments)
            debug "sending ack %j", args
            type = (if hasBin(args) then parser.BINARY_ACK else parser.ACK)
            self.packet
              type: type
              id: id
              data: args

            return

        Socket::onack = (packet) ->
          debug "calling ack %s with %j", packet.id, packet.data
          fn = @acks[packet.id]
          fn.apply this, packet.data
          delete @acks[packet.id]

          return

        Socket::onconnect = ->
          @connected = true
          @disconnected = false
          @emit "connect"
          @emitBuffered()
          return

        Socket::emitBuffered = ->
          i = undefined
          i = 0
          while i < @receiveBuffer.length
            emit.apply this, @receiveBuffer[i]
            i++
          @receiveBuffer = []
          i = 0
          while i < @sendBuffer.length
            @packet @sendBuffer[i]
            i++
          @sendBuffer = []
          return

        Socket::ondisconnect = ->
          debug "server disconnect (%s)", @nsp
          @destroy()
          @onclose "io server disconnect"
          return

        Socket::destroy = ->
          if @subs
            i = 0

            while i < @subs.length
              @subs[i].destroy()
              i++
            @subs = null
          @io.destroy this
          return

        Socket::close = Socket::disconnect = ->
          if @connected
            debug "performing disconnect (%s)", @nsp
            @packet type: parser.DISCONNECT
          @destroy()
          @onclose "io client disconnect"  if @connected
          this
      {
        "./on": 4
        "component-bind": 7
        "component-emitter": 8
        debug: 9
        "has-binary": 35
        "socket.io-parser": 43
        "to-array": 47
      }
    ]
    6: [
      (_dereq_, module, exports) ->
        ((global) ->
          url = (uri, loc) ->
            obj = uri
            loc = loc or global.location
            uri = loc.protocol + "//" + loc.hostname  if null is uri
            if "string" is typeof uri
              if "/" is uri.charAt(0)
                if "/" is uri.charAt(1)
                  uri = loc.protocol + uri
                else
                  uri = loc.hostname + uri
              unless /^(https?|wss?):\/\//.test(uri)
                debug "protocol-less url %s", uri
                unless "undefined" is typeof loc
                  uri = loc.protocol + "//" + uri
                else
                  uri = "https://" + uri
              debug "parse %s", uri
              obj = parseuri(uri)
            unless obj.port
              if /^(http|ws)$/.test(obj.protocol)
                obj.port = "80"
              else obj.port = "443"  if /^(http|ws)s$/.test(obj.protocol)
            obj.path = obj.path or "/"
            obj.id = obj.protocol + "://" + obj.host + ":" + obj.port
            obj.href = obj.protocol + "://" + obj.host + ((if loc and loc.port is obj.port then "" else ":" + obj.port))
            obj
          parseuri = _dereq_("parseuri")
          debug = _dereq_("debug")("socket.io-client:url")
          module.exports = url
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        debug: 9
        parseuri: 41
      }
    ]
    7: [
      (_dereq_, module, exports) ->
        slice = [].slice
        module.exports = (obj, fn) ->
          fn = obj[fn]  if "string" is typeof fn
          throw new Error("bind() requires a function")  unless "function" is typeof fn
          args = slice.call(arguments, 2)
          ->
            fn.apply obj, args.concat(slice.call(arguments))
      {
        {}
      }
    ]
    8: [
      (_dereq_, module, exports) ->
        Emitter = (obj) ->
          mixin obj  if obj
        mixin = (obj) ->
          for key of Emitter::
            obj[key] = Emitter::[key]
          obj
        module.exports = Emitter
        Emitter::on = Emitter::addEventListener = (event, fn) ->
          @_callbacks = @_callbacks or {}
          (@_callbacks[event] = @_callbacks[event] or []).push fn
          this

        Emitter::once = (event, fn) ->
          on = ->
            self.off event, on_
            fn.apply this, arguments
            return
          self = this
          @_callbacks = @_callbacks or {}
          on_.fn = fn
          @on event, on_
          this

        Emitter::off = Emitter::removeListener = Emitter::removeAllListeners = Emitter::removeEventListener = (event, fn) ->
          @_callbacks = @_callbacks or {}
          if 0 is arguments.length
            @_callbacks = {}
            return this
          callbacks = @_callbacks[event]
          return this  unless callbacks
          if 1 is arguments.length
            delete @_callbacks[event]

            return this
          cb = undefined
          i = 0

          while i < callbacks.length
            cb = callbacks[i]
            if cb is fn or cb.fn is fn
              callbacks.splice i, 1
              break
            i++
          this

        Emitter::emit = (event) ->
          @_callbacks = @_callbacks or {}
          args = [].slice.call(arguments, 1)
          callbacks = @_callbacks[event]
          if callbacks
            callbacks = callbacks.slice(0)
            i = 0
            len = callbacks.length

            while i < len
              callbacks[i].apply this, args
              ++i
          this

        Emitter::listeners = (event) ->
          @_callbacks = @_callbacks or {}
          @_callbacks[event] or []

        Emitter::hasListeners = (event) ->
          !!@listeners(event).length
      {
        {}
      }
    ]
    9: [
      (_dereq_, module, exports) ->
        debug = (name) ->
          return ->  unless debug.enabled(name)
          (fmt) ->
            fmt = coerce(fmt)
            curr = new Date
            ms = curr - (debug[name] or curr)
            debug[name] = curr
            fmt = name + " " + fmt + " +" + debug.humanize(ms)
            window.console and console.log and Function::apply.call(console.log, console, arguments)
            return
        coerce = (val) ->
          return val.stack or val.message  if val instanceof Error
          val
        module.exports = debug
        debug.names = []
        debug.skips = []
        debug.enable = (name) ->
          try
            localStorage.debug = name
          split = (name or "").split(/[\s,]+/)
          len = split.length
          i = 0

          while i < len
            name = split[i].replace("*", ".*?")
            if name[0] is "-"
              debug.skips.push new RegExp("^" + name.substr(1) + "$")
            else
              debug.names.push new RegExp("^" + name + "$")
            i++
          return

        debug.disable = ->
          debug.enable ""
          return

        debug.humanize = (ms) ->
          sec = 1e3
          min = 60 * 1e3
          hour = 60 * min
          return (ms / hour).toFixed(1) + "h"  if ms >= hour
          return (ms / min).toFixed(1) + "m"  if ms >= min
          return (ms / sec | 0) + "s"  if ms >= sec
          ms + "ms"

        debug.enabled = (name) ->
          i = 0
          len = debug.skips.length

          while i < len
            return false  if debug.skips[i].test(name)
            i++
          i = 0
          len = debug.names.length

          while i < len
            return true  if debug.names[i].test(name)
            i++
          false

        try
          debug.enable localStorage.debug  if window.localStorage
      {
        {}
      }
    ]
    10: [
      (_dereq_, module, exports) ->
        module.exports = _dereq_("./lib/")
      {
        "./lib/": 11
      }
    ]
    11: [
      (_dereq_, module, exports) ->
        module.exports = _dereq_("./socket")
        module.exports.parser = _dereq_("engine.io-parser")
      {
        "./socket": 12
        "engine.io-parser": 24
      }
    ]
    12: [
      (_dereq_, module, exports) ->
        ((global) ->
          noop = ->
          Socket = (uri, opts) ->
            return new Socket(uri, opts)  unless this instanceof Socket
            opts = opts or {}
            if uri and "object" is typeof uri
              opts = uri
              uri = null
            if uri
              uri = parseuri(uri)
              opts.host = uri.host
              opts.secure = uri.protocol is "https" or uri.protocol is "wss"
              opts.port = uri.port
              opts.query = uri.query  if uri.query
            @secure = (if null isnt opts.secure then opts.secure else global.location and "https:" is location.protocol)
            if opts.host
              pieces = opts.host.split(":")
              opts.hostname = pieces.shift()
              opts.port = pieces.pop()  if pieces.length
            @agent = opts.agent or false
            @hostname = opts.hostname or ((if global.location then location.hostname else "localhost"))
            @port = opts.port or ((if global.location and location.port then location.port else (if @secure then 443 else 80)))
            @query = opts.query or {}
            @query = parseqs.decode(@query)  if "string" is typeof @query
            @upgrade = false isnt opts.upgrade
            @path = (opts.path or "/engine.io").replace(/\/$/, "") + "/"
            @forceJSONP = !!opts.forceJSONP
            @jsonp = false isnt opts.jsonp
            @forceBase64 = !!opts.forceBase64
            @enablesXDR = !!opts.enablesXDR
            @timestampParam = opts.timestampParam or "t"
            @timestampRequests = opts.timestampRequests
            @transports = opts.transports or [
              "polling"
              "websocket"
            ]
            @readyState = ""
            @writeBuffer = []
            @callbackBuffer = []
            @policyPort = opts.policyPort or 843
            @rememberUpgrade = opts.rememberUpgrade or false
            @open()
            @binaryType = null
            @onlyBinaryUpgrades = opts.onlyBinaryUpgrades
            return
          clone = (obj) ->
            o = {}
            for i of obj
              o[i] = obj[i]  if obj.hasOwnProperty(i)
            o
          transports = _dereq_("./transports")
          Emitter = _dereq_("component-emitter")
          debug = _dereq_("debug")("engine.io-client:socket")
          index = _dereq_("indexof")
          parser = _dereq_("engine.io-parser")
          parseuri = _dereq_("parseuri")
          parsejson = _dereq_("parsejson")
          parseqs = _dereq_("parseqs")
          module.exports = Socket
          Socket.priorWebsocketSuccess = false
          Emitter Socket::
          Socket.protocol = parser.protocol
          Socket.Socket = Socket
          Socket.Transport = _dereq_("./transport")
          Socket.transports = _dereq_("./transports")
          Socket.parser = _dereq_("engine.io-parser")
          Socket::createTransport = (name) ->
            debug "creating transport \"%s\"", name
            query = clone(@query)
            query.EIO = parser.protocol
            query.transport = name
            query.sid = @id  if @id
            transport = new transports[name](
              agent: @agent
              hostname: @hostname
              port: @port
              secure: @secure
              path: @path
              query: query
              forceJSONP: @forceJSONP
              jsonp: @jsonp
              forceBase64: @forceBase64
              enablesXDR: @enablesXDR
              timestampRequests: @timestampRequests
              timestampParam: @timestampParam
              policyPort: @policyPort
              socket: this
            )
            transport

          Socket::open = ->
            transport = undefined
            if @rememberUpgrade and Socket.priorWebsocketSuccess and @transports.indexOf("websocket") isnt -1
              transport = "websocket"
            else if 0 is @transports.length
              self = this
              setTimeout (->
                self.emit "error", "No transports available"
                return
              ), 0
              return
            else
              transport = @transports[0]
            @readyState = "opening"
            transport = undefined
            try
              transport = @createTransport(transport)
            catch e
              @transports.shift()
              @open()
              return
            transport.open()
            @setTransport transport
            return

          Socket::setTransport = (transport) ->
            debug "setting transport %s", transport.name
            self = this
            if @transport
              debug "clearing existing transport %s", @transport.name
              @transport.removeAllListeners()
            @transport = transport
            transport.on("drain", ->
              self.onDrain()
              return
            ).on("packet", (packet) ->
              self.onPacket packet
              return
            ).on("error", (e) ->
              self.onError e
              return
            ).on "close", ->
              self.onClose "transport close"
              return

            return

          Socket::probe = (name) ->
            onTransportOpen = ->
              if self.onlyBinaryUpgrades
                upgradeLosesBinary = not @supportsBinary and self.transport.supportsBinary
                failed = failed or upgradeLosesBinary
              return  if failed
              debug "probe transport \"%s\" opened", name
              transport.send [
                type: "ping"
                data: "probe"
              ]
              transport.once "packet", (msg) ->
                return  if failed
                if "pong" is msg.type and "probe" is msg.data
                  debug "probe transport \"%s\" pong", name
                  self.upgrading = true
                  self.emit "upgrading", transport
                  return  unless transport
                  Socket.priorWebsocketSuccess = "websocket" is transport.name
                  debug "pausing current transport \"%s\"", self.transport.name
                  self.transport.pause ->
                    return  if failed
                    return  if "closed" is self.readyState
                    debug "changing transport and sending upgrade packet"
                    cleanup()
                    self.setTransport transport
                    transport.send [type: "upgrade"]
                    self.emit "upgrade", transport
                    transport = null
                    self.upgrading = false
                    self.flush()
                    return

                else
                  debug "probe transport \"%s\" failed", name
                  err = new Error("probe error")
                  err.transport = transport.name
                  self.emit "upgradeError", err
                return

              return
            freezeTransport = ->
              return  if failed
              failed = true
              cleanup()
              transport.close()
              transport = null
              return
            onerror = (err) ->
              error = new Error("probe error: " + err)
              error.transport = transport.name
              freezeTransport()
              debug "probe transport \"%s\" failed because of error: %s", name, err
              self.emit "upgradeError", error
              return
            onTransportClose = ->
              onerror "transport closed"
              return
            onclose = ->
              onerror "socket closed"
              return
            onupgrade = (to) ->
              if transport and to.name isnt transport.name
                debug "\"%s\" works - aborting \"%s\"", to.name, transport.name
                freezeTransport()
              return
            cleanup = ->
              transport.removeListener "open", onTransportOpen
              transport.removeListener "error", onerror
              transport.removeListener "close", onTransportClose
              self.removeListener "close", onclose
              self.removeListener "upgrading", onupgrade
              return
            debug "probing transport \"%s\"", name
            transport = @createTransport(name,
              probe: 1
            )
            failed = false
            self = this
            Socket.priorWebsocketSuccess = false
            transport.once "open", onTransportOpen
            transport.once "error", onerror
            transport.once "close", onTransportClose
            @once "close", onclose
            @once "upgrading", onupgrade
            transport.open()
            return

          Socket::onOpen = ->
            debug "socket open"
            @readyState = "open"
            Socket.priorWebsocketSuccess = "websocket" is @transport.name
            @emit "open"
            @flush()
            if "open" is @readyState and @upgrade and @transport.pause
              debug "starting upgrade probes"
              i = 0
              l = @upgrades.length

              while i < l
                @probe @upgrades[i]
                i++
            return

          Socket::onPacket = (packet) ->
            if "opening" is @readyState or "open" is @readyState
              debug "socket receive: type \"%s\", data \"%s\"", packet.type, packet.data
              @emit "packet", packet
              @emit "heartbeat"
              switch packet.type
                when "open"
                  @onHandshake parsejson(packet.data)
                when "pong"
                  @setPing()
                when "error"
                  err = new Error("server error")
                  err.code = packet.data
                  @emit "error", err
                when "message"
                  @emit "data", packet.data
                  @emit "message", packet.data
            else
              debug "packet received with socket readyState \"%s\"", @readyState
            return

          Socket::onHandshake = (data) ->
            @emit "handshake", data
            @id = data.sid
            @transport.query.sid = data.sid
            @upgrades = @filterUpgrades(data.upgrades)
            @pingInterval = data.pingInterval
            @pingTimeout = data.pingTimeout
            @onOpen()
            return  if "closed" is @readyState
            @setPing()
            @removeListener "heartbeat", @onHeartbeat
            @on "heartbeat", @onHeartbeat
            return

          Socket::onHeartbeat = (timeout) ->
            clearTimeout @pingTimeoutTimer
            self = this
            self.pingTimeoutTimer = setTimeout(->
              return  if "closed" is self.readyState
              self.onClose "ping timeout"
              return
            , timeout or self.pingInterval + self.pingTimeout)
            return

          Socket::setPing = ->
            self = this
            clearTimeout self.pingIntervalTimer
            self.pingIntervalTimer = setTimeout(->
              debug "writing ping packet - expecting pong within %sms", self.pingTimeout
              self.ping()
              self.onHeartbeat self.pingTimeout
              return
            , self.pingInterval)
            return

          Socket::ping = ->
            @sendPacket "ping"
            return

          Socket::onDrain = ->
            i = 0

            while i < @prevBufferLen
              @callbackBuffer[i]()  if @callbackBuffer[i]
              i++
            @writeBuffer.splice 0, @prevBufferLen
            @callbackBuffer.splice 0, @prevBufferLen
            @prevBufferLen = 0
            if @writeBuffer.length is 0
              @emit "drain"
            else
              @flush()
            return

          Socket::flush = ->
            if "closed" isnt @readyState and @transport.writable and not @upgrading and @writeBuffer.length
              debug "flushing %d packets in socket", @writeBuffer.length
              @transport.send @writeBuffer
              @prevBufferLen = @writeBuffer.length
              @emit "flush"
            return

          Socket::write = Socket::send = (msg, fn) ->
            @sendPacket "message", msg, fn
            this

          Socket::sendPacket = (type, data, fn) ->
            return  if "closing" is @readyState or "closed" is @readyState
            packet =
              type: type
              data: data

            @emit "packetCreate", packet
            @writeBuffer.push packet
            @callbackBuffer.push fn
            @flush()
            return

          Socket::close = ->
            if "opening" is @readyState or "open" is @readyState
              close = ->
                self.onClose "forced close"
                debug "socket closing - telling transport to close"
                self.transport.close()
                return
              cleanupAndClose = ->
                self.removeListener "upgrade", cleanupAndClose
                self.removeListener "upgradeError", cleanupAndClose
                close()
                return
              waitForUpgrade = ->
                self.once "upgrade", cleanupAndClose
                self.once "upgradeError", cleanupAndClose
                return
              @readyState = "closing"
              self = this
              if @writeBuffer.length
                @once "drain", ->
                  if @upgrading
                    waitForUpgrade()
                  else
                    close()
                  return

              else if @upgrading
                waitForUpgrade()
              else
                close()
            this

          Socket::onError = (err) ->
            debug "socket error %j", err
            Socket.priorWebsocketSuccess = false
            @emit "error", err
            @onClose "transport error", err
            return

          Socket::onClose = (reason, desc) ->
            if "opening" is @readyState or "open" is @readyState or "closing" is @readyState
              debug "socket close with reason: \"%s\"", reason
              self = this
              clearTimeout @pingIntervalTimer
              clearTimeout @pingTimeoutTimer
              setTimeout (->
                self.writeBuffer = []
                self.callbackBuffer = []
                self.prevBufferLen = 0
                return
              ), 0
              @transport.removeAllListeners "close"
              @transport.close()
              @transport.removeAllListeners()
              @readyState = "closed"
              @id = null
              @emit "close", reason, desc
            return

          Socket::filterUpgrades = (upgrades) ->
            filteredUpgrades = []
            i = 0
            j = upgrades.length

            while i < j
              filteredUpgrades.push upgrades[i]  if ~index(@transports, upgrades[i])
              i++
            filteredUpgrades

          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./transport": 13
        "./transports": 14
        "component-emitter": 8
        debug: 21
        "engine.io-parser": 24
        indexof: 39
        parsejson: 31
        parseqs: 32
        parseuri: 33
      }
    ]
    13: [
      (_dereq_, module, exports) ->
        Transport = (opts) ->
          @path = opts.path
          @hostname = opts.hostname
          @port = opts.port
          @secure = opts.secure
          @query = opts.query
          @timestampParam = opts.timestampParam
          @timestampRequests = opts.timestampRequests
          @readyState = ""
          @agent = opts.agent or false
          @socket = opts.socket
          @enablesXDR = opts.enablesXDR
          return
        parser = _dereq_("engine.io-parser")
        Emitter = _dereq_("component-emitter")
        module.exports = Transport
        Emitter Transport::
        Transport.timestamps = 0
        Transport::onError = (msg, desc) ->
          err = new Error(msg)
          err.type = "TransportError"
          err.description = desc
          @emit "error", err
          this

        Transport::open = ->
          if "closed" is @readyState or "" is @readyState
            @readyState = "opening"
            @doOpen()
          this

        Transport::close = ->
          if "opening" is @readyState or "open" is @readyState
            @doClose()
            @onClose()
          this

        Transport::send = (packets) ->
          if "open" is @readyState
            @write packets
          else
            throw new Error("Transport not open")
          return

        Transport::onOpen = ->
          @readyState = "open"
          @writable = true
          @emit "open"
          return

        Transport::onData = (data) ->
          packet = parser.decodePacket(data, @socket.binaryType)
          @onPacket packet
          return

        Transport::onPacket = (packet) ->
          @emit "packet", packet
          return

        Transport::onClose = ->
          @readyState = "closed"
          @emit "close"
          return
      {
        "component-emitter": 8
        "engine.io-parser": 24
      }
    ]
    14: [
      (_dereq_, module, exports) ->
        ((global) ->
          polling = (opts) ->
            xhr = undefined
            xd = false
            xs = false
            jsonp = false isnt opts.jsonp
            if global.location
              isSSL = "https:" is location.protocol
              port = location.port
              port = (if isSSL then 443 else 80)  unless port
              xd = opts.hostname isnt location.hostname or port isnt opts.port
              xs = opts.secure isnt isSSL
            opts.xdomain = xd
            opts.xscheme = xs
            xhr = new XMLHttpRequest(opts)
            if "open" of xhr and not opts.forceJSONP
              new XHR(opts)
            else
              throw new Error("JSONP disabled")  unless jsonp
              new JSONP(opts)
          XMLHttpRequest = _dereq_("xmlhttprequest")
          XHR = _dereq_("./polling-xhr")
          JSONP = _dereq_("./polling-jsonp")
          websocket = _dereq_("./websocket")
          exports.polling = polling
          exports.websocket = websocket
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./polling-jsonp": 15
        "./polling-xhr": 16
        "./websocket": 18
        xmlhttprequest: 19
      }
    ]
    15: [
      (_dereq_, module, exports) ->
        ((global) ->
          empty = ->
          JSONPPolling = (opts) ->
            Polling.call this, opts
            @query = @query or {}
            unless callbacks
              global.___eio = []  unless global.___eio
              callbacks = global.___eio
            @index = callbacks.length
            self = this
            callbacks.push (msg) ->
              self.onData msg
              return

            @query.j = @index
            if global.document and global.addEventListener
              global.addEventListener "beforeunload", (->
                self.script.onerror = empty  if self.script
                return
              ), false
            return
          Polling = _dereq_("./polling")
          inherit = _dereq_("component-inherit")
          module.exports = JSONPPolling
          rNewline = /\n/g
          rEscapedNewline = /\\n/g
          callbacks = undefined
          index = 0
          inherit JSONPPolling, Polling
          JSONPPolling::supportsBinary = false
          JSONPPolling::doClose = ->
            if @script
              @script.parentNode.removeChild @script
              @script = null
            if @form
              @form.parentNode.removeChild @form
              @form = null
              @iframe = null
            Polling::doClose.call this
            return

          JSONPPolling::doPoll = ->
            self = this
            script = document.createElement("script")
            if @script
              @script.parentNode.removeChild @script
              @script = null
            script.async = true
            script.src = @uri()
            script.onerror = (e) ->
              self.onError "jsonp poll error", e
              return

            insertAt = document.getElementsByTagName("script")[0]
            insertAt.parentNode.insertBefore script, insertAt
            @script = script
            isUAgecko = "undefined" isnt typeof navigator and /gecko/i.test(navigator.userAgent)
            if isUAgecko
              setTimeout (->
                iframe = document.createElement("iframe")
                document.body.appendChild iframe
                document.body.removeChild iframe
                return
              ), 100
            return

          JSONPPolling::doWrite = (data, fn) ->
            complete = ->
              initIframe()
              fn()
              return
            initIframe = ->
              if self.iframe
                try
                  self.form.removeChild self.iframe
                catch e
                  self.onError "jsonp polling iframe removal error", e
              try
                html = "<iframe src=\"javascript:0\" name=\"" + self.iframeId + "\">"
                iframe = document.createElement(html)
              catch e
                iframe = document.createElement("iframe")
                iframe.name = self.iframeId
                iframe.src = "javascript:0"
              iframe.id = self.iframeId
              self.form.appendChild iframe
              self.iframe = iframe
              return
            self = this
            unless @form
              form = document.createElement("form")
              area = document.createElement("textarea")
              id = @iframeId = "eio_iframe_" + @index
              iframe = undefined
              form.className = "socketio"
              form.style.position = "absolute"
              form.style.top = "-1000px"
              form.style.left = "-1000px"
              form.target = id
              form.method = "POST"
              form.setAttribute "accept-charset", "utf-8"
              area.name = "d"
              form.appendChild area
              document.body.appendChild form
              @form = form
              @area = area
            @form.action = @uri()
            initIframe()
            data = data.replace(rEscapedNewline, "\\\n")
            @area.value = data.replace(rNewline, "\\n")
            try
              @form.submit()
            if @iframe.attachEvent
              @iframe.onreadystatechange = ->
                complete()  if self.iframe.readyState is "complete"
                return
            else
              @iframe.onload = complete
            return

          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./polling": 17
        "component-inherit": 20
      }
    ]
    16: [
      (_dereq_, module, exports) ->
        ((global) ->
          empty = ->
          XHR = (opts) ->
            Polling.call this, opts
            if global.location
              isSSL = "https:" is location.protocol
              port = location.port
              port = (if isSSL then 443 else 80)  unless port
              @xd = opts.hostname isnt global.location.hostname or port isnt opts.port
              @xs = opts.secure isnt isSSL
            return
          Request = (opts) ->
            @method = opts.method or "GET"
            @uri = opts.uri
            @xd = !!opts.xd
            @xs = !!opts.xs
            @async = false isnt opts.async
            @data = (if `undefined` isnt opts.data then opts.data else null)
            @agent = opts.agent
            @isBinary = opts.isBinary
            @supportsBinary = opts.supportsBinary
            @enablesXDR = opts.enablesXDR
            @create()
            return
          unloadHandler = ->
            for i of Request.requests
              Request.requests[i].abort()  if Request.requests.hasOwnProperty(i)
            return
          XMLHttpRequest = _dereq_("xmlhttprequest")
          Polling = _dereq_("./polling")
          Emitter = _dereq_("component-emitter")
          inherit = _dereq_("component-inherit")
          debug = _dereq_("debug")("engine.io-client:polling-xhr")
          module.exports = XHR
          module.exports.Request = Request
          inherit XHR, Polling
          XHR::supportsBinary = true
          XHR::request = (opts) ->
            opts = opts or {}
            opts.uri = @uri()
            opts.xd = @xd
            opts.xs = @xs
            opts.agent = @agent or false
            opts.supportsBinary = @supportsBinary
            opts.enablesXDR = @enablesXDR
            new Request(opts)

          XHR::doWrite = (data, fn) ->
            isBinary = typeof data isnt "string" and data isnt `undefined`
            req = @request(
              method: "POST"
              data: data
              isBinary: isBinary
            )
            self = this
            req.on "success", fn
            req.on "error", (err) ->
              self.onError "xhr post error", err
              return

            @sendXhr = req
            return

          XHR::doPoll = ->
            debug "xhr poll"
            req = @request()
            self = this
            req.on "data", (data) ->
              self.onData data
              return

            req.on "error", (err) ->
              self.onError "xhr poll error", err
              return

            @pollXhr = req
            return

          Emitter Request::
          Request::create = ->
            xhr = @xhr = new XMLHttpRequest(
              agent: @agent
              xdomain: @xd
              xscheme: @xs
              enablesXDR: @enablesXDR
            )
            self = this
            try
              debug "xhr open %s: %s", @method, @uri
              xhr.open @method, @uri, @async
              xhr.responseType = "arraybuffer"  if @supportsBinary
              if "POST" is @method
                try
                  if @isBinary
                    xhr.setRequestHeader "Content-type", "application/octet-stream"
                  else
                    xhr.setRequestHeader "Content-type", "text/plain;charset=UTF-8"
              xhr.withCredentials = true  if "withCredentials" of xhr
              if @hasXDR()
                xhr.onload = ->
                  self.onLoad()
                  return

                xhr.onerror = ->
                  self.onError xhr.responseText
                  return
              else
                xhr.onreadystatechange = ->
                  return  unless 4 is xhr.readyState
                  if 200 is xhr.status or 1223 is xhr.status
                    self.onLoad()
                  else
                    setTimeout (->
                      self.onError xhr.status
                      return
                    ), 0
                  return
              debug "xhr data %s", @data
              xhr.send @data
            catch e
              setTimeout (->
                self.onError e
                return
              ), 0
              return
            if global.document
              @index = Request.requestsCount++
              Request.requests[@index] = this
            return

          Request::onSuccess = ->
            @emit "success"
            @cleanup()
            return

          Request::onData = (data) ->
            @emit "data", data
            @onSuccess()
            return

          Request::onError = (err) ->
            @emit "error", err
            @cleanup()
            return

          Request::cleanup = ->
            return  if "undefined" is typeof @xhr or null is @xhr
            if @hasXDR()
              @xhr.onload = @xhr.onerror = empty
            else
              @xhr.onreadystatechange = empty
            try
              @xhr.abort()
            delete Request.requests[@index]  if global.document
            @xhr = null
            return

          Request::onLoad = ->
            data = undefined
            try
              contentType = undefined
              try
                contentType = @xhr.getResponseHeader("Content-Type").split(";")[0]
              if contentType is "application/octet-stream"
                data = @xhr.response
              else
                unless @supportsBinary
                  data = @xhr.responseText
                else
                  data = "ok"
            catch e
              @onError e
            @onData data  unless null is data
            return

          Request::hasXDR = ->
            "undefined" isnt typeof global.XDomainRequest and not @xs and @enablesXDR

          Request::abort = ->
            @cleanup()
            return

          if global.document
            Request.requestsCount = 0
            Request.requests = {}
            if global.attachEvent
              global.attachEvent "onunload", unloadHandler
            else global.addEventListener "beforeunload", unloadHandler, false  if global.addEventListener
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./polling": 17
        "component-emitter": 8
        "component-inherit": 20
        debug: 21
        xmlhttprequest: 19
      }
    ]
    17: [
      (_dereq_, module, exports) ->
        Polling = (opts) ->
          forceBase64 = opts and opts.forceBase64
          @supportsBinary = false  if not hasXHR2 or forceBase64
          Transport.call this, opts
          return
        Transport = _dereq_("../transport")
        parseqs = _dereq_("parseqs")
        parser = _dereq_("engine.io-parser")
        inherit = _dereq_("component-inherit")
        debug = _dereq_("debug")("engine.io-client:polling")
        module.exports = Polling
        hasXHR2 = ->
          XMLHttpRequest = _dereq_("xmlhttprequest")
          xhr = new XMLHttpRequest(xdomain: false)
          null isnt xhr.responseType
        ()
        inherit Polling, Transport
        Polling::name = "polling"
        Polling::doOpen = ->
          @poll()
          return

        Polling::pause = (onPause) ->
          pause = ->
            debug "paused"
            self.readyState = "paused"
            onPause()
            return
          pending = 0
          self = this
          @readyState = "pausing"
          if @polling or not @writable
            total = 0
            if @polling
              debug "we are currently polling - waiting to pause"
              total++
              @once "pollComplete", ->
                debug "pre-pause polling complete"
                --total or pause()
                return

            unless @writable
              debug "we are currently writing - waiting to pause"
              total++
              @once "drain", ->
                debug "pre-pause writing complete"
                --total or pause()
                return

          else
            pause()
          return

        Polling::poll = ->
          debug "polling"
          @polling = true
          @doPoll()
          @emit "poll"
          return

        Polling::onData = (data) ->
          self = this
          debug "polling got data %s", data
          callback = (packet, index, total) ->
            self.onOpen()  if "opening" is self.readyState
            if "close" is packet.type
              self.onClose()
              return false
            self.onPacket packet
            return

          parser.decodePayload data, @socket.binaryType, callback
          unless "closed" is @readyState
            @polling = false
            @emit "pollComplete"
            if "open" is @readyState
              @poll()
            else
              debug "ignoring poll - transport state \"%s\"", @readyState
          return

        Polling::doClose = ->
          close = ->
            debug "writing close packet"
            self.write [type: "close"]
            return
          self = this
          if "open" is @readyState
            debug "transport open - closing"
            close()
          else
            debug "transport not open - deferring close"
            @once "open", close
          return

        Polling::write = (packets) ->
          self = this
          @writable = false
          callbackfn = ->
            self.writable = true
            self.emit "drain"
            return

          self = this
          parser.encodePayload packets, @supportsBinary, (data) ->
            self.doWrite data, callbackfn
            return

          return

        Polling::uri = ->
          query = @query or {}
          schema = (if @secure then "https" else "http")
          port = ""
          query[@timestampParam] = +new Date + "-" + Transport.timestamps++  if false isnt @timestampRequests
          query.b64 = 1  if not @supportsBinary and not query.sid
          query = parseqs.encode(query)
          port = ":" + @port  if @port and ("https" is schema and @port isnt 443 or "http" is schema and @port isnt 80)
          query = "?" + query  if query.length
          schema + "://" + @hostname + port + @path + query
      {
        "../transport": 13
        "component-inherit": 20
        debug: 21
        "engine.io-parser": 24
        parseqs: 32
        xmlhttprequest: 19
      }
    ]
    18: [
      (_dereq_, module, exports) ->
        WS = (opts) ->
          forceBase64 = opts and opts.forceBase64
          @supportsBinary = false  if forceBase64
          Transport.call this, opts
          return
        Transport = _dereq_("../transport")
        parser = _dereq_("engine.io-parser")
        parseqs = _dereq_("parseqs")
        inherit = _dereq_("component-inherit")
        debug = _dereq_("debug")("engine.io-client:websocket")
        WebSocket = _dereq_("ws")
        module.exports = WS
        inherit WS, Transport
        WS::name = "websocket"
        WS::supportsBinary = true
        WS::doOpen = ->
          return  unless @check()
          self = this
          uri = @uri()
          protocols = undefined
          opts = agent: @agent
          @ws = new WebSocket(uri, protocols, opts)
          @supportsBinary = false  if @ws.binaryType is `undefined`
          @ws.binaryType = "arraybuffer"
          @addEventListeners()
          return

        WS::addEventListeners = ->
          self = this
          @ws.onopen = ->
            self.onOpen()
            return

          @ws.onclose = ->
            self.onClose()
            return

          @ws.onmessage = (ev) ->
            self.onData ev.data
            return

          @ws.onerror = (e) ->
            self.onError "websocket error", e
            return

          return

        if "undefined" isnt typeof navigator and /iPad|iPhone|iPod/i.test(navigator.userAgent)
          WS::onData = (data) ->
            self = this
            setTimeout (->
              Transport::onData.call self, data
              return
            ), 0
            return
        WS::write = (packets) ->
          ondrain = ->
            self.writable = true
            self.emit "drain"
            return
          self = this
          @writable = false
          i = 0
          l = packets.length

          while i < l
            parser.encodePacket packets[i], @supportsBinary, (data) ->
              try
                self.ws.send data
              catch e
                debug "websocket closed before onclose event"
              return

            i++
          setTimeout ondrain, 0
          return

        WS::onClose = ->
          Transport::onClose.call this
          return

        WS::doClose = ->
          @ws.close()  if typeof @ws isnt "undefined"
          return

        WS::uri = ->
          query = @query or {}
          schema = (if @secure then "wss" else "ws")
          port = ""
          port = ":" + @port  if @port and ("wss" is schema and @port isnt 443 or "ws" is schema and @port isnt 80)
          query[@timestampParam] = +new Date  if @timestampRequests
          query.b64 = 1  unless @supportsBinary
          query = parseqs.encode(query)
          query = "?" + query  if query.length
          schema + "://" + @hostname + port + @path + query

        WS::check = ->
          !!WebSocket and not ("__initialize" of WebSocket and @name is WS::name)
      {
        "../transport": 13
        "component-inherit": 20
        debug: 21
        "engine.io-parser": 24
        parseqs: 32
        ws: 34
      }
    ]
    19: [
      (_dereq_, module, exports) ->
        hasCORS = _dereq_("has-cors")
        module.exports = (opts) ->
          xdomain = opts.xdomain
          xscheme = opts.xscheme
          enablesXDR = opts.enablesXDR
          try
            return new XMLHttpRequest  if "undefined" isnt typeof XMLHttpRequest and (not xdomain or hasCORS)
          try
            return new XDomainRequest  if "undefined" isnt typeof XDomainRequest and not xscheme and enablesXDR
          unless xdomain
            try
              return new ActiveXObject("Microsoft.XMLHTTP")
          return
      {
        "has-cors": 37
      }
    ]
    20: [
      (_dereq_, module, exports) ->
        module.exports = (a, b) ->
          fn = ->

          fn:: = b::
          a:: = new fn
          a::constructor = a
          return
      {
        {}
      }
    ]
    21: [
      (_dereq_, module, exports) ->
        useColors = ->
          "WebkitAppearance" of document.documentElement.style or window.console and (console.firebug or console.exception and console.table) or navigator.userAgent.toLowerCase().match(/firefox\/(\d+)/) and parseInt(RegExp.$1, 10) >= 31
        formatArgs = ->
          args = arguments
          useColors = @useColors
          args[0] = ((if useColors then "%c" else "")) + @namespace + ((if useColors then " %c" else " ")) + args[0] + ((if useColors then "%c " else " ")) + "+" + exports.humanize(@diff)
          return args  unless useColors
          c = "color: " + @color
          args = [
            args[0]
            c
            "color: inherit"
          ].concat(Array::slice.call(args, 1))
          index = 0
          lastC = 0
          args[0].replace /%[a-z%]/g, (match) ->
            return  if "%" is match
            index++
            lastC = index  if "%c" is match
            return

          args.splice lastC, 0, c
          args
        log = ->
          "object" is typeof console and "function" is typeof console.log and Function::apply.call(console.log, console, arguments)
        save = (namespaces) ->
          try
            if null is namespaces
              localStorage.removeItem "debug"
            else
              localStorage.debug = namespaces
          return
        load = ->
          r = undefined
          try
            r = localStorage.debug
          r
        exports = module.exports = _dereq_("./debug")
        exports.log = log
        exports.formatArgs = formatArgs
        exports.save = save
        exports.load = load
        exports.useColors = useColors
        exports.colors = [
          "lightseagreen"
          "forestgreen"
          "goldenrod"
          "dodgerblue"
          "darkorchid"
          "crimson"
        ]
        exports.formatters.j = (v) ->
          JSON.stringify v

        exports.enable load()
      {
        "./debug": 22
      }
    ]
    22: [
      (_dereq_, module, exports) ->
        selectColor = ->
          exports.colors[prevColor++ % exports.colors.length]
        debug = (namespace) ->
          disabled = ->
          enabled = ->
            self = enabled
            curr = +new Date
            ms = curr - (prevTime or curr)
            self.diff = ms
            self.prev = prevTime
            self.curr = curr
            prevTime = curr
            self.useColors = exports.useColors()  if null is self.useColors
            self.color = selectColor()  if null is self.color and self.useColors
            args = Array::slice.call(arguments)
            args[0] = exports.coerce(args[0])
            args = ["%o"].concat(args)  if "string" isnt typeof args[0]
            index = 0
            args[0] = args[0].replace(/%([a-z%])/g, (match, format) ->
              return match  if match is "%"
              index++
              formatter = exports.formatters[format]
              if "function" is typeof formatter
                val = args[index]
                match = formatter.call(self, val)
                args.splice index, 1
                index--
              match
            )
            args = exports.formatArgs.apply(self, args)  if "function" is typeof exports.formatArgs
            logFn = enabled.log or exports.log or console.log.bind(console)
            logFn.apply self, args
            return
          disabled.enabled = false
          enabled.enabled = true
          fn = (if exports.enabled(namespace) then enabled else disabled)
          fn.namespace = namespace
          fn
        enable = (namespaces) ->
          exports.save namespaces
          split = (namespaces or "").split(/[\s,]+/)
          len = split.length
          i = 0

          while i < len
            continue  unless split[i]
            namespaces = split[i].replace(/\*/g, ".*?")
            if namespaces[0] is "-"
              exports.skips.push new RegExp("^" + namespaces.substr(1) + "$")
            else
              exports.names.push new RegExp("^" + namespaces + "$")
            i++
          return
        disable = ->
          exports.enable ""
          return
        enabled = (name) ->
          i = undefined
          len = undefined
          i = 0
          len = exports.skips.length

          while i < len
            return false  if exports.skips[i].test(name)
            i++
          i = 0
          len = exports.names.length

          while i < len
            return true  if exports.names[i].test(name)
            i++
          false
        coerce = (val) ->
          return val.stack or val.message  if val instanceof Error
          val
        exports = module.exports = debug
        exports.coerce = coerce
        exports.disable = disable
        exports.enable = enable
        exports.enabled = enabled
        exports.humanize = _dereq_("ms")
        exports.names = []
        exports.skips = []
        exports.formatters = {}
        prevColor = 0
        prevTime = undefined
      {
        ms: 23
      }
    ]
    23: [
      (_dereq_, module, exports) ->
        parse = (str) ->
          match = /^((?:\d+)?\.?\d+) *(ms|seconds?|s|minutes?|m|hours?|h|days?|d|years?|y)?$/i.exec(str)
          return  unless match
          n = parseFloat(match[1])
          type = (match[2] or "ms").toLowerCase()
          switch type
            when "years", "year", "y"
              n * y
            when "days", "day", "d"
              n * d
            when "hours", "hour", "h"
              n * h
            when "minutes", "minute", "m"
              n * m
            when "seconds", "second", "s"
              n * s
            when "ms"
              n
        short = (ms) ->
          return Math.round(ms / d) + "d"  if ms >= d
          return Math.round(ms / h) + "h"  if ms >= h
          return Math.round(ms / m) + "m"  if ms >= m
          return Math.round(ms / s) + "s"  if ms >= s
          ms + "ms"
        long = (ms) ->
          plural(ms, d, "day") or plural(ms, h, "hour") or plural(ms, m, "minute") or plural(ms, s, "second") or ms + " ms"
        plural = (ms, n, name) ->
          return  if ms < n
          return Math.floor(ms / n) + " " + name  if ms < n * 1.5
          Math.ceil(ms / n) + " " + name + "s"
        s = 1e3
        m = s * 60
        h = m * 60
        d = h * 24
        y = d * 365.25
        module.exports = (val, options) ->
          options = options or {}
          return parse(val)  if "string" is typeof val
          (if options.long then long(val) else short(val))
      {
        {}
      }
    ]
    24: [
      (_dereq_, module, exports) ->
        ((global) ->
          encodeArrayBuffer = (packet, supportsBinary, callback) ->
            return exports.encodeBase64Packet(packet, callback)  unless supportsBinary
            data = packet.data
            contentArray = new Uint8Array(data)
            resultBuffer = new Uint8Array(1 + data.byteLength)
            resultBuffer[0] = packets[packet.type]
            i = 0

            while i < contentArray.length
              resultBuffer[i + 1] = contentArray[i]
              i++
            callback resultBuffer.buffer
          encodeBlobAsArrayBuffer = (packet, supportsBinary, callback) ->
            return exports.encodeBase64Packet(packet, callback)  unless supportsBinary
            fr = new FileReader
            fr.onload = ->
              packet.data = fr.result
              exports.encodePacket packet, supportsBinary, true, callback
              return

            fr.readAsArrayBuffer packet.data
          encodeBlob = (packet, supportsBinary, callback) ->
            return exports.encodeBase64Packet(packet, callback)  unless supportsBinary
            return encodeBlobAsArrayBuffer(packet, supportsBinary, callback)  if isAndroid
            length = new Uint8Array(1)
            length[0] = packets[packet.type]
            blob = new Blob([
              length.buffer
              packet.data
            ])
            callback blob
          map = (ary, each, done) ->
            result = new Array(ary.length)
            next = after(ary.length, done)
            eachWithIndex = (i, el, cb) ->
              each el, (error, msg) ->
                result[i] = msg
                cb error, result
                return

              return

            i = 0

            while i < ary.length
              eachWithIndex i, ary[i], next
              i++
            return
          keys = _dereq_("./keys")
          sliceBuffer = _dereq_("arraybuffer.slice")
          base64encoder = _dereq_("base64-arraybuffer")
          after = _dereq_("after")
          utf8 = _dereq_("utf8")
          isAndroid = navigator.userAgent.match(/Android/i)
          exports.protocol = 3
          packets = exports.packets =
            open: 0
            close: 1
            ping: 2
            pong: 3
            message: 4
            upgrade: 5
            noop: 6

          packetslist = keys(packets)
          err =
            type: "error"
            data: "parser error"

          Blob = _dereq_("blob")
          exports.encodePacket = (packet, supportsBinary, utf8encode, callback) ->
            if "function" is typeof supportsBinary
              callback = supportsBinary
              supportsBinary = false
            if "function" is typeof utf8encode
              callback = utf8encode
              utf8encode = null
            data = (if packet.data is `undefined` then `undefined` else packet.data.buffer or packet.data)
            if global.ArrayBuffer and data instanceof ArrayBuffer
              return encodeArrayBuffer(packet, supportsBinary, callback)
            else return encodeBlob(packet, supportsBinary, callback)  if Blob and data instanceof global.Blob
            encoded = packets[packet.type]
            encoded += (if utf8encode then utf8.encode(String(packet.data)) else String(packet.data))  if `undefined` isnt packet.data
            callback "" + encoded

          exports.encodeBase64Packet = (packet, callback) ->
            message = "b" + exports.packets[packet.type]
            if Blob and packet.data instanceof Blob
              fr = new FileReader
              fr.onload = ->
                b64 = fr.result.split(",")[1]
                callback message + b64
                return

              return fr.readAsDataURL(packet.data)
            b64data = undefined
            try
              b64data = String.fromCharCode.apply(null, new Uint8Array(packet.data))
            catch e
              typed = new Uint8Array(packet.data)
              basic = new Array(typed.length)
              i = 0

              while i < typed.length
                basic[i] = typed[i]
                i++
              b64data = String.fromCharCode.apply(null, basic)
            message += global.btoa(b64data)
            callback message

          exports.decodePacket = (data, binaryType, utf8decode) ->
            if typeof data is "string" or data is `undefined`
              return exports.decodeBase64Packet(data.substr(1), binaryType)  if data.charAt(0) is "b"
              if utf8decode
                try
                  data = utf8.decode(data)
                catch e
                  return err
              type = data.charAt(0)
              return err  if Number(type) isnt type or not packetslist[type]
              if data.length > 1
                return (
                  type: packetslist[type]
                  data: data.substring(1)
                )
              else
                return type: packetslist[type]
            asArray = new Uint8Array(data)
            type = asArray[0]
            rest = sliceBuffer(data, 1)
            rest = new Blob([rest])  if Blob and binaryType is "blob"
            type: packetslist[type]
            data: rest

          exports.decodeBase64Packet = (msg, binaryType) ->
            type = packetslist[msg.charAt(0)]
            unless global.ArrayBuffer
              return (
                type: type
                data:
                  base64: true
                  data: msg.substr(1)
              )
            data = base64encoder.decode(msg.substr(1))
            data = new Blob([data])  if binaryType is "blob" and Blob
            type: type
            data: data

          exports.encodePayload = (packets, supportsBinary, callback) ->
            setLengthHeader = (message) ->
              message.length + ":" + message
            encodeOne = (packet, doneCallback) ->
              exports.encodePacket packet, supportsBinary, true, (message) ->
                doneCallback null, setLengthHeader(message)
                return

              return
            if typeof supportsBinary is "function"
              callback = supportsBinary
              supportsBinary = null
            if supportsBinary
              return exports.encodePayloadAsBlob(packets, callback)  if Blob and not isAndroid
              return exports.encodePayloadAsArrayBuffer(packets, callback)
            return callback("0:")  unless packets.length
            map packets, encodeOne, (err, results) ->
              callback results.join("")

            return

          exports.decodePayload = (data, binaryType, callback) ->
            return exports.decodePayloadAsBinary(data, binaryType, callback)  unless typeof data is "string"
            if typeof binaryType is "function"
              callback = binaryType
              binaryType = null
            packet = undefined
            return callback(err, 0, 1)  if data is ""
            length = ""
            n = undefined
            msg = undefined
            i = 0
            l = data.length

            while i < l
              chr = data.charAt(i)
              unless ":" is chr
                length += chr
              else
                return callback(err, 0, 1)  if "" is length or length isnt (n = Number(length))
                msg = data.substr(i + 1, n)
                return callback(err, 0, 1)  unless length is msg.length
                if msg.length
                  packet = exports.decodePacket(msg, binaryType, true)
                  return callback(err, 0, 1)  if err.type is packet.type and err.data is packet.data
                  ret = callback(packet, i + n, l)
                  return  if false is ret
                i += n
                length = ""
              i++
            callback err, 0, 1  unless length is ""

          exports.encodePayloadAsArrayBuffer = (packets, callback) ->
            encodeOne = (packet, doneCallback) ->
              exports.encodePacket packet, true, true, (data) ->
                doneCallback null, data

              return
            return callback(new ArrayBuffer(0))  unless packets.length
            map packets, encodeOne, (err, encodedPackets) ->
              totalLength = encodedPackets.reduce((acc, p) ->
                len = undefined
                if typeof p is "string"
                  len = p.length
                else
                  len = p.byteLength
                acc + len.toString().length + len + 2
              , 0)
              resultArray = new Uint8Array(totalLength)
              bufferIndex = 0
              encodedPackets.forEach (p) ->
                isString = typeof p is "string"
                ab = p
                if isString
                  view = new Uint8Array(p.length)
                  i = 0

                  while i < p.length
                    view[i] = p.charCodeAt(i)
                    i++
                  ab = view.buffer
                if isString
                  resultArray[bufferIndex++] = 0
                else
                  resultArray[bufferIndex++] = 1
                lenStr = ab.byteLength.toString()
                i = 0

                while i < lenStr.length
                  resultArray[bufferIndex++] = parseInt(lenStr[i])
                  i++
                resultArray[bufferIndex++] = 255
                view = new Uint8Array(ab)
                i = 0

                while i < view.length
                  resultArray[bufferIndex++] = view[i]
                  i++
                return

              callback resultArray.buffer

            return

          exports.encodePayloadAsBlob = (packets, callback) ->
            encodeOne = (packet, doneCallback) ->
              exports.encodePacket packet, true, true, (encoded) ->
                binaryIdentifier = new Uint8Array(1)
                binaryIdentifier[0] = 1
                if typeof encoded is "string"
                  view = new Uint8Array(encoded.length)
                  i = 0

                  while i < encoded.length
                    view[i] = encoded.charCodeAt(i)
                    i++
                  encoded = view.buffer
                  binaryIdentifier[0] = 0
                len = (if encoded instanceof ArrayBuffer then encoded.byteLength else encoded.size)
                lenStr = len.toString()
                lengthAry = new Uint8Array(lenStr.length + 1)
                i = 0

                while i < lenStr.length
                  lengthAry[i] = parseInt(lenStr[i])
                  i++
                lengthAry[lenStr.length] = 255
                if Blob
                  blob = new Blob([
                    binaryIdentifier.buffer
                    lengthAry.buffer
                    encoded
                  ])
                  doneCallback null, blob
                return

              return
            map packets, encodeOne, (err, results) ->
              callback new Blob(results)

            return

          exports.decodePayloadAsBinary = (data, binaryType, callback) ->
            if typeof binaryType is "function"
              callback = binaryType
              binaryType = null
            bufferTail = data
            buffers = []
            numberTooLong = false
            while bufferTail.byteLength > 0
              tailArray = new Uint8Array(bufferTail)
              isString = tailArray[0] is 0
              msgLength = ""
              i = 1

              loop
                break  if tailArray[i] is 255
                if msgLength.length > 310
                  numberTooLong = true
                  break
                msgLength += tailArray[i]
                i++
              return callback(err, 0, 1)  if numberTooLong
              bufferTail = sliceBuffer(bufferTail, 2 + msgLength.length)
              msgLength = parseInt(msgLength)
              msg = sliceBuffer(bufferTail, 0, msgLength)
              if isString
                try
                  msg = String.fromCharCode.apply(null, new Uint8Array(msg))
                catch e
                  typed = new Uint8Array(msg)
                  msg = ""
                  i = 0

                  while i < typed.length
                    msg += String.fromCharCode(typed[i])
                    i++
              buffers.push msg
              bufferTail = sliceBuffer(bufferTail, msgLength)
            total = buffers.length
            buffers.forEach (buffer, i) ->
              callback exports.decodePacket(buffer, binaryType, true), i, total
              return

            return

          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./keys": 25
        after: 26
        "arraybuffer.slice": 27
        "base64-arraybuffer": 28
        blob: 29
        utf8: 30
      }
    ]
    25: [
      (_dereq_, module, exports) ->
        module.exports = Object.keys or keys = (obj) ->
          arr = []
          has = Object::hasOwnProperty
          for i of obj
            arr.push i  if has.call(obj, i)
          arr
      {
        {}
      }
    ]
    26: [
      (_dereq_, module, exports) ->
        after = (count, callback, err_cb) ->
          proxy = (err, result) ->
            throw new Error("after called too many times")  if proxy.count <= 0
            --proxy.count
            if err
              bail = true
              callback err
              callback = err_cb
            else callback null, result  if proxy.count is 0 and not bail
            return
          bail = false
          err_cb = err_cb or noop
          proxy.count = count
          return (if count is 0 then callback() else proxy)
          return
        noop = ->
        module.exports = after
      {
        {}
      }
    ]
    27: [
      (_dereq_, module, exports) ->
        module.exports = (arraybuffer, start, end) ->
          bytes = arraybuffer.byteLength
          start = start or 0
          end = end or bytes
          return arraybuffer.slice(start, end)  if arraybuffer.slice
          start += bytes  if start < 0
          end += bytes  if end < 0
          end = bytes  if end > bytes
          return new ArrayBuffer(0)  if start >= bytes or start >= end or bytes is 0
          abv = new Uint8Array(arraybuffer)
          result = new Uint8Array(end - start)
          i = start
          ii = 0

          while i < end
            result[ii] = abv[i]
            i++
            ii++
          result.buffer
      {
        {}
      }
    ]
    28: [
      (_dereq_, module, exports) ->
        ((chars) ->
          "use strict"
          exports.encode = (arraybuffer) ->
            bytes = new Uint8Array(arraybuffer)
            i = undefined
            len = bytes.length
            base64 = ""
            i = 0
            while i < len
              base64 += chars[bytes[i] >> 2]
              base64 += chars[(bytes[i] & 3) << 4 | bytes[i + 1] >> 4]
              base64 += chars[(bytes[i + 1] & 15) << 2 | bytes[i + 2] >> 6]
              base64 += chars[bytes[i + 2] & 63]
              i += 3
            if len % 3 is 2
              base64 = base64.substring(0, base64.length - 1) + "="
            else base64 = base64.substring(0, base64.length - 2) + "=="  if len % 3 is 1
            base64

          exports.decode = (base64) ->
            bufferLength = base64.length * .75
            len = base64.length
            i = undefined
            p = 0
            encoded1 = undefined
            encoded2 = undefined
            encoded3 = undefined
            encoded4 = undefined
            if base64[base64.length - 1] is "="
              bufferLength--
              bufferLength--  if base64[base64.length - 2] is "="
            arraybuffer = new ArrayBuffer(bufferLength)
            bytes = new Uint8Array(arraybuffer)
            i = 0
            while i < len
              encoded1 = chars.indexOf(base64[i])
              encoded2 = chars.indexOf(base64[i + 1])
              encoded3 = chars.indexOf(base64[i + 2])
              encoded4 = chars.indexOf(base64[i + 3])
              bytes[p++] = encoded1 << 2 | encoded2 >> 4
              bytes[p++] = (encoded2 & 15) << 4 | encoded3 >> 2
              bytes[p++] = (encoded3 & 3) << 6 | encoded4 & 63
              i += 4
            arraybuffer

          return
        ) "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
      {
        {}
      }
    ]
    29: [
      (_dereq_, module, exports) ->
        ((global) ->
          BlobBuilderConstructor = (ary, options) ->
            options = options or {}
            bb = new BlobBuilder
            i = 0

            while i < ary.length
              bb.append ary[i]
              i++
            (if options.type then bb.getBlob(options.type) else bb.getBlob())
          BlobBuilder = global.BlobBuilder or global.WebKitBlobBuilder or global.MSBlobBuilder or global.MozBlobBuilder
          blobSupported = ->
            try
              b = new Blob(["hi"])
              return b.size is 2
            catch e
              return false
            return
          ()
          blobBuilderSupported = BlobBuilder and BlobBuilder::append and BlobBuilder::getBlob
          module.exports = ->
            if blobSupported
              global.Blob
            else if blobBuilderSupported
              BlobBuilderConstructor
            else
              `undefined`
          ()
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        {}
      }
    ]
    30: [
      (_dereq_, module, exports) ->
        ((global) ->
          ((root) ->
            ucs2decode = (string) ->
              output = []
              counter = 0
              length = string.length
              value = undefined
              extra = undefined
              while counter < length
                value = string.charCodeAt(counter++)
                if value >= 55296 and value <= 56319 and counter < length
                  extra = string.charCodeAt(counter++)
                  if (extra & 64512) is 56320
                    output.push ((value & 1023) << 10) + (extra & 1023) + 65536
                  else
                    output.push value
                    counter--
                else
                  output.push value
              output
            ucs2encode = (array) ->
              length = array.length
              index = -1
              value = undefined
              output = ""
              while ++index < length
                value = array[index]
                if value > 65535
                  value -= 65536
                  output += stringFromCharCode(value >>> 10 & 1023 | 55296)
                  value = 56320 | value & 1023
                output += stringFromCharCode(value)
              output
            createByte = (codePoint, shift) ->
              stringFromCharCode codePoint >> shift & 63 | 128
            encodeCodePoint = (codePoint) ->
              return stringFromCharCode(codePoint)  if (codePoint & 4294967168) is 0
              symbol = ""
              if (codePoint & 4294965248) is 0
                symbol = stringFromCharCode(codePoint >> 6 & 31 | 192)
              else if (codePoint & 4294901760) is 0
                symbol = stringFromCharCode(codePoint >> 12 & 15 | 224)
                symbol += createByte(codePoint, 6)
              else if (codePoint & 4292870144) is 0
                symbol = stringFromCharCode(codePoint >> 18 & 7 | 240)
                symbol += createByte(codePoint, 12)
                symbol += createByte(codePoint, 6)
              symbol += stringFromCharCode(codePoint & 63 | 128)
              symbol
            utf8encode = (string) ->
              codePoints = ucs2decode(string)
              length = codePoints.length
              index = -1
              codePoint = undefined
              byteString = ""
              while ++index < length
                codePoint = codePoints[index]
                byteString += encodeCodePoint(codePoint)
              byteString
            readContinuationByte = ->
              throw Error("Invalid byte index")  if byteIndex >= byteCount
              continuationByte = byteArray[byteIndex] & 255
              byteIndex++
              return continuationByte & 63  if (continuationByte & 192) is 128
              throw Error("Invalid continuation byte")return
            decodeSymbol = ->
              byte1 = undefined
              byte2 = undefined
              byte3 = undefined
              byte4 = undefined
              codePoint = undefined
              throw Error("Invalid byte index")  if byteIndex > byteCount
              return false  if byteIndex is byteCount
              byte1 = byteArray[byteIndex] & 255
              byteIndex++
              return byte1  if (byte1 & 128) is 0
              if (byte1 & 224) is 192
                byte2 = readContinuationByte()
                codePoint = (byte1 & 31) << 6 | byte2
                if codePoint >= 128
                  return codePoint
                else
                  throw Error("Invalid continuation byte")
              if (byte1 & 240) is 224
                byte2 = readContinuationByte()
                byte3 = readContinuationByte()
                codePoint = (byte1 & 15) << 12 | byte2 << 6 | byte3
                if codePoint >= 2048
                  return codePoint
                else
                  throw Error("Invalid continuation byte")
              if (byte1 & 248) is 240
                byte2 = readContinuationByte()
                byte3 = readContinuationByte()
                byte4 = readContinuationByte()
                codePoint = (byte1 & 15) << 18 | byte2 << 12 | byte3 << 6 | byte4
                return codePoint  if codePoint >= 65536 and codePoint <= 1114111
              throw Error("Invalid UTF-8 detected")return
            utf8decode = (byteString) ->
              byteArray = ucs2decode(byteString)
              byteCount = byteArray.length
              byteIndex = 0
              codePoints = []
              tmp = undefined
              codePoints.push tmp  while (tmp = decodeSymbol()) isnt false
              ucs2encode codePoints
            freeExports = typeof exports is "object" and exports
            freeModule = typeof module is "object" and module and module.exports is freeExports and module
            freeGlobal = typeof global is "object" and global
            root = freeGlobal  if freeGlobal.global is freeGlobal or freeGlobal.window is freeGlobal
            stringFromCharCode = String.fromCharCode
            byteArray = undefined
            byteCount = undefined
            byteIndex = undefined
            utf8 =
              version: "2.0.0"
              encode: utf8encode
              decode: utf8decode

            if typeof define is "function" and typeof define.amd is "object" and define.amd
              define ->
                utf8

            else if freeExports and not freeExports.nodeType
              if freeModule
                freeModule.exports = utf8
              else
                object = {}
                hasOwnProperty = object.hasOwnProperty
                for key of utf8
                  hasOwnProperty.call(utf8, key) and (freeExports[key] = utf8[key])
            else
              root.utf8 = utf8
            return
          ) this
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        {}
      }
    ]
    31: [
      (_dereq_, module, exports) ->
        ((global) ->
          rvalidchars = /^[\],:{}\s]*$/
          rvalidescape = /\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g
          rvalidtokens = /"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g
          rvalidbraces = /(?:^|:|,)(?:\s*\[)+/g
          rtrimLeft = /^\s+/
          rtrimRight = /\s+$/
          module.exports = parsejson = (data) ->
            return null  if "string" isnt typeof data or not data
            data = data.replace(rtrimLeft, "").replace(rtrimRight, "")
            return JSON.parse(data)  if global.JSON and JSON.parse
            new Function("return " + data)()  if rvalidchars.test(data.replace(rvalidescape, "@").replace(rvalidtokens, "]").replace(rvalidbraces, ""))

          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        {}
      }
    ]
    32: [
      (_dereq_, module, exports) ->
        exports.encode = (obj) ->
          str = ""
          for i of obj
            if obj.hasOwnProperty(i)
              str += "&"  if str.length
              str += encodeURIComponent(i) + "=" + encodeURIComponent(obj[i])
          str

        exports.decode = (qs) ->
          qry = {}
          pairs = qs.split("&")
          i = 0
          l = pairs.length

          while i < l
            pair = pairs[i].split("=")
            qry[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1])
            i++
          qry
      {
        {}
      }
    ]
    33: [
      (_dereq_, module, exports) ->
        re = /^(?:(?![^:@]+:[^:@\/]*@)(http|https|ws|wss):\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?((?:[a-f0-9]{0,4}:){2,7}[a-f0-9]{0,4}|[^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
        parts = [
          "source"
          "protocol"
          "authority"
          "userInfo"
          "user"
          "password"
          "host"
          "port"
          "relative"
          "path"
          "directory"
          "file"
          "query"
          "anchor"
        ]
        module.exports = parseuri = (str) ->
          src = str
          b = str.indexOf("[")
          e = str.indexOf("]")
          str = str.substring(0, b) + str.substring(b, e).replace(/:/g, ";") + str.substring(e, str.length)  if b isnt -1 and e isnt -1
          m = re.exec(str or "")
          uri = {}
          i = 14
          uri[parts[i]] = m[i] or ""  while i--
          if b isnt -1 and e isnt -1
            uri.source = src
            uri.host = uri.host.substring(1, uri.host.length - 1).replace(/;/g, ":")
            uri.authority = uri.authority.replace("[", "").replace("]", "").replace(/;/g, ":")
            uri.ipv6uri = true
          uri
      {
        {}
      }
    ]
    34: [
      (_dereq_, module, exports) ->
        ws = (uri, protocols, opts) ->
          instance = undefined
          if protocols
            instance = new WebSocket(uri, protocols)
          else
            instance = new WebSocket(uri)
          instance
        global = ->
          this
        ()
        WebSocket = global.WebSocket or global.MozWebSocket
        module.exports = (if WebSocket then ws else null)
        ws:: = WebSocket::  if WebSocket
      {
        {}
      }
    ]
    35: [
      (_dereq_, module, exports) ->
        ((global) ->
          hasBinary = (data) ->
            _hasBinary = (obj) ->
              return false  unless obj
              return true  if global.Buffer and global.Buffer.isBuffer(obj) or global.ArrayBuffer and obj instanceof ArrayBuffer or global.Blob and obj instanceof Blob or global.File and obj instanceof File
              if isArray(obj)
                i = 0

                while i < obj.length
                  return true  if _hasBinary(obj[i])
                  i++
              else if obj and "object" is typeof obj
                obj = obj.toJSON()  if obj.toJSON
                for key of obj
                  return true  if obj.hasOwnProperty(key) and _hasBinary(obj[key])
              false
            _hasBinary data
          isArray = _dereq_("isarray")
          module.exports = hasBinary
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        isarray: 36
      }
    ]
    36: [
      (_dereq_, module, exports) ->
        module.exports = Array.isArray or (arr) ->
          Object::toString.call(arr) is "[object Array]"
      {
        {}
      }
    ]
    37: [
      (_dereq_, module, exports) ->
        global = _dereq_("global")
        try
          module.exports = "XMLHttpRequest" of global and "withCredentials" of new global.XMLHttpRequest
        catch err
          module.exports = false
      {
        global: 38
      }
    ]
    38: [
      (_dereq_, module, exports) ->
        module.exports = ->
          this
        ()
      {
        {}
      }
    ]
    39: [
      (_dereq_, module, exports) ->
        indexOf = [].indexOf
        module.exports = (arr, obj) ->
          return arr.indexOf(obj)  if indexOf
          i = 0

          while i < arr.length
            return i  if arr[i] is obj
            ++i
          -1
      {
        {}
      }
    ]
    40: [
      (_dereq_, module, exports) ->
        has = Object::hasOwnProperty
        exports.keys = Object.keys or (obj) ->
          keys = []
          for key of obj
            keys.push key  if has.call(obj, key)
          keys

        exports.values = (obj) ->
          vals = []
          for key of obj
            vals.push obj[key]  if has.call(obj, key)
          vals

        exports.merge = (a, b) ->
          for key of b
            a[key] = b[key]  if has.call(b, key)
          a

        exports.length = (obj) ->
          exports.keys(obj).length

        exports.isEmpty = (obj) ->
          0 is exports.length(obj)
      {
        {}
      }
    ]
    41: [
      (_dereq_, module, exports) ->
        re = /^(?:(?![^:@]+:[^:@\/]*@)(http|https|ws|wss):\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?((?:[a-f0-9]{0,4}:){2,7}[a-f0-9]{0,4}|[^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
        parts = [
          "source"
          "protocol"
          "authority"
          "userInfo"
          "user"
          "password"
          "host"
          "port"
          "relative"
          "path"
          "directory"
          "file"
          "query"
          "anchor"
        ]
        module.exports = parseuri = (str) ->
          m = re.exec(str or "")
          uri = {}
          i = 14
          uri[parts[i]] = m[i] or ""  while i--
          uri
      {
        {}
      }
    ]
    42: [
      (_dereq_, module, exports) ->
        ((global) ->
          isArray = _dereq_("isarray")
          isBuf = _dereq_("./is-buffer")
          exports.deconstructPacket = (packet) ->
            _deconstructPacket = (data) ->
              return data  unless data
              if isBuf(data)
                placeholder =
                  _placeholder: true
                  num: buffers.length

                buffers.push data
                return placeholder
              else if isArray(data)
                newData = new Array(data.length)
                i = 0

                while i < data.length
                  newData[i] = _deconstructPacket(data[i])
                  i++
                return newData
              else if "object" is typeof data and (data not instanceof Date)
                newData = {}
                for key of data
                  newData[key] = _deconstructPacket(data[key])
                return newData
              data
            buffers = []
            packetData = packet.data
            pack = packet
            pack.data = _deconstructPacket(packetData)
            pack.attachments = buffers.length
            packet: pack
            buffers: buffers

          exports.reconstructPacket = (packet, buffers) ->
            _reconstructPacket = (data) ->
              if data and data._placeholder
                buf = buffers[data.num]
                return buf
              else if isArray(data)
                i = 0

                while i < data.length
                  data[i] = _reconstructPacket(data[i])
                  i++
                return data
              else if data and "object" is typeof data
                for key of data
                  data[key] = _reconstructPacket(data[key])
                return data
              data
            curPlaceHolder = 0
            packet.data = _reconstructPacket(packet.data)
            packet.attachments = `undefined`
            packet

          exports.removeBlobs = (data, callback) ->
            _removeBlobs = (obj, curKey, containingObject) ->
              return obj  unless obj
              if global.Blob and obj instanceof Blob or global.File and obj instanceof File
                pendingBlobs++
                fileReader = new FileReader
                fileReader.onload = ->
                  if containingObject
                    containingObject[curKey] = @result
                  else
                    bloblessData = @result
                  callback bloblessData  unless --pendingBlobs
                  return

                fileReader.readAsArrayBuffer obj
              else if isArray(obj)
                i = 0

                while i < obj.length
                  _removeBlobs obj[i], i, obj
                  i++
              else if obj and "object" is typeof obj and not isBuf(obj)
                for key of obj
                  _removeBlobs obj[key], key, obj
              return
            pendingBlobs = 0
            bloblessData = data
            _removeBlobs bloblessData
            callback bloblessData  unless pendingBlobs
            return

          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        "./is-buffer": 44
        isarray: 45
      }
    ]
    43: [
      (_dereq_, module, exports) ->
        Encoder = ->
        encodeAsString = (obj) ->
          str = ""
          nsp = false
          str += obj.type
          if exports.BINARY_EVENT is obj.type or exports.BINARY_ACK is obj.type
            str += obj.attachments
            str += "-"
          if obj.nsp and "/" isnt obj.nsp
            nsp = true
            str += obj.nsp
          unless null is obj.id
            if nsp
              str += ","
              nsp = false
            str += obj.id
          unless null is obj.data
            str += ","  if nsp
            str += json.stringify(obj.data)
          debug "encoded %j as %s", obj, str
          str
        encodeAsBinary = (obj, callback) ->
          writeEncoding = (bloblessData) ->
            deconstruction = binary.deconstructPacket(bloblessData)
            pack = encodeAsString(deconstruction.packet)
            buffers = deconstruction.buffers
            buffers.unshift pack
            callback buffers
            return
          binary.removeBlobs obj, writeEncoding
          return
        Decoder = ->
          @reconstructor = null
          return
        decodeString = (str) ->
          p = {}
          i = 0
          p.type = Number(str.charAt(0))
          return error()  if null is exports.types[p.type]
          if exports.BINARY_EVENT is p.type or exports.BINARY_ACK is p.type
            p.attachments = ""
            p.attachments += str.charAt(i)  until str.charAt(++i) is "-"
            p.attachments = Number(p.attachments)
          if "/" is str.charAt(i + 1)
            p.nsp = ""
            while ++i
              c = str.charAt(i)
              break  if "," is c
              p.nsp += c
              break  if i + 1 is str.length
          else
            p.nsp = "/"
          next = str.charAt(i + 1)
          if "" isnt next and Number(next) is next
            p.id = ""
            while ++i
              c = str.charAt(i)
              if null is c or Number(c) isnt c
                --i
                break
              p.id += str.charAt(i)
              break  if i + 1 is str.length
            p.id = Number(p.id)
          if str.charAt(++i)
            try
              p.data = json.parse(str.substr(i))
            catch e
              return error()
          debug "decoded %s as %j", str, p
          p
        BinaryReconstructor = (packet) ->
          @reconPack = packet
          @buffers = []
          return
        error = (data) ->
          type: exports.ERROR
          data: "parser error"
        debug = _dereq_("debug")("socket.io-parser")
        json = _dereq_("json3")
        isArray = _dereq_("isarray")
        Emitter = _dereq_("component-emitter")
        binary = _dereq_("./binary")
        isBuf = _dereq_("./is-buffer")
        exports.protocol = 4
        exports.types = [
          "CONNECT"
          "DISCONNECT"
          "EVENT"
          "BINARY_EVENT"
          "ACK"
          "BINARY_ACK"
          "ERROR"
        ]
        exports.CONNECT = 0
        exports.DISCONNECT = 1
        exports.EVENT = 2
        exports.ACK = 3
        exports.ERROR = 4
        exports.BINARY_EVENT = 5
        exports.BINARY_ACK = 6
        exports.Encoder = Encoder
        exports.Decoder = Decoder
        Encoder::encode = (obj, callback) ->
          debug "encoding packet %j", obj
          if exports.BINARY_EVENT is obj.type or exports.BINARY_ACK is obj.type
            encodeAsBinary obj, callback
          else
            encoding = encodeAsString(obj)
            callback [encoding]
          return

        Emitter Decoder::
        Decoder::add = (obj) ->
          packet = undefined
          if "string" is typeof obj
            packet = decodeString(obj)
            if exports.BINARY_EVENT is packet.type or exports.BINARY_ACK is packet.type
              @reconstructor = new BinaryReconstructor(packet)
              @emit "decoded", packet  if @reconstructor.reconPack.attachments is 0
            else
              @emit "decoded", packet
          else if isBuf(obj) or obj.base64
            unless @reconstructor
              throw new Error("got binary data when not reconstructing a packet")
            else
              packet = @reconstructor.takeBinaryData(obj)
              if packet
                @reconstructor = null
                @emit "decoded", packet
          else
            throw new Error("Unknown type: " + obj)
          return

        Decoder::destroy = ->
          @reconstructor.finishedReconstruction()  if @reconstructor
          return

        BinaryReconstructor::takeBinaryData = (binData) ->
          @buffers.push binData
          if @buffers.length is @reconPack.attachments
            packet = binary.reconstructPacket(@reconPack, @buffers)
            @finishedReconstruction()
            return packet
          null

        BinaryReconstructor::finishedReconstruction = ->
          @reconPack = null
          @buffers = []
          return
      {
        "./binary": 42
        "./is-buffer": 44
        "component-emitter": 8
        debug: 9
        isarray: 45
        json3: 46
      }
    ]
    44: [
      (_dereq_, module, exports) ->
        ((global) ->
          isBuf = (obj) ->
            global.Buffer and global.Buffer.isBuffer(obj) or global.ArrayBuffer and obj instanceof ArrayBuffer
          module.exports = isBuf
          return
        ).call this, (if typeof self isnt "undefined" then self else (if typeof window isnt "undefined" then window else {}))
      {
        {}
      }
    ]
    45: [
      (_dereq_, module, exports) ->
        module.exports = _dereq_(36)
      {
        {}
      }
    ]
    46: [
      (_dereq_, module, exports) ->
        ((window) ->
          has = (name) ->
            return has[name]  if has[name] isnt undef
            isSupported = undefined
            if name is "bug-string-char-index"
              isSupported = "a"[0] isnt "a"
            else if name is "json"
              isSupported = has("json-stringify") and has("json-parse")
            else
              value = undefined
              serialized = "{\"a\":[1,true,false,null,\"\\u0000\\b\\n\\f\\r\\t\"]}"
              if name is "json-stringify"
                stringify = JSON3.stringify
                stringifySupported = typeof stringify is "function" and isExtended
                if stringifySupported
                  (value = ->
                    1
                  ).toJSON = value
                  try
                    stringifySupported = stringify(0) is "0" and stringify(new Number) is "0" and stringify(new String) is "\"\"" and stringify(getClass) is undef and stringify(undef) is undef and stringify() is undef and stringify(value) is "1" and stringify([value]) is "[1]" and stringify([undef]) is "[null]" and stringify(null) is "null" and stringify([
                      undef
                      getClass
                      null
                    ]) is "[null,null,null]" and stringify(a: [
                      value
                      true
                      false
                      null
                      "\u0000\b\n\f\r  "
                    ]) is serialized and stringify(null, value) is "1" and stringify([
                      1
                      2
                    ], null, 1) is "[\n 1,\n 2\n]" and stringify(new Date(-864e13)) is "\"-271821-04-20T00:00:00.000Z\"" and stringify(new Date(864e13)) is "\"+275760-09-13T00:00:00.000Z\"" and stringify(new Date(-621987552e5)) is "\"-000001-01-01T00:00:00.000Z\"" and stringify(new Date(-1)) is "\"1969-12-31T23:59:59.999Z\""
                  catch exception
                    stringifySupported = false
                isSupported = stringifySupported
              if name is "json-parse"
                parse = JSON3.parse
                if typeof parse is "function"
                  try
                    if parse("0") is 0 and not parse(false)
                      value = parse(serialized)
                      parseSupported = value["a"].length is 5 and value["a"][0] is 1
                      if parseSupported
                        try
                          parseSupported = not parse("\"  \"")
                        if parseSupported
                          try
                            parseSupported = parse("01") isnt 1
                        if parseSupported
                          try
                            parseSupported = parse("1.") isnt 1
                  catch exception
                    parseSupported = false
                isSupported = parseSupported
            has[name] = !!isSupported
          getClass = {}.toString
          isProperty = undefined
          forEach = undefined
          undef = undefined
          isLoader = typeof define is "function" and define.amd
          nativeJSON = typeof JSON is "object" and JSON
          JSON3 = typeof exports is "object" and exports and not exports.nodeType and exports
          if JSON3 and nativeJSON
            JSON3.stringify = nativeJSON.stringify
            JSON3.parse = nativeJSON.parse
          else
            JSON3 = window.JSON = nativeJSON or {}
          isExtended = new Date(-0xc782b5b800cec)
          try
            isExtended = isExtended.getUTCFullYear() is -109252 and isExtended.getUTCMonth() is 0 and isExtended.getUTCDate() is 1 and isExtended.getUTCHours() is 10 and isExtended.getUTCMinutes() is 37 and isExtended.getUTCSeconds() is 6 and isExtended.getUTCMilliseconds() is 708
          unless has("json")
            functionClass = "[object Function]"
            dateClass = "[object Date]"
            numberClass = "[object Number]"
            stringClass = "[object String]"
            arrayClass = "[object Array]"
            booleanClass = "[object Boolean]"
            charIndexBuggy = has("bug-string-char-index")
            unless isExtended
              floor = Math.floor
              Months = [
                0
                31
                59
                90
                120
                151
                181
                212
                243
                273
                304
                334
              ]
              getDay = (year, month) ->
                Months[month] + 365 * (year - 1970) + floor((year - 1969 + (month = +(month > 1))) / 4) - floor((year - 1901 + month) / 100) + floor((year - 1601 + month) / 400)
            unless isProperty = {}.hasOwnProperty
              isProperty = (property) ->
                members = {}
                constructor = undefined
                unless (members.__proto__ = null
                members.__proto__ = toString: 1
                members
                ).toString is getClass
                  isProperty = (property) ->
                    original = @__proto__
                    result = property of (@__proto__ = null
                    this
                    )
                    @__proto__ = original
                    result
                else
                  constructor = members.constructor
                  isProperty = (property) ->
                    parent = (@constructor or constructor)::
                    property of this and not (property of parent and this[property] is parent[property])
                members = null
                isProperty.call this, property
            PrimitiveTypes =
              boolean: 1
              number: 1
              string: 1
              undefined: 1

            isHostType = (object, property) ->
              type = typeof object[property]
              (if type is "object" then !!object[property] else not PrimitiveTypes[type])

            forEach = (object, callback) ->
              size = 0
              Properties = undefined
              members = undefined
              property = undefined
              (Properties = ->
                @valueOf = 0
                return
              )::valueOf = 0
              members = new Properties
              for property of members
                size++  if isProperty.call(members, property)
              Properties = members = null
              unless size
                members = [
                  "valueOf"
                  "toString"
                  "toLocaleString"
                  "propertyIsEnumerable"
                  "isPrototypeOf"
                  "hasOwnProperty"
                  "constructor"
                ]
                forEach = (object, callback) ->
                  isFunction = getClass.call(object) is functionClass
                  property = undefined
                  length = undefined
                  hasProperty = (if not isFunction and typeof object.constructor isnt "function" and isHostType(object, "hasOwnProperty") then object.hasOwnProperty else isProperty)
                  for property of object
                    callback property  if not (isFunction and property is "prototype") and hasProperty.call(object, property)
                  length = members.length
                  while property = members[--length]
                    hasProperty.call(object, property) and callback(property)
                  return
              else if size is 2
                forEach = (object, callback) ->
                  members = {}
                  isFunction = getClass.call(object) is functionClass
                  property = undefined
                  for property of object
                    callback property  if not (isFunction and property is "prototype") and not isProperty.call(members, property) and (members[property] = 1) and isProperty.call(object, property)
                  return
              else
                forEach = (object, callback) ->
                  isFunction = getClass.call(object) is functionClass
                  property = undefined
                  isConstructor = undefined
                  for property of object
                    callback property  if not (isFunction and property is "prototype") and isProperty.call(object, property) and not (isConstructor = property is "constructor")
                  callback property  if isConstructor or isProperty.call(object, property = "constructor")
                  return
              forEach object, callback

            unless has("json-stringify")
              Escapes =
                92: "\\\\"
                34: "\\\""
                8: "\\b"
                12: "\\f"
                10: "\\n"
                13: "\\r"
                9: "\\t"

              leadingZeroes = "000000"
              toPaddedString = (width, value) ->
                (leadingZeroes + (value or 0)).slice -width

              unicodePrefix = "\\u00"
              quote = (value) ->
                result = "\""
                index = 0
                length = value.length
                isLarge = length > 10 and charIndexBuggy
                symbols = undefined
                symbols = value.split("")  if isLarge
                while index < length
                  charCode = value.charCodeAt(index)
                  switch charCode
                    when 8, 9, 10, 12, 13, 34, 92
                      result += Escapes[charCode]
                    else
                      if charCode < 32
                        result += unicodePrefix + toPaddedString(2, charCode.toString(16))
                        break
                      result += (if isLarge then symbols[index] else (if charIndexBuggy then value.charAt(index) else value[index]))
                  index++
                result + "\""

              serialize = (property, object, callback, properties, whitespace, indentation, stack) ->
                value = undefined
                className = undefined
                year = undefined
                month = undefined
                date = undefined
                time = undefined
                hours = undefined
                minutes = undefined
                seconds = undefined
                milliseconds = undefined
                results = undefined
                element = undefined
                index = undefined
                length = undefined
                prefix = undefined
                result = undefined
                try
                  value = object[property]
                if typeof value is "object" and value
                  className = getClass.call(value)
                  if className is dateClass and not isProperty.call(value, "toJSON")
                    if value > -1 / 0 and value < 1 / 0
                      if getDay
                        date = floor(value / 864e5)
                        year = floor(date / 365.2425) + 1970 - 1
                        while getDay(year + 1, 0) <= date
                          year++
                        month = floor((date - getDay(year, 0)) / 30.42)
                        while getDay(year, month + 1) <= date
                          month++
                        date = 1 + date - getDay(year, month)
                        time = (value % 864e5 + 864e5) % 864e5
                        hours = floor(time / 36e5) % 24
                        minutes = floor(time / 6e4) % 60
                        seconds = floor(time / 1e3) % 60
                        milliseconds = time % 1e3
                      else
                        year = value.getUTCFullYear()
                        month = value.getUTCMonth()
                        date = value.getUTCDate()
                        hours = value.getUTCHours()
                        minutes = value.getUTCMinutes()
                        seconds = value.getUTCSeconds()
                        milliseconds = value.getUTCMilliseconds()
                      value = ((if year <= 0 or year >= 1e4 then ((if year < 0 then "-" else "+")) + toPaddedString(6, (if year < 0 then -year else year)) else toPaddedString(4, year))) + "-" + toPaddedString(2, month + 1) + "-" + toPaddedString(2, date) + "T" + toPaddedString(2, hours) + ":" + toPaddedString(2, minutes) + ":" + toPaddedString(2, seconds) + "." + toPaddedString(3, milliseconds) + "Z"
                    else
                      value = null
                  else value = value.toJSON(property)  if typeof value.toJSON is "function" and (className isnt numberClass and className isnt stringClass and className isnt arrayClass or isProperty.call(value, "toJSON"))
                value = callback.call(object, property, value)  if callback
                return "null"  if value is null
                className = getClass.call(value)
                if className is booleanClass
                  return "" + value
                else if className is numberClass
                  return (if value > -1 / 0 and value < 1 / 0 then "" + value else "null")
                else return quote("" + value)  if className is stringClass
                if typeof value is "object"
                  length = stack.length
                  while length--
                    throw TypeError()  if stack[length] is value
                  stack.push value
                  results = []
                  prefix = indentation
                  indentation += whitespace
                  if className is arrayClass
                    index = 0
                    length = value.length

                    while index < length
                      element = serialize(index, value, callback, properties, whitespace, indentation, stack)
                      results.push (if element is undef then "null" else element)
                      index++
                    result = (if results.length then (if whitespace then "[\n" + indentation + results.join(",\n" + indentation) + "\n" + prefix + "]" else "[" + results.join(",") + "]") else "[]")
                  else
                    forEach properties or value, (property) ->
                      element = serialize(property, value, callback, properties, whitespace, indentation, stack)
                      results.push quote(property) + ":" + ((if whitespace then " " else "")) + element  if element isnt undef
                      return

                    result = (if results.length then (if whitespace then "{\n" + indentation + results.join(",\n" + indentation) + "\n" + prefix + "}" else "{" + results.join(",") + "}") else "{}")
                  stack.pop()
                  result

              JSON3.stringify = (source, filter, width) ->
                whitespace = undefined
                callback = undefined
                properties = undefined
                className = undefined
                if typeof filter is "function" or typeof filter is "object" and filter
                  if (className = getClass.call(filter)) is functionClass
                    callback = filter
                  else if className is arrayClass
                    properties = {}
                    index = 0
                    length = filter.length
                    value = undefined

                    while index < length
                      value = filter[index++]
                      (className = getClass.call(value)
                      className is stringClass or className is numberClass
                      ) and (properties[value] = 1)
                if width
                  if (className = getClass.call(width)) is numberClass
                    if (width -= width % 1) > 0
                      whitespace = ""
                      width > 10 and (width = 10)

                      while whitespace.length < width
                        whitespace += " "
                  else whitespace = (if width.length <= 10 then width else width.slice(0, 10))  if className is stringClass
                serialize "", (value = {}
                value[""] = source
                value
                ), callback, properties, whitespace, "", []
            unless has("json-parse")
              fromCharCode = String.fromCharCode
              Unescapes =
                92: "\\"
                34: "\""
                47: "/"
                98: "\b"
                116: "  "
                110: "\n"
                102: "\f"
                114: "\r"

              Index = undefined
              Source = undefined
              abort = ->
                Index = Source = null
                throw SyntaxError()return

              lex = ->
                source = Source
                length = source.length
                value = undefined
                begin = undefined
                position = undefined
                isSigned = undefined
                charCode = undefined
                while Index < length
                  charCode = source.charCodeAt(Index)
                  switch charCode
                    when 9, 10, 13, 32
                      Index++
                    when 123, 125, 91, 93, 58, 44
                      value = (if charIndexBuggy then source.charAt(Index) else source[Index])
                      Index++
                      return value
                    when 34
                      value = "@"
                      Index++

                      while Index < length
                        charCode = source.charCodeAt(Index)
                        if charCode < 32
                          abort()
                        else if charCode is 92
                          charCode = source.charCodeAt(++Index)
                          switch charCode
                            when 92, 34, 47, 98, 116, 110, 102, 114
                              value += Unescapes[charCode]
                              Index++
                            when 117
                              begin = ++Index
                              position = Index + 4
                              while Index < position
                                charCode = source.charCodeAt(Index)
                                abort()  unless charCode >= 48 and charCode <= 57 or charCode >= 97 and charCode <= 102 or charCode >= 65 and charCode <= 70
                                Index++
                              value += fromCharCode("0x" + source.slice(begin, Index))
                            else
                              abort()
                        else
                          break  if charCode is 34
                          charCode = source.charCodeAt(Index)
                          begin = Index
                          charCode = source.charCodeAt(++Index)  while charCode >= 32 and charCode isnt 92 and charCode isnt 34
                          value += source.slice(begin, Index)
                      if source.charCodeAt(Index) is 34
                        Index++
                        return value
                      abort()
                    else
                      begin = Index
                      if charCode is 45
                        isSigned = true
                        charCode = source.charCodeAt(++Index)
                      if charCode >= 48 and charCode <= 57
                        abort()  if charCode is 48 and (charCode = source.charCodeAt(Index + 1)
                        charCode >= 48 and charCode <= 57
                        )
                        isSigned = false
                        while Index < length and (charCode = source.charCodeAt(Index)
                        charCode >= 48 and charCode <= 57
                        )
                          Index++
                        if source.charCodeAt(Index) is 46
                          position = ++Index
                          while position < length and (charCode = source.charCodeAt(position)
                          charCode >= 48 and charCode <= 57
                          )
                            position++
                          abort()  if position is Index
                          Index = position
                        charCode = source.charCodeAt(Index)
                        if charCode is 101 or charCode is 69
                          charCode = source.charCodeAt(++Index)
                          Index++  if charCode is 43 or charCode is 45
                          position = Index
                          while position < length and (charCode = source.charCodeAt(position)
                          charCode >= 48 and charCode <= 57
                          )
                            position++
                          abort()  if position is Index
                          Index = position
                        return +source.slice(begin, Index)
                      abort()  if isSigned
                      if source.slice(Index, Index + 4) is "true"
                        Index += 4
                        return true
                      else if source.slice(Index, Index + 5) is "false"
                        Index += 5
                        return false
                      else if source.slice(Index, Index + 4) is "null"
                        Index += 4
                        return null
                      abort()
                "$"

              get = (value) ->
                results = undefined
                hasMembers = undefined
                abort()  if value is "$"
                if typeof value is "string"
                  return value.slice(1)  if ((if charIndexBuggy then value.charAt(0) else value[0])) is "@"
                  if value is "["
                    results = []
                    loop
                      value = lex()
                      break  if value is "]"
                      if hasMembers
                        if value is ","
                          value = lex()
                          abort()  if value is "]"
                        else
                          abort()
                      abort()  if value is ","
                      results.push get(value)
                      hasMembers or (hasMembers = true)
                    return results
                  else if value is "{"
                    results = {}
                    loop
                      value = lex()
                      break  if value is "}"
                      if hasMembers
                        if value is ","
                          value = lex()
                          abort()  if value is "}"
                        else
                          abort()
                      abort()  if value is "," or typeof value isnt "string" or ((if charIndexBuggy then value.charAt(0) else value[0])) isnt "@" or lex() isnt ":"
                      results[value.slice(1)] = get(lex())
                      hasMembers or (hasMembers = true)
                    return results
                  abort()
                value

              update = (source, property, callback) ->
                element = walk(source, property, callback)
                if element is undef
                  delete source[property]
                else
                  source[property] = element
                return

              walk = (source, property, callback) ->
                value = source[property]
                length = undefined
                if typeof value is "object" and value
                  if getClass.call(value) is arrayClass
                    length = value.length
                    while length--
                      update value, length, callback
                  else
                    forEach value, (property) ->
                      update value, property, callback
                      return

                callback.call source, property, value

              JSON3.parse = (source, callback) ->
                result = undefined
                value = undefined
                Index = 0
                Source = "" + source
                result = get(lex())
                abort()  unless lex() is "$"
                Index = Source = null
                (if callback and getClass.call(callback) is functionClass then walk((value = {}
                value[""] = result
                value
                ), "", callback) else result)
          if isLoader
            define ->
              JSON3

          return
        ) this
      {
        {}
      }
    ]
    47: [
      (_dereq_, module, exports) ->
        toArray = (list, index) ->
          array = []
          index = index or 0
          i = index or 0

          while i < list.length
            array[i - index] = list[i]
            i++
          array
        module.exports = toArray
      {
        {}
      }
    ]
  , {}, [1]) 1
)

###*
sails.io.js
------------------------------------------------------------------------
JavaScript Client (SDK) for communicating with Sails.

Note that this script is completely optional, but it is handy if you're
using WebSockets from the browser to talk to your Sails server.

For tips and documentation, visit:
http://sailsjs.org/#!documentation/reference/BrowserSDK/BrowserSDK.html
------------------------------------------------------------------------

This file allows you to send and receive socket.io messages to & from Sails
by simulating a REST client interface on top of socket.io. It models its API
after the $.ajax pattern from jQuery you might already be familiar with.

So if you're switching from using AJAX to sockets, instead of:
`$.post( url, [data], [cb] )`

You would use:
`socket.post( url, [data], [cb] )`
###
(->
  
  # Save the URL that this script was fetched from for use below.
  # (skip this if this SDK is being used outside of the DOM, i.e. in a Node process)
  
  # Return the URL of the last script loaded (i.e. this one)
  # (this must run before nextTick; see http://stackoverflow.com/a/2976714/486547)
  
  # Constants
  
  # Current version of this SDK (sailsDK?!?!) and other metadata
  # that will be sent along w/ the initial connection request.
  # TODO: pull this automatically from package.json during build.
  
  # In case you're wrapping the socket.io client to prevent pollution of the
  # global namespace, you can pass in your own `io` to replace the global one.
  # But we still grab access to the global one if it's available here:
  
  ###*
  Augment the `io` object passed in with methods for talking and listening
  to one or more Sails backend(s).  Automatically connects a socket and
  exposes it on `io.socket`.  If a socket tries to make requests before it
  is connected, the sails.io.js client will queue it up.
  
  @param {SocketIO} io
  ###
  SailsIOClient = (io) ->
    
    # Prefer the passed-in `io` instance, but also use the global one if we've got it.
    
    # If the socket.io client is not available, none of this will work.
    
    #////////////////////////////////////////////////////////////
    #///                              ///////////////////////////
    #/// PRIVATE METHODS/CONSTRUCTORS ///////////////////////////
    #///                              ///////////////////////////
    #////////////////////////////////////////////////////////////
    
    ###*
    A little logger for this library to use internally.
    Basically just a wrapper around `console.log` with
    support for feature-detection.
    
    @api private
    @factory
    ###
    LoggerFactory = (options) ->
      options = options or prefix: true
      
      # If `console.log` is not accessible, `log` is a noop.
      return noop = ->  if typeof console isnt "object" or typeof console.log isnt "function" or typeof console.log.bind isnt "function"
      log = ->
        args = Array::slice.call(arguments)
        
        # All logs are disabled when `io.sails.environment = 'production'`.
        return  if io.sails.environment is "production"
        
        # Add prefix to log messages (unless disabled)
        PREFIX = ""
        args.unshift PREFIX  if options.prefix
        
        # Call wrapped logger
        console.log.bind(console).apply this, args
        return
    
    # Create a private logger instance
    
    ###*
    What is the `requestQueue`?
    
    The request queue is used to simplify app-level connection logic--
    i.e. so you don't have to wait for the socket to be connected
    to start trying to  synchronize data.
    
    @api private
    @param  {SailsSocket}  socket
    ###
    runRequestQueue = (socket) ->
      queue = socket.requestQueue
      return  unless queue
      for i of queue
        
        # Double-check that `queue[i]` will not
        # inadvertently discover extra properties attached to the Object
        # and/or Array prototype by other libraries/frameworks/tools.
        # (e.g. Ember does this. See https://github.com/balderdashy/sails.io.js/pull/5)
        isSafeToDereference = ({}).hasOwnProperty.call(queue, i)
        
        # Emit the request.
        _emitFrom socket, queue[i]  if isSafeToDereference
      
      # Now empty the queue to remove it as a source of additional complexity.
      queue = null
      return
    
    ###*
    Send a JSONP request.
    
    @param  {Object}   opts [optional]
    @param  {Function} cb
    @return {XMLHttpRequest}
    ###
    jsonp = (opts, cb) ->
      opts = opts or {}
      
      # TODO: refactor node usage to live in here
      return cb()  if typeof window is "undefined"
      scriptEl = document.createElement("script")
      window._sailsIoJSConnect = (response) ->
        scriptEl.parentNode.removeChild scriptEl
        cb response
        return

      scriptEl.src = opts.url
      document.getElementsByTagName("head")[0].appendChild scriptEl
      return
    
    ###*
    The JWR (JSON WebSocket Response) received from a Sails server.
    
    @api public
    @param  {Object}  responseCtx
    => :body
    => :statusCode
    => :headers
    
    @constructor
    ###
    JWR = (responseCtx) ->
      @body = responseCtx.body or {}
      @headers = responseCtx.headers or {}
      @statusCode = responseCtx.statusCode or 200
      @error = @body or @statusCode  if @statusCode < 200 or @statusCode >= 400
      return
    
    # TODO: look at substack's stuff
    
    ###*
    @api private
    @param  {SailsSocket} socket  [description]
    @param  {Object} requestCtx [description]
    ###
    _emitFrom = (socket, requestCtx) ->
      throw new Error("Failed to emit from socket- raw SIO socket is missing.")  unless socket._raw
      
      # Since callback is embedded in requestCtx,
      # retrieve it and delete the key before continuing.
      cb = requestCtx.cb
      delete requestCtx.cb

      
      # Name of the appropriate socket.io listener on the server
      # ( === the request method or "verb", e.g. 'get', 'post', 'put', etc. )
      sailsEndpoint = requestCtx.method
      socket._raw.emit sailsEndpoint, requestCtx, serverResponded = (responseCtx) ->
        
        # Send back (emulatedHTTPBody, jsonWebSocketResponse)
        cb responseCtx.body, new JWR(responseCtx)  if cb
        return

      return
    
    #////////////////////////////////////////////////////////////
    #/// </PRIVATE METHODS/CONSTRUCTORS> ////////////////////////
    #////////////////////////////////////////////////////////////
    
    # Version note:
    # 
    # `io.SocketNamespace.prototype` doesn't exist in sio 1.0.
    # 
    # Rather than adding methods to the prototype for the Socket instance that is returned
    # when the browser connects with `io.connect()`, we create our own constructor, `SailsSocket`.
    # This makes our solution more future-proof and helps us work better w/ the Socket.io team
    # when changes are rolled out in the future.  To get a `SailsSocket`, you can run:
    # ```
    # io.sails.connect();
    # ```
    
    ###*
    SailsSocket
    
    A wrapper for an underlying Socket instance that communicates directly
    to the Socket.io server running inside of Sails.
    
    If no `socket` option is provied, SailsSocket will function as a mock. It will queue socket
    requests and event handler bindings, replaying them when the raw underlying socket actually
    connects. This is handy when we don't necessarily have the valid configuration to know
    WHICH SERVER to talk to yet, etc.  It is also used by `io.socket` for your convenience.
    
    @constructor
    ###
    SailsSocket = (opts) ->
      self = this
      opts = opts or {}
      
      # Absorb opts
      self.useCORSRouteToGetCookie = opts.useCORSRouteToGetCookie
      self.url = opts.url
      self.multiplex = opts.multiplex
      
      # Set up "eventQueue" to hold event handlers which have not been set on the actual raw socket yet.
      self.eventQueue = {}
      
      # Listen for special `parseError` event sent from sockets hook on the backend
      # if an error occurs but a valid callback was not received from the client
      # (i.e. so the server had no other way to send back the error information)
      self.on "sails:parseError", (err) ->
        consolog "Sails encountered an error parsing a socket message sent from this client, and did not have access to a callback function to respond with."
        consolog "Error details:", err
        return

      return
    io = _io  unless io
    throw new Error("`sails.io.js` requires a socket.io client, but `io` was not passed in.")  unless io
    consolog = LoggerFactory()
    consolog.noPrefix = LoggerFactory(prefix: false)
    JWR::toString = ->
      "[ResponseFromSails]" + "  -- " + "Status: " + @statusCode + "  -- " + "Headers: " + @headers + "  -- " + "Body: " + @body

    JWR::toPOJO = ->
      body: @body
      headers: @headers
      statusCode: @statusCode

    JWR::pipe = ->
      new Error("Client-side streaming support not implemented yet.")

    
    # TODO:
    # Listen for a special private message on any connected that allows the server
    # to set the environment (giving us 100% certainty that we guessed right)
    # However, note that the `console.log`s called before and after connection
    # are still forced to rely on our existing heuristics (to disable, tack #production
    # onto the URL used to fetch this file.)
    
    ###*
    Start connecting this socket.
    
    @api private
    ###
    SailsSocket::_connect = ->
      self = this
      
      # Apply `io.sails` config as defaults
      # (now that at least one tick has elapsed)
      self.useCORSRouteToGetCookie = self.useCORSRouteToGetCookie or io.sails.useCORSRouteToGetCookie
      self.url = self.url or io.sails.url
      
      # Ensure URL has no trailing slash
      self.url = (if self.url then self.url.replace(/(\/)$/, "") else `undefined`)
      
      # Mix the current SDK version into the query string in
      # the connection request to the server:
      if typeof self.query isnt "string"
        self.query = SDK_INFO.versionString
      else
        self.query += "&" + SDK_INFO.versionString
      
      # Determine whether this is a cross-origin socket by examining the
      # hostname and port on the `window.location` object.
      isXOrigin = (->
        
        # If `window` doesn't exist (i.e. being used from node.js), then it's
        # always "cross-domain".
        return false  if typeof window is "undefined" or typeof window.location is "undefined"
        
        # If `self.url` (aka "target") is falsy, then we don't need to worry about it.
        return false  if typeof self.url isnt "string"
        
        # Get information about the "target" (`self.url`)
        targetProtocol = (->
          try
            targetProtocol = self.url.match(/^([a-z]+:\/\/)/i)[1].toLowerCase()
          targetProtocol = targetProtocol or "http://"
          targetProtocol
        )()
        isTargetSSL = !!self.url.match("^https")
        targetPort = (->
          try
            return self.url.match(/^[a-z]+:\/\/[^:]*:([0-9]*)/i)[1]
          (if isTargetSSL then "443" else "80")
        )()
        targetAfterProtocol = self.url.replace(/^([a-z]+:\/\/)/i, "")
        
        # If target protocol is different than the actual protocol,
        # then we'll consider this cross-origin.
        return true  if targetProtocol.replace(/[:\/]/g, "") isnt window.location.protocol.replace(/[:\/]/g, "")
        
        # If target hostname is different than actual hostname, we'll consider this cross-origin.
        hasSameHostname = targetAfterProtocol.search(window.location.hostname) isnt 0
        return true  unless hasSameHostname
        
        # If no actual port is explicitly set on the `window.location` object,
        # we'll assume either 80 or 443.
        isLocationSSL = window.location.protocol.match(/https/i)
        locationPort = (window.location.port + "") or ((if isLocationSSL then "443" else "80"))
        
        # Finally, if ports don't match, we'll consider this cross-origin.
        return true  if targetPort isnt locationPort
        
        # Otherwise, it's the same origin.
        false
      )()
      
      # Prepare to start connecting the socket
      (selfInvoking = (cb) ->
        
        # If this is an attempt at a cross-origin or cross-port
        # socket connection, send a JSONP request first to ensure
        # that a valid cookie is available.  This can be disabled
        # by setting `io.sails.useCORSRouteToGetCookie` to false.
        # 
        # Otherwise, skip the stuff below.
        return cb()  unless self.useCORSRouteToGetCookie and isXOrigin
        
        # Figure out the x-origin CORS route
        # (Sails provides a default)
        xOriginCookieURL = self.url
        if typeof self.useCORSRouteToGetCookie is "string"
          xOriginCookieURL += self.useCORSRouteToGetCookie
        else
          xOriginCookieURL += "/__getcookie"
        
        # Make the AJAX request (CORS)
        if typeof window isnt "undefined"
          jsonp
            url: xOriginCookieURL
            method: "GET"
          , cb
          return
        
        # If there's no `window` object, we must be running in Node.js
        # so just require the request module and send the HTTP request that
        # way.
        mikealsReq = require("request")
        mikealsReq.get xOriginCookieURL, (err, httpResponse, body) ->
          if err
            consolog "Failed to connect socket (failed to get cookie)", "Error:", err
            return
          cb()
          return

        return
      ) goAheadAndActuallyConnect = ->
        
        # Now that we're ready to connect, create a raw underlying Socket
        # using Socket.io and save it as `_raw` (this will start it connecting)
        self._raw = io(self.url, self)
        
        # Replay event bindings from the eager socket
        self.replay()
        
        ###*
        'connect' event is triggered when the socket establishes a connection
        successfully.
        ###
        self.on "connect", socketConnected = ->
          
          # '    |>    ' + '\n' +
          # '  \\___/  '+️
          # '\n'+
          
          # '\n'+
          consolog.noPrefix "\n" + "\n" + "  |>    Now connected to Sails." + "\n" + "\\___/   For help, see: http://bit.ly/1DmTvgK" + "\n" + "        (using " + io.sails.sdk.platform + " SDK @v" + io.sails.sdk.version + ")" + "\n" + "\n" + "\n" + ""
          return

        
        # ' ⚓︎ (development mode)'
        # 'e.g. to send a GET request to Sails via WebSockets, run:'+ '\n' +
        # '`io.socket.get("/foo", function serverRespondedWith (body, jwr) { console.log(body); })`'+ '\n' +
        self.on "disconnect", ->
          self.connectionLostTimestamp = (new Date()).getTime()
          consolog "===================================="
          consolog "Socket was disconnected from Sails."
          consolog "Usually, this is due to one of the following reasons:" + "\n" + " -> the server " + ((if self.url then self.url + " " else "")) + "was taken down" + "\n" + " -> your browser lost internet connectivity"
          consolog "===================================="
          return

        self.on "reconnecting", (numAttempts) ->
          consolog "\n" + "        Socket is trying to reconnect to Sails...\n" + "_-|>_-  (attempt #" + numAttempts + ")" + "\n" + "\n"
          return

        self.on "reconnect", (transport, numAttempts) ->
          msSinceConnectionLost = ((new Date()).getTime() - self.connectionLostTimestamp)
          numSecsOffline = (msSinceConnectionLost / 1000)
          consolog "\n" + "  |>    Socket reconnected successfully after" + "\n" + "\\___/   being offline for ~" + numSecsOffline + " seconds." + "\n" + "\n"
          return

        
        # 'error' event is triggered if connection can not be established.
        # (usually because of a failed authorization, which is in turn
        # usually due to a missing or invalid cookie)
        self.on "error", failedToConnect = (err) ->
          
          # TODO:
          # handle failed connections due to failed authorization
          # in a smarter way (probably can listen for a different event)
          
          # A bug in Socket.io 0.9.x causes `connect_failed`
          # and `reconnect_failed` not to fire.
          # Check out the discussion in github issues for details:
          # https://github.com/LearnBoost/socket.io/issues/652
          # io.socket.on('connect_failed', function () {
          #  consolog('io.socket emitted `connect_failed`');
          # });
          # io.socket.on('reconnect_failed', function () {
          #  consolog('io.socket emitted `reconnect_failed`');
          # });
          consolog "Failed to connect socket (probably due to failed authorization on server)", "Error:", err
          return

        return

      return

    
    ###*
    Disconnect the underlying socket.
    
    @api public
    ###
    SailsSocket::disconnect = ->
      throw new Error("Cannot disconnect- socket is already disconnected")  unless @_raw
      @_raw.disconnect()

    
    ###*
    isConnected
    
    @api private
    @return {Boolean} whether the socket is connected and able to
    communicate w/ the server.
    ###
    SailsSocket::isConnected = ->
      return false  unless @_raw
      !!@_raw.connected

    
    ###*
    [replay description]
    @return {[type]} [description]
    ###
    SailsSocket::replay = ->
      self = this
      
      # Pass events and a reference to the request queue
      # off to the self._raw for consumption
      for evName of self.eventQueue
        for i of self.eventQueue[evName]
          self._raw.on evName, self.eventQueue[evName][i]
      
      # Bind a one-time function to run the request queue
      # when the self._raw connects.
      unless self.isConnected()
        alreadyRanRequestQueue = false
        self._raw.on "connect", whenRawSocketConnects = ->
          return  if alreadyRanRequestQueue
          runRequestQueue self
          alreadyRanRequestQueue = true
          return

      
      # Or run it immediately if self._raw is already connected
      else
        runRequestQueue self
      self

    
    ###*
    Chainable method to bind an event to the socket.
    
    @param  {String}   evName [event name]
    @param  {Function} fn     [event handler function]
    @return {SailsSocket}
    ###
    SailsSocket::on = (evName, fn) ->
      
      # Bind the event to the raw underlying socket if possible.
      if @_raw
        @_raw.on evName, fn
        return this
      
      # Otherwise queue the event binding.
      unless @eventQueue[evName]
        @eventQueue[evName] = [fn]
      else
        @eventQueue[evName].push fn
      this

    
    ###*
    Chainable method to unbind an event from the socket.
    
    @param  {String}   evName [event name]
    @param  {Function} fn     [event handler function]
    @return {SailsSocket}
    ###
    SailsSocket::off = (evName, fn) ->
      
      # Bind the event to the raw underlying socket if possible.
      if @_raw
        @_raw.off evName, fn
        return this
      
      # Otherwise queue the event binding.
      @eventQueue[evName].splice @eventQueue[evName].indexOf(fn), 1  if @eventQueue[evName] and @eventQueue[evName].indexOf(fn) > -1
      this

    
    ###*
    Chainable method to unbind all events from the socket.
    
    @return {SailsSocket}
    ###
    SailsSocket::removeAllListeners = ->
      
      # Bind the event to the raw underlying socket if possible.
      if @_raw
        @_raw.removeAllListeners()
        return this
      
      # Otherwise queue the event binding.
      @eventQueue = {}
      this

    
    ###*
    Simulate a GET request to sails
    e.g.
    `socket.get('/user/3', Stats.populate)`
    
    @api public
    @param {String} url    ::    destination URL
    @param {Object} params ::    parameters to send with the request [optional]
    @param {Function} cb   ::    callback function to call when finished [optional]
    ###
    SailsSocket::get = (url, data, cb) ->
      
      # `data` is optional
      if typeof data is "function"
        cb = data
        data = {}
      @request
        method: "get"
        params: data
        url: url
      , cb

    
    ###*
    Simulate a POST request to sails
    e.g.
    `socket.post('/event', newMeeting, $spinner.hide)`
    
    @api public
    @param {String} url    ::    destination URL
    @param {Object} params ::    parameters to send with the request [optional]
    @param {Function} cb   ::    callback function to call when finished [optional]
    ###
    SailsSocket::post = (url, data, cb) ->
      
      # `data` is optional
      if typeof data is "function"
        cb = data
        data = {}
      @request
        method: "post"
        data: data
        url: url
      , cb

    
    ###*
    Simulate a PUT request to sails
    e.g.
    `socket.post('/event/3', changedFields, $spinner.hide)`
    
    @api public
    @param {String} url    ::    destination URL
    @param {Object} params ::    parameters to send with the request [optional]
    @param {Function} cb   ::    callback function to call when finished [optional]
    ###
    SailsSocket::put = (url, data, cb) ->
      
      # `data` is optional
      if typeof data is "function"
        cb = data
        data = {}
      @request
        method: "put"
        params: data
        url: url
      , cb

    
    ###*
    Simulate a DELETE request to sails
    e.g.
    `socket.delete('/event', $spinner.hide)`
    
    @api public
    @param {String} url    ::    destination URL
    @param {Object} params ::    parameters to send with the request [optional]
    @param {Function} cb   ::    callback function to call when finished [optional]
    ###
    SailsSocket::["delete"] = (url, data, cb) ->
      
      # `data` is optional
      if typeof data is "function"
        cb = data
        data = {}
      @request
        method: "delete"
        params: data
        url: url
      , cb

    
    ###*
    Simulate an HTTP request to sails
    e.g.
    ```
    socket.request({
    url:'/user',
    params: {},
    method: 'POST',
    headers: {}
    }, function (responseBody, JWR) {
    // ...
    });
    ```
    
    @api public
    @option {String} url    ::    destination URL
    @option {Object} params ::    parameters to send with the request [optional]
    @option {Object} headers::    headers to send with the request [optional]
    @option {Function} cb   ::    callback function to call when finished [optional]
    @option {String} method ::    HTTP request method [optional]
    ###
    SailsSocket::request = (options, cb) ->
      usage = "Usage:\n" + "socket.request( options, [fnToCallWhenComplete] )\n\n" + "options.url :: e.g. \"/foo/bar\"" + "\n" + "options.method :: e.g. \"get\", \"post\", \"put\", or \"delete\", etc." + "\n" + "options.params :: e.g. { emailAddress: \"mike@sailsjs.org\" }" + "\n" + "options.headers :: e.g. { \"x-my-custom-header\": \"some string\" }"
      
      # Old usage:
      # var usage = 'Usage:\n socket.'+(options.method||'request')+'('+
      #   ' destinationURL, [dataToSend], [fnToCallWhenComplete] )';
      
      # Validate options and callback
      throw new Error("Invalid or missing URL!\n" + usage)  if typeof options isnt "object" or typeof options.url isnt "string"
      throw new Error("Invalid `method` provided (should be a string like \"post\" or \"put\")\n" + usage)  if options.method and typeof options.method isnt "string"
      throw new Error("Invalid `headers` provided (should be an object with string values)\n" + usage)  if options.headers and typeof options.headers isnt "object"
      throw new Error("Invalid `params` provided (should be an object with string values)\n" + usage)  if options.params and typeof options.params isnt "object"
      throw new Error("Invalid callback function!\n" + usage)  if cb and typeof cb isnt "function"
      
      # Build a simulated request object
      # (and sanitize/marshal options along the way)
      requestCtx =
        method: options.method.toLowerCase() or "get"
        headers: options.headers or {}
        data: options.params or options.data or {}
        
        # Remove trailing slashes and spaces to make packets smaller.
        url: options.url.replace(/^(.+)\/*\s*$/, "$1")
        cb: cb

      
      # If this socket is not connected yet, queue up this request
      # instead of sending it.
      # (so it can be replayed when the socket comes online.)
      unless @isConnected()
        
        # If no queue array exists for this socket yet, create it.
        @requestQueue = @requestQueue or []
        @requestQueue.push requestCtx
        return
      
      # Otherwise, our socket is ok!
      # Send the request.
      _emitFrom this, requestCtx
      return

    
    ###*
    Socket.prototype._request
    
    Simulate HTTP over Socket.io.
    
    @api private
    @param  {[type]}   options [description]
    @param  {Function} cb      [description]
    ###
    SailsSocket::_request = (options, cb) ->
      throw new Error("`_request()` was a private API deprecated as of v0.11 of the sails.io.js client. Use `.request()` instead.")return

    
    # Set a `sails` object that may be used for configuration before the
    # first socket connects (i.e. to prevent auto-connect)
    io.sails =
      
      # Whether to automatically connect a socket and save it as `io.socket`.
      autoConnect: true
      
      # The route (path) to hit to get a x-origin (CORS) cookie
      # (or true to use the default: '/__getcookie')
      useCORSRouteToGetCookie: true
      
      # The environment we're running in.
      # (logs are not displayed when this is set to 'production')
      # 
      # Defaults to development unless this script was fetched from a URL
      # that ends in `*.min.js` or '#production' (may also be manually overridden.)
      # 
      environment: (if urlThisScriptWasFetchedFrom.match(/(\#production|\.min\.js)/g) then "production" else "development")
      
      # The version of this sails.io.js client SDK
      sdk: SDK_INFO

    
    ###*
    Add `io.sails.connect` function as a wrapper for the built-in `io()` aka `io.connect()`
    method, returning a SailsSocket. This special function respects the configured io.sails
    connection URL, as well as sending other identifying information (most importantly, the
    current version of this SDK).
    
    @param  {String} url  [optional]
    @param  {Object} opts [optional]
    @return {Socket}
    ###
    io.sails.connect = (url, opts) ->
      opts = opts or {}
      
      # If explicit connection url is specified, save it to options
      opts.url = url or opts.url or `undefined`
      
      # Instantiate and return a new SailsSocket- and try to connect immediately.
      socket = new SailsSocket(opts)
      socket._connect()
      socket

    
    # io.socket
    # 
    # The eager instance of Socket which will automatically try to connect
    # using the host that this js file was served from.
    # 
    # This can be disabled or configured by setting properties on `io.sails.*` within the
    # first cycle of the event loop.
    # 
    
    # Build `io.socket` so it exists
    # (this does not start the connection process)
    io.socket = new SailsSocket()
    
    # In the mean time, this eager socket will be queue events bound by the user
    # before the first cycle of the event loop (using `.on()`), which will later
    # be rebound on the raw underlying socket.
    
    # If configured to do so, start auto-connecting after the first cycle of the event loop
    # has completed (to allow time for this behavior to be configured/disabled
    # by specifying properties on `io.sails`)
    setTimeout (->
      
      # If autoConnect is disabled, delete the eager socket (io.socket) and bail out.
      unless io.sails.autoConnect
        delete io.socket

        return
      
      # consolog('Eagerly auto-connecting socket to Sails... (requests will be queued in the mean-time)');
      io.socket._connect()
      return
    ), 0 # </setTimeout>
    
    # Return the `io` object.
    io
  urlThisScriptWasFetchedFrom = (->
    return ""  if typeof window isnt "object" or typeof window.document isnt "object" or typeof window.document.getElementsByTagName isnt "function"
    allScriptsCurrentlyInDOM = window.document.getElementsByTagName("script")
    thisScript = allScriptsCurrentlyInDOM[allScriptsCurrentlyInDOM.length - 1]
    thisScript.src
  )()
  CONNECTION_METADATA_PARAMS =
    version: "__sails_io_sdk_version"
    platform: "__sails_io_sdk_platform"
    language: "__sails_io_sdk_language"

  SDK_INFO =
    version: "0.11.0"
    platform: (if typeof module is "undefined" then "browser" else "node")
    language: "javascript"

  SDK_INFO.versionString = CONNECTION_METADATA_PARAMS.version + "=" + SDK_INFO.version + "&" + CONNECTION_METADATA_PARAMS.platform + "=" + SDK_INFO.platform + "&" + CONNECTION_METADATA_PARAMS.language + "=" + SDK_INFO.language
  _io = (if (typeof io isnt "undefined") then io else null)
  
  # Add CommonJS support to allow this client SDK to be used from Node.js.
  if typeof module is "object" and typeof module.exports isnt "undefined"
    module.exports = SailsIOClient
    return SailsIOClient
  
  # Otherwise, try to instantiate the client:
  # In case you're wrapping the socket.io client to prevent pollution of the
  # global namespace, you can replace the global `io` with your own `io` here:
  SailsIOClient()
)()
