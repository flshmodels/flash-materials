local Rules = {}

function Rules.plan(rows, options, supported)
    assert(#rows > 0 and #rows <= 1000, "Choose between 1 and 1000 parts, excluding Terrain.")
    assert(type(options.material) == "string" and supported[options.material], "Choose an exact material name from the supported list.")
    assert(options.variants == "Skip custom variants" or options.variants == "Clear part variants", "Choose how to handle per-part material variants.")
    local plan, skipped = {}, 0
    for _, row in ipairs(rows) do
        if row.variant ~= "" and options.variants == "Skip custom variants" then
            skipped += 1
        elseif row.material ~= options.material or row.variant ~= "" then
            table.insert(plan, { before = row, after = options.material })
        end
    end
    plan.skippedVariants = skipped
    return plan
end

return Rules
