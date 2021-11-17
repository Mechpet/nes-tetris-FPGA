-- Converts RGB Colorscaled black and white image to the font_rom array as found in the given SystemVerilog file font_rom.sv.
-- Maps:
--      Black -> 1'b0
--      White -> 1'b1
-- The output can have automated comments generated with the .py file.

local dlg = Dialog()
local sprite = app.activeSprite
local name = sprite.filename
local sprite_sheet = Image(sprite)
local w = sprite_sheet.width
local h = sprite_sheet.height

-- sliceToLastSubstr
-- Arguments: str is the string to slice
--            substr is the string to slice to
-- Implementation: Find the index of the last substr in str and then return a string that omits all characters following that substr
-- Purpose: Return a string that omits all characters following the last found substr in str
function sliceToLastSubstr(str, substr)
    assert(type(str) == "string", "Passed argument str to sliceToLastSubstr is not a string.")
    assert(type(substr) == "string", "Passed argument substr to sliceToLastSubstrs is not a string.")

    local lastIndex, index = 1, 0
    
    while (index ~= nil) do -- Keep finding leading '\' until there are no more - the last found index is the index of the last '\' in str
        lastIndex = index
        _, index = string.find(str, substr, index + 1)
    end

    -- Slice the sprite name to exclude the last character in the last substr 
    slicedStr = string.sub(str, 1, lastIndex - 1)
    return slicedStr
end

-- sliceToLastSubstr
-- Arguments: str is the string to slice
--            substr is the string to slice past
-- Implementation: Find the index of the last substr in str and then return a string that omits all characters before that substr.
-- Purpose: Return a string that omits all characters preceding the last found substr in str.
function slicePastLastSubstr(str, substr)
    assert(type(str) == "string", "Passed argument str to slicePastLastSubstr is not a string.")
    assert(type(substr) == "string", "Passed argument substr to slicePastLastSubstr is not a string.")

    local lastIndex, index = 1, 0
    
    while (index ~= nil) do -- Keep finding leading '\' until there are no more - the last found index is the index of the last '\' in str.
        lastIndex = index
        _, index = string.find(str, substr, index + 1)
    end

    -- Slice the sprite name to exclude the last character in the last substr.
    slicedStr = string.sub(str, lastIndex + 1, -1)
    return slicedStr
end

dlg:number {
    id = "width",
    label = "Sprite width (px): ",
    text = "8", -- Default width is 8 pixels.
    decimals = 0
}

dlg:number {
    id = "height",
    label = "Pixel height (px): ",
    text = "8",  -- Default height is 8 pixels.
    decimals = 0
}

dlg:entry {
    id = "dest",
    label = "Folder path",
    text = ""
}

dlg:entry {
    id = "file",
    label = "File name (.txt)",
    text = ""
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:button {
    id = "export",
    text = "EXPORT",
    onclick = function()
        local data = dlg.data
        local sprite_w = data.width
        local sprite_h = data.height
        local sprite = app.activeSprite
        local columns = math.floor(w / sprite_w)
        local rows = math.floor(h / sprite_h) 
        local index = 0
        local row_index = 0
	    local column_index = 0
        local x = 0
        local y = 0
        
        local destData = data.dest
        
        if (destData ~= "") then -- If the user has inputted a destination in the dialog entry, set that as the directory of output.
            destName = destData
            if (string.byte(destName, -1) ~= string.byte("\\")) then -- In case the destination entered does not end with a backslash, append one.
                destName = destName.."\\"
            end
        else -- If the user has left the dialog entry blank, set the default directory as the same directory the active sprite has.
            destName = sliceToLastSubstr(name, "\\").."\\"
        end

        local fileData = data.file

        if (fileData ~= "") then -- If the user has inputted a name in the dialog entry, set that as the output file name.
            fileName = fileData..".txt"
        else -- If the user has lef tthe dialog entry blank, set the default name as the same name the active sprite has.
            temp = slicePastLastSubstr(name, "\\")
            fileName = sliceToLastSubstr(temp, "%.")..".txt"
        end

        file = io.open(fileName, "w")
        io.output(file)

	    while row_index < rows do
            -- Handle a column of sprites.
		    while column_index < columns do
                -- Before the array of bits pertaining to the sprite, print the character code.
                io.write("\t\t// Code "..row_index * columns + column_index.."\n")
                -- Iterate through raster-order.
                while y < sprite_h do
                    -- For each row of the sprite, allocate 1 slot of the ROM (data width is equal to the sprite width since this is monocolor).
                    io.write("\t\t"..sprite_w.."'b")
                    -- For each pixel of the row, map its color to a bit.
                    while x < sprite_w do
			            local pixel_value = sprite_sheet:getPixel(column_index * sprite_w + x, row_index * sprite_h + y)
                        
                        if pixel_value == 2 ^ 32 - 1 then
                            io.write("1")
                        else 
                            io.write("0")
                        end

                        x = x + 1
                    end
                    -- Terminate the current line with a comma and a comment.
                    io.write(", // "..y.." \n")
                    x = 0
                    y = y + 1
                end
                x = 0
                y = 0
                column_index = column_index + 1
		    end
            row_index = row_index + 1
            column_index = 0
	    end
        io.close(file)
    end
}

dlg:show { 
    wait = false 
}