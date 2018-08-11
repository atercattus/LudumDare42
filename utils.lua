local M = {}

function M.randomInt(from, to)
    if from == nil then
        from = 1
    end
    local to = to or from

    local n = to - from

    return math.round(math.random() * n) + from
end

function M.sqr(v)
    return v * v
end

return M
