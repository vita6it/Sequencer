# 📦 Sequencer Queue System

A lightweight queue system for running prioritized tasks in order.
Each queue executes from top to bottom and stops when a task returns `true`.

---

## 🚀 Getting Started

```lua
local Sequencer = loadstring(game:HttpGet("https://github.com/vita6it/Sequencer/releases/latest/download/main.lua"))()
local Queues = Sequencer.new()
```

---

## ⚙️ How It Works

* Queues run **from top to bottom**
* If a queue function returns `true`, the system will:

  * Stop in that queue
  * Restart from the first queue
* If it returns `false` or nothing:

  * Continue to the next queue

---

## 🧩 Example Usage

```lua
Queues:NewQueue("Auto Collect Fruit", function()
    if FruitSpawn then
        print("Collect Fruit")
        return true -- stop here
    end
    
    return false
end)

Queues:NewQueue("Auto Farm Level", function()
    print("Im Farm Level")
    return true
end)
```

---

## ▶️ Running the System

```lua
print(Sequencer:IsQueueRunning()) -- check if running

Sequencer:Operational() -- start loop
```

---

## ⚠️ Error Handling

```lua
Sequencer:OnErrorCatching(function(err)
    print("Error:", err)
    
    -- restart system
    Sequencer:Operational()
end)
```

---

## 📌 Notes

* Always return `true` when you want to prioritize and stop other queues
* Use `false` to continue checking other tasks
* Ideal for automation systems (farm, collect, combat, etc.)

---
