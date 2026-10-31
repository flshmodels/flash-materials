local Rules = require(script.Parent.Rules)
local Scope = require(script.Parent.Scope)
local Adapter = {}
local names = { "Plastic", "SmoothPlastic", "Wood", "WoodPlanks", "Concrete", "Brick", "Metal", "DiamondPlate", "Glass", "Neon", "Marble", "Fabric" }

local function materials()
    local result = {}
    for _, name in ipairs(names) do result[name] = Enum.Material[name] end
    return result
end

local function eligible(object)
    return object:IsA("BasePart") and not object:IsA("Terrain")
end

function Adapter.controls(panel, changed)
    panel.label("Apply a built-in material to selected parts. Color, textures and custom physical properties stay unchanged. A material change can change default physical behavior.")
    panel.label("Supported: " .. table.concat(names, ", "))
    local material = panel.field("Material (exact name)", "SmoothPlastic")
    local variants = panel.cycle("Variants", { "Skip custom variants", "Clear part variants" }, changed)
    local scope = panel.cycle("Scope", { "Selection only", "Include descendants" }, changed)
    material:GetPropertyChangedSignal("Text"):Connect(changed)
    return function() return { material = material.Text, variants = variants(), expand = scope() == "Include descendants" } end
end

function Adapter.plan(selection, options)
    local parts, scanned = Scope.collect(selection, options.expand, eligible)
    local rows = {}
    for _, part in ipairs(parts) do
        assert(not part.Locked, "A target part is locked. Unlock it or use a smaller selection.")
        table.insert(rows, {
            target = part, parent = part.Parent, material = part.Material.Name,
            materialEnum = part.Material, variant = part.MaterialVariant,
        })
    end
    local available = materials()
    local plan = Rules.plan(rows, options, available)
    plan.summary = string.format("%d changes / %d eligible parts / %d variant parts skipped / %d objects scanned.", #plan, #parts, plan.skippedVariants, scanned)
    for _, entry in ipairs(plan) do
        entry.materialEnum = available[entry.after]
        local variant = if entry.before.variant == "" then "" else " [" .. entry.before.variant .. "]"
        entry.label = entry.before.target:GetFullName() .. "\n" .. entry.before.material .. variant .. " -> " .. entry.after
    end
    return plan
end

function Adapter.validate(plan)
    for _, entry in ipairs(plan) do
        local before = entry.before
        local part = before.target
        if not part:IsDescendantOf(game) or not eligible(part) or part.Parent ~= before.parent or part.Locked
            or part.Material ~= before.materialEnum or part.MaterialVariant ~= before.variant then
            return false, "A part, material or variant changed after preview. Preview again."
        end
    end
    return true
end

function Adapter.write(entry)
    entry.before.target.Material = entry.materialEnum
    entry.before.target.MaterialVariant = ""
end

return Adapter
