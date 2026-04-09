local _ENV = (getgenv or getrenv or getfenv)()

export type ConnectionObject = {
    Connected: boolean,
    Signal: SignalObject,
    Function: ((...any) -> any)?,
    Disconnect: (self: ConnectionObject) -> (),
    Fire: (self: ConnectionObject, ...any) -> (),
}

export type SignalObject = {
    _connections: { ConnectionObject },
    Connect: (self: SignalObject, fn: (...any) -> any) -> ConnectionObject,
    Fire: (self: SignalObject, ...any) -> (),
}

export type ConnectionsObject = {
    Connect: (Instance: RBXScriptSignal, Callback: (...any) -> any) -> RBXScriptConnection,
}

export type QueueEntry = {
    Name: string,
    Function: () -> any,
}

export type SequencerObject = {
    Options: { QueueEntry },
    OptionMap: { [string]: number },
    THREAD_HASH: string,
    Guard: SignalObject,
    NewQueue: (self: SequencerObject, Flag: string, Function: () -> any) -> QueueEntry,
    CallQueue: (self: SequencerObject, Flag: string) -> any,
    GetQueue: (self: SequencerObject, Flag: string) -> QueueEntry,
    IsQueueRunning: (self: SequencerObject) -> boolean,
    Operational: (self: SequencerObject) -> thread,
    OnErrorCatching: (self: SequencerObject, fn: (err: string) -> any) -> ConnectionObject,
    Connect: (self: SequencerObject, Instance: RBXScriptSignal, Callback: (...any) -> any) -> RBXScriptConnection,
}

local Sequencer = {} do
    Sequencer.__index = Sequencer

    Sequencer.hmac = (function()
        local hmac = {}

        local HEX = "0123456789abcdef"

        local function random_hex(n: number): string
            local t = {}

            for i = 1, n do
                local idx = math.random(1, 16)
                t[i] = HEX:sub(idx, idx)
            end

            return table.concat(t)
        end

        local DIGEST_LEN: { [string]: number } = {
            md5 = 32,
            sha1 = 40,
            sha256 = 64,
            sha384 = 96,
            sha512 = 128,
        }

        function hmac.new(algo: string?): string
            local len = DIGEST_LEN[(algo or "sha256"):lower()]
            assert(len, "unknown algo: " .. tostring(algo))
            return random_hex(len)
        end

        return setmetatable(hmac, {
            __call = function(_, _input: any, algo: string?): string
                return hmac.new(algo)
            end
        })
    end)()

    Sequencer.Connections = (function()
        local Connections: ConnectionsObject = {} :: ConnectionsObject
        local Cached: { RBXScriptConnection } = _ENV.Connections or {}

        do
            _ENV.Connections = Cached

            for i = 1, #Cached do
                Cached[i]:Disconnect()
            end

            table.clear(Cached)
        end

        function Connections.Connect(Instance: RBXScriptSignal, Callback: (...any) -> any): RBXScriptConnection
            local Connection = Instance:Connect(Callback)

            table.insert(Cached, Connection)

            return Connection
        end

        return Connections
    end)()

    Sequencer.Signal = (function()
        local Signal = {}
        local Connection = {}

        Connection.__index = Connection
        Signal.__index = Signal

        function Connection:Disconnect(self: ConnectionObject)
            if not self.Connected then
                return
            end

            local find = table.find(self.Signal._connections, self)

            if find then
                table.remove(self.Signal._connections, find)
            end

            self.Function = nil
            self.Connected = false
        end

        function Connection:Fire(self: ConnectionObject, ...: any)
            if self.Function then
                task.spawn(self.Function, ...)
            end
        end

        function Signal.new(): SignalObject
            return setmetatable({
                _connections = {}
            }, Signal) :: any
        end

        function Signal:Connect(self: SignalObject, fn: (...any) -> any): ConnectionObject
            local connection = setmetatable({
                Signal = self,
                Function = fn,
                Connected = true
            }, Connection) :: any

            table.insert(self._connections, connection)
            return connection
        end

        function Signal:Fire(self: SignalObject, ...: any)
            for _, connection in ipairs(self._connections) do
                connection:Fire(...)
            end
        end

        return Signal
    end)()
end

function Sequencer.new(Protect: any?): SequencerObject
    local self = setmetatable({}, {
        __index = Sequencer
    }) :: any

    self.Options = {} :: { QueueEntry }
    self.OptionMap = {} :: { [string]: number }

    local HMAC_HASH: string = Sequencer.hmac('Sequencer') do
        self.THREAD_HASH = HMAC_HASH
        _ENV.__THREAD_HASH = HMAC_HASH
    end

    local Guard: SignalObject = Sequencer.Signal.new() do
        self.Guard = Guard
    end

    return self
end

function Sequencer:NewQueue(Flag: string, Function: () -> any): QueueEntry
    table.insert(self.Options, {
        ["Name"] = Flag,
        ["Function"] = Function
    })

    self.OptionMap[Flag] = #self.Options

    return self.Options[self.OptionMap[Flag]]
end

function Sequencer:CallQueue(Flag: string): any
    local idx: number = self.OptionMap[Flag]

    if not idx or not self.Options[idx] then
        return warn("Function is not valid: ", Flag)
    end

    return self.Options[idx].Function()
end

function Sequencer:GetQueue(Flag: string): QueueEntry
    local idx: number = self.OptionMap[Flag]

    if not idx or not self.Options[idx] then
        return warn("Function is not valid: ", Flag)
    end

    return self.Options[idx]
end

function Sequencer:IsQueueRunning(): boolean
    return _ENV.OnFarm
end

function Sequencer:Operational(): thread
    return task.spawn(function()
        local THREAD_HASH: string = self.THREAD_HASH

        local Success: boolean, ErrorMessage: string = pcall(function()
            local function GetQueue(): any
                for _, Option: QueueEntry in self.Options do
                    local Method = Option.Function()
                    if Method then
                        return Method
                    end
                end
            end

            while task.wait(0) do
                if _ENV.__THREAD_HASH ~= THREAD_HASH then break end
                _ENV.OnFarm = if GetQueue() then true else false
            end
        end)

        if not Success then
            self.Guard:Fire(ErrorMessage)
            warn(ErrorMessage)
        end
    end)
end

function Sequencer:OnErrorCatching(fn: (err: string) -> any): ConnectionObject
    if not self.Guard then
        self.Guard = Sequencer.Signal.new()
    end

    return self.Guard:Connect(fn)
end

function Sequencer:Connect(Instance: RBXScriptSignal, Callback: (...any) -> any): RBXScriptConnection
    return Sequencer.Connections.Connect(Instance, Callback)
end

return Sequencer
