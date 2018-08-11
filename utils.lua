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

function M.enabled(n)
    local n = (n and (n > 2)) and n or 2
    return math.random() < (1 / n)
end

function M.sqr(v)
    return v * v
end

function M.vector(fromX, fromY, toX, toY)
    return { x = toX - fromX, y = toY - fromY }
end

function M.vectorToAngle(vec)
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

function M.vectorLen(vec)
    return math.sqrt(vec.x * vec.x + vec.y * vec.y)
end

function M.distanceBetween(obj1, obj2)
    local dX = obj1.x - obj2.x
    local dY = obj1.y - obj2.y

    return math.sqrt(dX * dX + dY * dY)
end

function M.hasCollidedCircle(obj1, obj2)
    local minimalDistance = (obj2.contentWidth / 2) + (obj1.contentWidth / 2)
    return M.distanceBetween(obj1, obj2) < minimalDistance
end

return M
