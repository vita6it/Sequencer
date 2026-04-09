# Sequencer
A lightweight task queue manager for Roblox exploit environments. Handles re-execution safety, connection management, and error catching via a custom signal system.

---

## Installation

Drop `Sequencer.lua` into your project and require it.

```lua
local Sequencer = loadstring(...)()
```

---

## Quick Start

```lua
local seq = Sequencer.new()

seq:NewQueue("IsAlive", function()
    local char = game.Players.LocalPlayer.Character
    return char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
end)

seq:OnErrorCatching(function(err)
    print("Error:", err)
end)

seq:Operational()
```

---

## API

### `Sequencer.new(Protect?)`
Creates a new Sequencer instance. Invalidates any previously running loop from an older instance via `__THREAD_HASH`.

```lua
local seq = Sequencer.new()
```

| Parameter | Type | Description |
|---|---|---|
| `Protect` | `any?` | Reserved, currently unused |

**Returns:** `SequencerObject`

---

### `:NewQueue(Flag, Function)`
Registers a named function into the queue.

```lua
seq:NewQueue("CheckTarget", function()
    return workspace:FindFirstChild("Target") ~= nil
end)
```

| Parameter | Type | Description |
|---|---|---|
| `Flag` | `string` | Unique name for this queue entry |
| `Function` | `() -> any` | Function to run each tick. Truthy return = active |

**Returns:** `QueueEntry`

---

### `:CallQueue(Flag)`
Calls a registered queue function by name and returns its result.

```lua
local result = seq:CallQueue("CheckTarget")
```

| Parameter | Type | Description |
|---|---|---|
| `Flag` | `string` | Name of the queue entry to call |

**Returns:** `any`

---

### `:GetQueue(Flag)`
Returns the raw queue entry object without calling it.

```lua
local entry = seq:GetQueue("CheckTarget")
print(entry.Name, entry.Function)
```

| Parameter | Type | Description |
|---|---|---|
| `Flag` | `string` | Name of the queue entry to retrieve |

**Returns:** `QueueEntry`

---

### `:Operational()`
Starts the main loop in a new thread. Each tick, iterates all queued functions and sets `OnFarm` accordingly. Loop exits automatically when a new `Sequencer.new()` is called.

```lua
seq:Operational()
```

**Returns:** `thread`

---

### `:OnErrorCatching(fn)`
Registers a callback that fires if the main loop encounters a runtime error. Must be called before `:Operational()`.

```lua
seq:OnErrorCatching(function(err)
    print("Caught:", err)
end)
```

| Parameter | Type | Description |
|---|---|---|
| `fn` | `(err: string) -> any` | Callback receiving the error message |

**Returns:** `ConnectionObject`

---

### `:IsQueueRunning()`
Returns whether any queue function returned truthy on the last tick.

```lua
if seq:IsQueueRunning() then
    print("Currently farming")
end
```

**Returns:** `boolean`

---

### `:Connect(Instance, Callback)`
Managed wrapper around `:Connect()`. All connections registered here are automatically disconnected on re-execution.

```lua
seq:Connect(RunService.Heartbeat, function(dt)
    print("tick:", dt)
end)
```

| Parameter | Type | Description |
|---|---|---|
| `Instance` | `RBXScriptSignal` | The signal to connect to |
| `Callback` | `(...any) -> any` | Handler function |

**Returns:** `RBXScriptConnection`

---

## Types

```lua
export type QueueEntry = {
    Name: string,
    Function: () -> any,
}

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
```

---

## Re-execution Safety

Every `Sequencer.new()` generates a unique `THREAD_HASH` written to `_ENV.__THREAD_HASH`. The running loop checks this value every tick — if it no longer matches, the loop exits cleanly. This means re-running the script will never stack duplicate loops.

All managed connections are stored in `_ENV.Connections` and disconnected automatically on the next execution.

---

## Notes

- `:Operational()` is non-blocking — it runs inside `task.spawn` internally
- `:OnErrorCatching()` should always be registered before `:Operational()`
- `Sequencer.hmac` is not a real cryptographic implementation — it is used purely as a session token generator
