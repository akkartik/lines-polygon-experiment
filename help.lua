function draw_help_without_mouse_pressed(State, drawing)
  App.color(Help_color)
  local y = drawing.y+10
  love.graphics.print("Things you can do:", State.left+30,y)
  y = y + Line_height
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape(), State.left+30,y)
  y = y + Line_height
  love.graphics.print("* Hover on a point and press 'ctrl+u' to pick it up and start moving it,", State.left+30,y)
  y = y + Line_height
  love.graphics.print("then press the mouse button to drop it", State.left+30+bullet_indent(),y)
  y = y + Line_height
  love.graphics.print("* Hover on a point and press 'ctrl+n', type a name, then press 'enter'", State.left+30,y)
  y = y + Line_height
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", State.left+30,y)
  y = y + Line_height
  if Current_drawing_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+p' to switch to drawing freehand strokes", State.left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+2' to switch to drawing lines", State.left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", State.left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+o' to switch to drawing circles/arcs", State.left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+<digit>' to switch to drawing regular polygons", State.left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'ctrl+r' to switch to drawing rectangles", State.left+30,y)
    y = y + Line_height
  end
  love.graphics.print("* Press 'ctrl+=' or 'ctrl+-' to zoom in or out, ctrl+0 to reset zoom", State.left+30,y)
  y = y + Line_height
  love.graphics.print("Press 'esc' now to hide this message", State.left+30,y)
  y = y + Line_height
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', State.left,drawing.y, State.right, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function draw_help_with_mouse_pressed(State, drawing)
  App.color(Help_color)
  local y = drawing.y+10
  love.graphics.print("You're currently drawing a "..current_shape(State, drawing.pending), State.left+30,y)
  y = y + State.line_height
  love.graphics.print('Things you can do now:', State.left+30,y)
  y = y + State.line_height
  if State.current_drawing_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing the stroke', State.left+30,y)
    y = y + State.line_height
  elseif State.current_drawing_mode == 'line' or State.current_drawing_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing the line', State.left+30,y)
    y = y + State.line_height
  elseif State.current_drawing_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing the circle', State.left+30,y)
      y = y + State.line_height
      love.graphics.print("* Press 'a' to draw just an arc of a circle", State.left+30,y)
    else
      love.graphics.print('* Release the mouse button to finish drawing the arc', State.left+30,y)
    end
    y = y + Line_height
  elseif Current_drawing_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing the regular polygon', State.left+30,y)
    y = y + Line_height
  elseif Current_drawing_mode == 'rectangle' then
    if #drawing.pending.vertices < 2 then
      love.graphics.print("* Press 'p' to add a vertex to the rectangle", State.left+30,y)
      y = y + State.line_height
    else
      love.graphics.print('* Release the mouse button to finish drawing the rectangle', State.left+30,y)
      y = y + State.line_height
      love.graphics.print("* Press 'p' to replace the second vertex of the rectangle", State.left+30,y)
      y = y + State.line_height
    end
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", State.left+30,y)
  y = y + Line_height
  y = y + Line_height
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press '2' to switch to drawing lines", State.left+30,y)
    y = y + Line_height
  end
  love.graphics.print("* Press other digits to switch to polygons with corresponding vertices", State.left+30,y)
  y = y + Line_height
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", State.left+30,y)
    y = y + Line_height
  end
  if State.current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'o' to switch to drawing circles/arcs", State.left+30,y)
    y = y + State.line_height
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'r' to switch to drawing rectangles", State.left+30,y)
    y = y + Line_height
  end
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', State.left,drawing.y, State.right, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function current_shape(State, shape)
  if State.current_drawing_mode == 'freehand' then
    return 'freehand stroke'
  elseif State.current_drawing_mode == 'line' then
    return 'straight line'
  elseif State.current_drawing_mode == 'manhattan' then
    return 'horizontal/vertical line'
  elseif State.current_drawing_mode == 'circle' and shape and shape.start_angle then
    return 'arc'
  else
    return State.current_drawing_mode
  end
end

_bullet_indent = nil
function bullet_indent()
  if _bullet_indent == nil then
    local text = love.graphics.newText(love.graphics.getFont(), '* ')
    _bullet_indent = text:getWidth()
  end
  return _bullet_indent
end
