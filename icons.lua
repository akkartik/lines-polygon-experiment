icon = {}

function icon.line_width(x, y)
  love.graphics.setColor(0.7,0.7,0.7)
  love.graphics.line(x+0,y+0, x+9,y+0)
  love.graphics.line(x+0,y+1, x+9,y+1)
  love.graphics.line(x+0,y+2, x+9,y+2)
  love.graphics.line(x+0,y+3, x+9,y+3)
  love.graphics.line(x+0,y+4, x+9,y+4)
  love.graphics.line(x+0,y+5, x+9,y+5)
  love.graphics.line(x+1,y+6, x+8,y+6)
  love.graphics.line(x+2,y+7, x+7,y+7)
  love.graphics.line(x+3,y+8, x+6,y+8)
  love.graphics.line(x+4,y+9, x+5,y+9)
end

function icon.insert_drawing(x, y)
  love.graphics.setColor(0.7,0.7,0.7)
  love.graphics.rectangle('line', x,y, 12,12)
  love.graphics.line(4,y+6, 16,y+6)
  love.graphics.line(10,y, 10,y+12)
  love.graphics.setColor(0, 0, 0)
end

function icon.freehand(x, y)
  love.graphics.line(x+4,y+7,x+5,y+5)
  love.graphics.line(x+5,y+5,x+7,y+4)
  love.graphics.line(x+7,y+4,x+9,y+3)
  love.graphics.line(x+9,y+3,x+10,y+5)
  love.graphics.line(x+10,y+5,x+12,y+6)
  love.graphics.line(x+12,y+6,x+13,y+8)
  love.graphics.line(x+13,y+8,x+13,y+10)
  love.graphics.line(x+13,y+10,x+14,y+12)
  love.graphics.line(x+14,y+12,x+15,y+14)
  love.graphics.line(x+15,y+14,x+15,y+16)
end

function icon.line(x, y)
  love.graphics.line(x+4,y+2, x+16,y+18)
end

function icon.manhattan(x, y)
  love.graphics.line(x+4,y+20, x+4,y+2)
  love.graphics.line(x+4,y+2, x+10,y+2)
  love.graphics.line(x+10,y+2, x+10,y+10)
  love.graphics.line(x+10,y+10, x+18,y+10)
end

function icon.polygon(x, y)
  local offsets
  if Current_drawing_submode == 3 then
    offsets = {{10,4}, {4,16}, {16,16}}
  elseif Current_drawing_submode == 4 then
    offsets = {{4,4}, {4,16}, {16,16}, {16,4}}
  elseif Current_drawing_submode == 5 then
    offsets = {{10,2}, {18,10}, {16,18}, {4,18}, {2,10}}
  elseif Current_drawing_submode == 6 then
    offsets = {{7,4}, {13,4}, {16,10}, {13,16}, {7,16}, {4,10}}
  elseif Current_drawing_submode == 7 then
    -- not quite right
    offsets = {{7,4}, {12,5}, {15,11}, {12,15}, {6,17}, {4,12}, {4,8}}
  elseif Current_drawing_submode == 8 then
    offsets = {{4,4}, {2,10}, {4,16}, {10,18}, {16,16}, {18,10}, {16,4}, {10,2}}
  elseif Current_drawing_submode == 9 then
    -- not quite right
    offsets = {{10,4}, {6,8}, {5,12}, {4,16}, {8,18}, {12,18}, {16,16}, {15,11}, {14,8}}
  else
    print(Current_drawing_submode)
    assert(false)
  end
  for i=1,#offsets-1 do
    love.graphics.line(x+offsets[i][1],y+offsets[i][2], x+offsets[i+1][1],y+offsets[i+1][2])
  end
  love.graphics.line(x+offsets[#offsets][1],y+offsets[#offsets][2], x+offsets[1][1],y+offsets[1][2])
end

function icon.rectangle(x, y)
  love.graphics.line(x+4,y+8, x+4,y+16)
  love.graphics.line(x+4,y+16, x+16,y+16)
  love.graphics.line(x+16,y+16, x+16,y+8)
  love.graphics.line(x+16,y+8, x+4,y+8)
end

function icon.circle(x, y)
  love.graphics.circle('line', x+10,y+10, 8)
end
