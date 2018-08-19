local M = {}

local tableRemove = table.remove

function M:new(callback, options)
    local pool = {
        callback = callback,
    }

    function pool:get()
        if pool._cache == nil then
            pool._cache = {}
        end

        local item
        if #pool._cache > 0 then
            item = pool._cache[#self._cache]
            tableRemove(pool._cache, #pool._cache)
        else
            item = self.callback()
        end

        return item
    end

    function pool:put(item)
        pool._cache[#pool._cache + 1] = item
    end

    return pool
end

return M
