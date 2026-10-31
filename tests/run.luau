local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Rules = require("../src/Rules")
local Transaction = require("../src/Transaction")
local count = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    count += 1
    print("PASS " .. name)
end
local function rejects(callback)
    assert(not pcall(callback), "expected an error")
end
for _, name in ipairs(fs.readDir("src")) do
    if name:match("%.luau$") then luau.compile(fs.readFile("src/" .. name)) end
end

test("transaction commits one batch", function()
    local writes, commits = 0, 0
    local ok = Transaction.apply({ {}, {} }, {
        validate = function() return true end,
        write = function() writes += 1 end,
    }, {
        begin = function() return "recording" end,
        finish = function(id, commit) assert(id == "recording" and commit) commits += 1 end,
    })
    assert(ok and writes == 2 and commits == 1)
end)
test("empty, stale and uncheckable plans never begin a recording", function()
    local function forbidden() error("must not be called") end
    for _, mode in ipairs({ "empty", "stale", "throw" }) do
        local began = false
        local ok = Transaction.apply(if mode == "empty" then {} else { {} }, {
            validate = function() if mode == "throw" then error("deleted") end return false, "stale" end,
            write = forbidden,
        }, { begin = function() began = true return "id" end, finish = forbidden })
        assert(not ok and not began)
    end
end)
test("refused or failing undo recordings do not edit objects", function()
    for _, mode in ipairs({ "refuse", "throw" }) do
        local writes = 0
        local ok = Transaction.apply({ {} }, { validate = function() return true end, write = function() writes += 1 end }, {
            begin = function() if mode == "throw" then error("busy") end return nil end,
            finish = function() error("must not finish") end,
        })
        assert(not ok and writes == 0)
    end
end)
test("write failures cancel and restore the fake scene", function()
    local state, snapshot, cancelled = 0, 0, false
    local ok = Transaction.apply({ {}, {} }, {
        validate = function() return true end,
        write = function() state += 1 if state == 2 then error("locked") end end,
    }, {
        begin = function() snapshot = state return "id" end,
        finish = function(_, commit) assert(not commit) state = snapshot cancelled = true end,
    })
    assert(not ok and cancelled and state == 0)
end)
test("failed commits attempt cancellation", function()
    local cancelled = false
    local ok = Transaction.apply({ {} }, { validate = function() return true end, write = function() end }, {
        begin = function() return "id" end,
        finish = function(_, commit) if commit then error("commit failed") end cancelled = true end,
    })
    assert(not ok and cancelled)
end)
test("failed cancellation is reported", function()
    local ok, message = Transaction.apply({ {} }, { validate = function() return true end, write = function() error("write failed") end }, {
        begin = function() return "id" end,
        finish = function() error("cancel failed") end,
    })
    assert(not ok and message:find("could not cancel", 1, true))
end)



local roblox = require("@lune/roblox")
local gameRoot = { Name = "Game", children = {} }
function gameRoot:IsA(class) return class == "DataModel" end
local function object(name, parent, class)
    local node = { Name = name, Parent = parent, ClassName = class or "Folder", children = {}, Locked = false,
        Material = roblox.Enum.Material.Plastic, MaterialVariant = "", Size = roblox.Vector3.new(2, 2, 2),
        CFrame = roblox.CFrame.new(), Color = roblox.Color3.new(0.2, 0.4, 0.6), TextureID = "example-texture",
        CustomPhysicalProperties = { marker = "unchanged" },
    }
    function node:IsA(candidate)
        if candidate == self.ClassName then return true end
        if candidate == "BasePart" then return self.ClassName == "Part" or self.ClassName == "MeshPart" or self.ClassName == "Terrain" end
        if candidate == "WorldRoot" or candidate == "Model" then return self.ClassName == "WorldModel" or self.ClassName == "Workspace" end
        return false
    end
    function node:IsDescendantOf(ancestor)
        local cursor = self.Parent
        while cursor do if cursor == ancestor then return true end cursor = cursor.Parent end
        return false
    end
    function node:FindFirstAncestorWhichIsA(class)
        local cursor = self.Parent
        while cursor do if cursor:IsA(class) then return cursor end cursor = cursor.Parent end
        return nil
    end
    function node:GetChildren() return self.children end
    function node:GetFullName()
        local names, cursor = {}, self
        while cursor and cursor ~= gameRoot do table.insert(names, 1, cursor.Name) cursor = cursor.Parent end
        return table.concat(names, ".")
    end
    if parent then table.insert(parent.children, node) end
    return node
end
local world = object("Workspace", gameRoot, "Workspace")
local Scope = luau.load(fs.readFile("src/Scope.luau"), { environment = { game = gameRoot } })()
local modules = { Rules = Rules, Scope = Scope }
local Adapter = luau.load(fs.readFile("src/Adapter.luau"), { environment = {
    require = function(name) assert(modules[name]) return modules[name] end,
    script = { Parent = { Rules = "Rules", Scope = "Scope" } }, game = gameRoot, workspace = world,
    Enum = roblox.Enum, Vector3 = roblox.Vector3,
} })()
local function near(a, b)
    assert(math.abs(a - b) < 0.0001, tostring(a) .. " differs from " .. tostring(b))
end
test("scope deduplicates overlapping roots", function()
    local folder = object("Folder", world)
    local a, b = object("A", folder), object("B", folder)
    local targets, scanned = Scope.collect({ folder, a }, true, function() return true end)
    assert(#targets == 3 and scanned == 3 and targets[1] == folder and targets[2] == b and targets[3] == a)
    local only = Scope.collect({ folder }, false, function() return true end)
    assert(#only == 1)
end)
test("scope rejects detached roots, services and empty selections", function()
    rejects(function() Scope.collect({}, true, function() return true end) end)
    rejects(function() Scope.collect({ world }, true, function() return true end) end)
    rejects(function() Scope.collect({ object("Detached", nil) }, true, function() return true end) end)
end)
test("scope limits discovered objects before returning partial results", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return false end, { maxNodes = 2, maxTargets = 2 }) end)
end)
test("scope target limit is independent of scan limit", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return true end, { maxNodes = 10, maxTargets = 2 }) end)
end)


test("material preview is read-only and writes preserve unrelated properties", function()
    local part = object("Part", world, "Part")
    local frame, color, texture, physical = part.CFrame, part.Color, part.TextureID, part.CustomPhysicalProperties
    local plan = Adapter.plan({ part }, { material = "Wood", variants = "Skip custom variants", expand = false })
    assert(#plan == 1 and part.Material == roblox.Enum.Material.Plastic and Adapter.validate(plan))
    Adapter.write(plan[1])
    assert(part.Material == roblox.Enum.Material.Wood and part.MaterialVariant == "")
    assert(part.CFrame == frame and part.Color == color and part.TextureID == texture and part.CustomPhysicalProperties == physical)
end)
test("custom variants are skipped by default", function()
    local a, b = object("A", world, "Part"), object("B", world, "Part")
    a.MaterialVariant = "CustomWood"
    local plan = Adapter.plan({ a, b }, { material = "Metal", variants = "Skip custom variants", expand = false })
    assert(#plan == 1 and plan.skippedVariants == 1 and plan[1].before.target == b and a.MaterialVariant == "CustomWood")
end)
test("explicit clear handles variants even when the base material is unchanged", function()
    local part = object("Part", world, "Part")
    part.MaterialVariant = "Variant"
    local plan = Adapter.plan({ part }, { material = "Plastic", variants = "Clear part variants", expand = false })
    assert(#plan == 1 and plan.skippedVariants == 0) Adapter.write(plan[1])
    assert(part.Material == roblox.Enum.Material.Plastic and part.MaterialVariant == "")
end)
test("unsupported material names and invalid policies are refused", function()
    local part = object("Part", world, "Part")
    for _, name in ipairs({ "", "Water", "wood", "NotAMaterial" }) do
        rejects(function() Adapter.plan({ part }, { material = name, variants = "Skip custom variants" }) end)
    end
    rejects(function() Adapter.plan({ part }, { material = "Wood", variants = "Unknown" }) end)
    assert(part.Material == roblox.Enum.Material.Plastic)
end)
test("locked targets refuse the entire preview", function()
    local a, b = object("A", world, "Part"), object("B", world, "Part") b.Locked = true
    rejects(function() Adapter.plan({ a, b }, { material = "Wood", variants = "Skip custom variants" }) end)
    assert(a.Material == roblox.Enum.Material.Plastic)
end)
test("changed materials, variants, locks and parents invalidate previews", function()
    local part = object("Part", world, "Part")
    local plan = Adapter.plan({ part }, { material = "Wood", variants = "Skip custom variants" })
    part.Material = roblox.Enum.Material.Glass assert(not Adapter.validate(plan))
    part.Material = roblox.Enum.Material.Plastic part.MaterialVariant = "Changed" assert(not Adapter.validate(plan))
    part.MaterialVariant = "" part.Locked = true assert(not Adapter.validate(plan))
    part.Locked = false part.Parent = nil assert(not Adapter.validate(plan))
end)
test("nested material scopes deduplicate parts and exclude Terrain", function()
    local folder = object("Folder", world)
    local part = object("Part", folder, "Part") object("Terrain", folder, "Terrain")
    local plan = Adapter.plan({ folder, part }, { material = "Wood", variants = "Skip custom variants", expand = true })
    assert(#plan == 1)
end)
test("unchanged materials are omitted", function()
    local part = object("Part", world, "Part")
    assert(#Adapter.plan({ part }, { material = "Plastic", variants = "Clear part variants" }) == 0)
end)

print(string.format("%d checks passed", count))
