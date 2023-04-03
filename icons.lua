icon = {}

function icon.insert_drawing(button_params)
  local x,y = button_params.x, button_params.y
  App.color(Icon_color)
  love.graphics.rectangle('line', x,y, 12,12)
  love.graphics.line(x,y+6, x+12,y+6)
  love.graphics.line(x+6,y, x+6,y+12)
end

function icon.hyperlink_decoration(button_params)
  local x,y = button_params.x, button_params.y
  -- hack: set the hyperlink color so that caller can draw the text of the
  -- hyperlink in the same color
  App.color(Hyperlink_decoration_color)
  love.graphics.line(x,y+Editor_state.line_height, x+button_params.w,y+Editor_state.line_height)
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
  if Editor_state.current_drawing_submode == 3 then
    offsets = {{10,4}, {4,16}, {16,16}}
  elseif Editor_state.current_drawing_submode == 4 then
    offsets = {{4,4}, {4,16}, {16,16}, {16,4}}
  elseif Editor_state.current_drawing_submode == 5 then
    offsets = {{10,2}, {18,10}, {16,18}, {4,18}, {2,10}}
  elseif Editor_state.current_drawing_submode == 6 then
    offsets = {{7,4}, {13,4}, {16,10}, {13,16}, {7,16}, {4,10}}
  elseif Editor_state.current_drawing_submode == 7 then
    -- not quite right
    offsets = {{7,4}, {12,5}, {15,11}, {12,15}, {6,17}, {4,12}, {4,8}}
  elseif Editor_state.current_drawing_submode == 8 then
    offsets = {{4,4}, {2,10}, {4,16}, {10,18}, {16,16}, {18,10}, {16,4}, {10,2}}
  elseif Editor_state.current_drawing_submode == 9 then
    -- not quite right
    offsets = {{10,4}, {6,8}, {5,12}, {4,16}, {8,18}, {12,18}, {16,16}, {15,11}, {14,8}}
  else
    print(Editor_state.current_drawing_submode)
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
