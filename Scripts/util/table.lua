
---@param table table
function table.shuffle(table)
	local size = #table
	for i = size, 2, -1 do
		local j = math.random(i)

		table[i], table[j] = table[j], table[i]
	end

	return table
end
