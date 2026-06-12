---@param table table
---@return table
function sm.util.shuffle(table)
	local size = #table
	for i = size, 2, -1 do
		local j = math.random(i)

		table[i], table[j] = table[j], table[i]
	end

	return table
end

---@param hex string
---@return Color
function sm.util.toColor(hex)
	hex = hex:gsub("#", "")
	local r_num = tonumber(hex:sub(1, 2), 16) or 0
	local g_num = tonumber(hex:sub(3, 4), 16) or 0
	local b_num = tonumber(hex:sub(5, 6), 16) or 0
	return sm.color.new(r_num / 255, g_num / 255, b_num / 255)
end
