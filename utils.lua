local M = {}

function M.randomInt(from, to)
    if to ~= nil then
        if from == nil then
            from = 1
        end
        local to = to or from

        local n = to - from

        return math.round(math.random() * n) + from
    else
        local n = from or 1
        return math.round(math.random() * n)
    end
end

function M.sqr(v)
    return v * v
end

return M
