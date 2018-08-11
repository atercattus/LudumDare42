local math = math

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

function M.vector(fromX, fromY, toX, toY)
    return { x = toX - fromX, y = toY - fromY }
end

function M.vec2Angle(vec)
    if vec.y == 0 then
        return 0
    end

    local angle = math.deg(math.atan(vec.x / vec.y))
    if vec.y < 0 then
        angle = angle + 180
    elseif vec.x < 0 then
        angle = angle + 360
    end

    return angle
end

return M
