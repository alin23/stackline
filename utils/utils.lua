-- OTHERS ----------------------------------------------------------------------
-- https://github.com/luapower/glue/blob/master/glue.lua
-- https://github.com/Desvelao/f/blob/master/f/table.lua (new in 2020)
-- https://github.com/moriyalb/lamda (based on ramda, updated May 2020, 27 stars)
-- -----------------------------------------------------------------------------
utils = {}

utils.map = hs.fnutils.map
utils.filter = hs.fnutils.filter
utils.reduce = hs.fnutils.reduce
utils.partial = hs.fnutils.partial
utils.each = hs.fnutils.each
utils.contains = hs.fnutils.contains
utils.some = hs.fnutils.some
utils.any = hs.fnutils.some -- also rename 'some()' to 'any()'
utils.concat = hs.fnutils.concat
utils.copy = hs.fnutils.copy

function utils.keyBind(hyper, keyFuncTable) -- {{{
    for key, fn in pairs(keyFuncTable) do
        hs.hotkey.bind(hyper, key, fn)
    end
end -- }}}

utils.length = function(t) -- {{{
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end -- }}}

utils.indexOf = function(t, object) -- {{{
    if type(t) ~= "table" then
        error("table expected, got " .. type(t), 2)
    end

    for i, v in pairs(t) do
        if object == v then
            return i
        end
    end
end -- }}}

function utils.isEqual(a, b) -- {{{
    --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
    --]]

    local function isEqualTable(t1, t2)

        if t1 == t2 then
            return true
        end

        -- luacheck: ignore
        for k, v in pairs(t1) do

            if type(t1[k]) ~= type(t2[k]) then
                return false
            end

            if type(t1[k]) == "table" then
                if not isEqualTable(t1[k], t2[k]) then
                    return false
                end
            else
                if t1[k] ~= t2[k] then
                    return false
                end
            end
        end

        for k, v in pairs(t2) do

            if type(t2[k]) ~= type(t1[k]) then
                return false
            end

            if type(t2[k]) == "table" then
                if not isEqualTable(t2[k], t1[k]) then
                    return false
                end
            else
                if t2[k] ~= t1[k] then
                    return false
                end
            end
        end

        return true
    end

    if type(a) ~= type(b) then
        return false
    end

    if type(a) == "table" then
        return isEqualTable(a, b)
    else
        return (a == b)
    end

end -- }}}

-- FROM: lume.lua — https://github.com/rxi/lume/blob/master/lume.lua
function utils.isarray(x) -- {{{
    return type(x) == "table" and x[1] ~= nil
end -- }}}
local getiter = function(x) -- {{{
    if utils.isarray(x) then
        return ipairs
    elseif type(x) == "table" then
        return pairs
    end
    error("expected table", 3)
end -- }}}
function utils.invert(t) -- {{{
    local rtn = {}
    for k, v in pairs(t) do
        rtn[v] = k
    end
    return rtn
end -- }}}
function utils.keys(t) -- {{{
    local rtn = {}
    local iter = getiter(t)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end -- }}}
function utils.find(t, value) -- {{{
    local iter = getiter(t)
    result = nil
    for k, v in iter(t) do
        print('value looking for')
        print(value)
        print('key matching against')
        print(k)
        print('are they equal?')
        print(k == value)
        if k == value then
            result = v
        end
    end
    -- utils.pheader('result')
    print(result)
    return result
end -- }}}
-- END lume.lua

local function filter_row(row, key_constraints) -- {{{
    -- Check if a row matches the specified key constraints.
    -- @param row The row to check
    -- @param key_constraints The key constraints to apply
    -- @return A boolean result

    -- Loop through all constraints
    for k, v in pairs(key_constraints) do
        if v and not row[k] then
            -- The row is missing the key entirely,
            -- definitely not a match
            return false
        end

        -- Wrap the key and constraint values in arrays,
        -- if they're not arrays already (so we can loop through them)
        local actual_values = type(row[k]) == "table" and row[k] or {row[k]}
        local required_values = type(v) == "table" and v or {v}

        -- Loop through the values we *need* to find
        for i = 1, #required_values do
            local found
            -- Loop through the values actually present
            for j = 1, #actual_values do
                if actual_values[j] == required_values[i] then
                    -- This object has the required value somewhere in the key,
                    -- no need to look any farther
                    found = true
                    break
                end
            end

            if not found then
                return false
            end
        end
    end

    return true
end -- }}}

function utils.pick(input, key_values) -- {{{
    -- Filter an array, returning entries matching `key_values`.
    -- @param input The array to process
    -- @param key_values A table of keys mapped to their viable values
    -- @return An array of matches
    local result = {}
    utils.each(key_values, function(k)
        result[k] = input[k]
    end)
    return result
end -- }}}

function utils.p(data, howDeep) -- {{{
    howDeep = howDeep or 3
    print(hs.inspect(data, {depth = howDeep}))
end -- }}}

function utils.pdivider(str) -- {{{
    str = string.upper(str) or ""
    print("=========", str, "==========")
end -- }}}

function utils.pheader(str) -- {{{
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
end -- }}}

function utils.groupBy(t, f) -- {{{
    -- FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
    local res = {}
    for _k, v in pairs(t) do
        local g
        if type(f) == 'function' then
            g = f(v)
        elseif type(f) == 'string' and v[f] ~= nil then
            g = v[f]
        else
            error('Invalid group parameter [' .. f .. ']')
        end

        if res[g] == nil then
            res[g] = {}
        end
        table.insert(res[g], v)
    end
    return res
end -- }}}

function utils.tableCopyShallow(orig) -- {{{
    -- FROM: https://github.com/XavierCHN/go/blob/master/game/go/scripts/vscripts/utils/table.lua
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end -- }}}

function utils.equal(a, b) -- {{{
    if #a ~= #b then
        return false
    end

    for i, _ in ipairs(a) do
        if b[i] ~= a[i] then
            return false
        end
    end

    return true
end -- }}}

-- TODO: Confirm that hs.fnutils.partial works just as well
function utils.partial(f, ...) -- {{{
    -- FROM: https://www.reddit.com/r/lua/comments/fh2go5/a_partialcurry_implementation_of_mine_hope_you/
    -- WHEN: 2020-08-08
    local unpack = unpack or table.unpack -- Lua 5.3 moved unpack
    local a = {...}
    local a_len = select("#", ...)
    return function(...)
        local tmp = {...}
        local tmp_len = select("#", ...)
        -- Merge arg lists
        for i = 1, tmp_len do
            a[a_len + i] = tmp[i]
        end
        return f(unpack(a, 1, a_len + tmp_len))
    end
end -- }}}

utils.flattenForce = require 'stackline.utils.flatten'
-- table will be squashed down to 1 level deep. Previously nested structures
-- will be converted to long, path-like string keys.

function utils.greaterThan(n) -- {{{
    return function(t)
        return #t > n
    end
end -- }}}

function utils.getFields(t, fields) -- {{{
    -- FROM: https://stackoverflow.com/questions/41417971/a-better-way-to-assign-multiple-return-values-to-table-keys-in-lua
    -- WHEN: 2020-08-09
    -- USAGE:
    --      local bnot, band, bor = get_fields(require("bit"), {"bnot", "band", "bor"})
    local values = {}
    for k, field in ipairs(fields) do
        values[k] = t[field]
    end
    return (table.unpack or unpack)(values, 1, #fields)
end -- }}}

function utils.setFields(tab, fields, ...) -- {{{
    -- USAGE:
    --      image.size = set_fields({}, {"width", "height"}, image.data:getDimensions())
    --     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  ---
    -- USAGE EXAMPLE #2:      {{{
    --      Swap the values on-the-fly!

    --      local function get_weekdays()
    --         return "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    --      end

    --          -- we want to save returned values in different order
    --      local weekdays = set_fields({}, {7,1,2,3,4,5,6}, get_weekdays())
    --          -- now weekdays contains {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
    --   --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  ---
    -- USAGE EXAMPLE #3:     
    --      local function get_coords_x_y_z()
    --         return 111, 222, 333      -- x, y, z of the point
    --      end
    --          -- we want to get the projection of the point on the ground plane local projection = {y = 0}
    --          -- projection.y will be preserved, projection.x and projection.z will be modified

    --      set_fields(projection, {"x", "", "z"}, get_coords_x_y_z())

    --          -- now projection contains {x = 111, y = 0, z = 333}
    --   --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  ---
    -- Usage example #4:
    --          -- If require("some_module") returns a module with plenty of functions
    --          -- inside, but you need only a few of them:
    --      local bnot, band, bor = get_fields(require("bit"), {"bnot", "band", "bor"})
    --   --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  ---
    -- }}}

    -- fields is an array of field names
    -- (use empty string to skip value at corresponging position)
    local values = {...}
    for k, field in ipairs(fields) do
        if field ~= "" then
            tab[field] = values[k]
        end
    end
    return tab
end -- }}}

return utils

