-- primitives for editing drawings
Drawing = {}
geom = require 'geom'

require 'drawing_tests'

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts.
function Drawing.draw(line)
  local pmx,pmy = App.mouse_x(), App.mouse_y()
  if pmx < Margin_left+Line_width and pmy > line.y and pmy < line.y+Drawing.pixels(line.h) then
    love.graphics.setColor(0.75,0.75,0.75)
    love.graphics.rectangle('line', Margin_left,line.y, Line_width,Drawing.pixels(line.h))
    if icon[Current_drawing_mode] then
      icon[Current_drawing_mode](Margin_left+Line_width-22, line.y+4)
    else
      icon[Previous_drawing_mode](Margin_left+Line_width-22, line.y+4)
    end

    if App.mouse_down(1) and love.keyboard.isDown('h') then
      draw_help_with_mouse_pressed(line)
      return
    end
  end

  if line.show_help then
    draw_help_without_mouse_pressed(line)
    return
  end

  local mx,my = Drawing.coord(pmx-Margin_left), Drawing.coord(pmy-line.y)

  for _,shape in ipairs(line.shapes) do
    assert(shape)
    if geom.on_shape(mx,my, line, shape) then
      love.graphics.setColor(1,0,0)
    else
      love.graphics.setColor(0,0,0)
    end
    Drawing.draw_shape(Margin_left,line.y, line, shape)
  end
  for i,p in ipairs(line.points) do
    if p.deleted == nil then
      if Drawing.near(p, mx,my) then
        love.graphics.setColor(1,0,0)
        love.graphics.circle('line', Drawing.pixels(p.x)+Margin_left,Drawing.pixels(p.y)+line.y, 4)
      else
        love.graphics.setColor(0,0,0)
        love.graphics.circle('fill', Drawing.pixels(p.x)+Margin_left,Drawing.pixels(p.y)+line.y, 2)
      end
      if p.name then
        -- TODO: clip
        local x,y = Drawing.pixels(p.x)+Margin_left+5, Drawing.pixels(p.y)+line.y+5
        love.graphics.print(p.name, x,y)
        if Current_drawing_mode == 'name' and i == line.pending.target_point then
          -- create a faint red box for the name
          love.graphics.setColor(1,0,0,0.1)
          local name_text
          -- TODO: avoid computing name width on every repaint
          if p.name == '' then
            name_text = Em
          else
            name_text = App.newText(love.graphics.getFont(), p.name)
          end
          love.graphics.rectangle('fill', x,y, App.width(name_text), Line_height)
        end
      end
    end
  end
  love.graphics.setColor(0.75,0.75,0.75)
  Drawing.draw_pending_shape(Margin_left,line.y, line)
end

function Drawing.draw_shape(left,top, drawing, shape)
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(point.x)+left,Drawing.pixels(point.y)+top)
      end
      prev = point
    end
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(p2.x)+left,Drawing.pixels(p2.y)+top)
  elseif shape.mode == 'rectangle' then
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(curr.x)+left,Drawing.pixels(curr.y)+top)
      end
      prev = curr
    end
    -- close the loop
    local curr = drawing.points[shape.vertices[1]]
    love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(curr.x)+left,Drawing.pixels(curr.y)+top)
  elseif shape.mode == 'polygon' then
    local center = drawing.points[shape.center]
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    local p1 = drawing.points[shape.p1]
    local x,y = Drawing.pixels(p1.x)+left, Drawing.pixels(p1.y)+top
    Drawing.draw_polygon(shape.num_vertices, cx,cy, x,y)
  elseif shape.mode == 'circle' then
    -- TODO: clip
    local center = drawing.points[shape.center]
    love.graphics.circle('line', Drawing.pixels(center.x)+left,Drawing.pixels(center.y)+top, Drawing.pixels(shape.radius))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    love.graphics.arc('line', 'open', Drawing.pixels(center.x)+left,Drawing.pixels(center.y)+top, Drawing.pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'deleted' then
    -- ignore
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.draw_pending_shape(left,top, drawing)
  local shape = drawing.pending
  if shape.mode == nil then
    -- nothing pending
  elseif shape.mode == 'freehand' then
    Drawing.draw_shape(left,top, drawing, shape)
  elseif shape.mode == 'line' then
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(mx)+left,Drawing.pixels(my)+top)
  elseif shape.mode == 'manhattan' then
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    if math.abs(mx-p1.x) > math.abs(my-p1.y) then
      love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(mx)+left,Drawing.pixels(p1.y)+top)
    else
      love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(p1.x)+left,Drawing.pixels(my)+top)
    end
  elseif shape.mode == 'rectangle' then
    local pmx,pmy = App.mouse_x(), App.mouse_y()
    local first = drawing.points[shape.vertices[1]]
    if #shape.vertices == 1 then
      love.graphics.line(Drawing.pixels(first.x)+left,Drawing.pixels(first.y)+top, pmx,pmy)
      return
    end
    local second = drawing.points[shape.vertices[2]]
    local mx,my = Drawing.coord(pmx-left), Drawing.coord(pmy-top)
    local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
    love.graphics.line(Drawing.pixels(first.x)+left,Drawing.pixels(first.y)+top, Drawing.pixels(second.x)+left,Drawing.pixels(second.y)+top)
    love.graphics.line(Drawing.pixels(second.x)+left,Drawing.pixels(second.y)+top, Drawing.pixels(thirdx)+left,Drawing.pixels(thirdy)+top)
    love.graphics.line(Drawing.pixels(thirdx)+left,Drawing.pixels(thirdy)+top, Drawing.pixels(fourthx)+left,Drawing.pixels(fourthy)+top)
    love.graphics.line(Drawing.pixels(fourthx)+left,Drawing.pixels(fourthy)+top, Drawing.pixels(first.x)+left,Drawing.pixels(first.y)+top)
  elseif shape.mode == 'polygon' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    Drawing.draw_polygon(Current_drawing_submode, cx,cy, App.mouse_x(),App.mouse_y())
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    love.graphics.circle('line', cx,cy, geom.dist(cx,cy, App.mouse_x(),App.mouse_y()))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    shape.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, shape.end_angle)
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    love.graphics.arc('line', 'open', cx,cy, Drawing.pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'move' then
    -- nothing pending; changes are immediately committed
  elseif shape.mode == 'name' then
    -- nothing pending; changes are immediately committed
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.draw_polygon(n, cx,cy, x1,y1)
  local r = geom.dist(cx,cy, x1,y1)
  local theta = 2*math.pi/n
  local prevx,prevy = x1,y1
  for i=1,n do
--?     print(prevx-cx,prevy-cy)
    x,y = geom.rotate(cx,cy, prevx,prevy, theta)
    love.graphics.line(prevx,prevy, x,y)
    prevx,prevy = x,y
  end
end

function Drawing.in_drawing(drawing, x,y)
  if drawing.y == nil then return false end  -- outside current page
  return y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h) and x >= Margin_left and x < Margin_left+Line_width
end

function Drawing.mouse_pressed(drawing, x,y, button)
  if Current_drawing_mode == 'freehand' then
    drawing.pending = {mode=Current_drawing_mode, points={{x=Drawing.coord(x-Margin_left), y=Drawing.coord(y-drawing.y)}}}
  elseif Current_drawing_mode == 'line' or Current_drawing_mode == 'manhattan' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, p1=j}
  elseif Current_drawing_mode == 'rectangle' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, vertices={j}}
  elseif Current_drawing_mode == 'polygon' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, num_vertices=Current_drawing_submode, center=j}
  elseif Current_drawing_mode == 'circle' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, center=j}
  elseif Current_drawing_mode == 'move' then
    -- all the action is in mouse_released
  elseif Current_drawing_mode == 'name' then
    -- nothing
  else
    print(Current_drawing_mode)
    assert(false)
  end
end

-- a couple of operations on drawings need to constantly check the state of the mouse
function Drawing.update()
  if Lines.current_drawing == nil then return end
  local drawing = Lines.current_drawing
  assert(drawing.mode == 'drawing')
  local x, y = App.mouse_x(), App.mouse_y()
  if App.mouse_down(1) then
    if Drawing.in_drawing(drawing, x,y) then
      if drawing.pending.mode == 'freehand' then
        table.insert(drawing.pending.points, {x=Drawing.coord(App.mouse_x()-Margin_left), y=Drawing.coord(App.mouse_y()-drawing.y)})
      elseif drawing.pending.mode == 'move' then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        drawing.pending.target_point.x = mx
        drawing.pending.target_point.y = my
        Drawing.relax_constraints(drawing, drawing.pending.target_point_index)
      end
    end
  elseif Current_drawing_mode == 'move' then
    if Drawing.in_drawing(drawing, x, y) then
      local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
      drawing.pending.target_point.x = mx
      drawing.pending.target_point.y = my
      Drawing.relax_constraints(drawing, drawing.pending.target_point_index)
    end
  else
    -- do nothing
  end
end

function Drawing.relax_constraints(drawing, p)
  for _,shape in ipairs(drawing.shapes) do
    if shape.mode == 'manhattan' then
      if shape.p1 == p then
        shape.mode = 'line'
      elseif shape.p2 == p then
        shape.mode = 'line'
      end
    elseif shape.mode == 'rectangle' or shape.mode == 'square' then
      for _,v in ipairs(shape.vertices) do
        if v == p then
          shape.mode = 'polygon'
        end
      end
    end
  end
end

function Drawing.mouse_released(x,y, button)
  if Current_drawing_mode == 'move' then
    Current_drawing_mode = Previous_drawing_mode
    Previous_drawing_mode = nil
    if Lines.current_drawing then
      Lines.current_drawing.pending = {}
      Lines.current_drawing = nil
    end
  elseif Lines.current_drawing then
    local drawing = Lines.current_drawing
    if drawing.pending then
      if drawing.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        table.insert(drawing.shapes, drawing.pending)
      elseif drawing.pending.mode == 'line' then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          drawing.pending.p2 = Drawing.insert_point(drawing.points, mx,my)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'manhattan' then
        local p1 = drawing.points[drawing.pending.p1]
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            drawing.pending.p2 = Drawing.insert_point(drawing.points, mx, p1.y)
          else
            drawing.pending.p2 = Drawing.insert_point(drawing.points, p1.x, my)
          end
          local p2 = drawing.points[drawing.pending.p2]
          App.mouse_move(Margin_left+Drawing.pixels(p2.x), drawing.y+Drawing.pixels(p2.y))
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'rectangle' then
        assert(#drawing.pending.vertices <= 2)
        if #drawing.pending.vertices == 2 then
          local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
          if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
            local first = drawing.points[drawing.pending.vertices[1]]
            local second = drawing.points[drawing.pending.vertices[2]]
            local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
            table.insert(drawing.pending.vertices, Drawing.insert_point(drawing.points, thirdx,thirdy))
            table.insert(drawing.pending.vertices, Drawing.insert_point(drawing.points, fourthx,fourthy))
            table.insert(drawing.shapes, drawing.pending)
          end
        else
          -- too few points; draw nothing
        end
      elseif drawing.pending.mode == 'polygon' then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        drawing.pending.p1 = Drawing.insert_point(drawing.points, mx,my)
        table.insert(drawing.shapes, drawing.pending)
      elseif drawing.pending.mode == 'circle' then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.radius = geom.dist(center.x,center.y, mx,my)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'arc' then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, drawing.pending.end_angle)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'name' then
        -- drop it
      else
        print(drawing.pending.mode)
        assert(false)
      end
      Lines.current_drawing.pending = {}
      Lines.current_drawing = nil
    end
  end
end

function Drawing.keychord_pressed(chord)
  if chord == 'C-p' and not App.mouse_down(1) then
    Current_drawing_mode = 'freehand'
  elseif App.mouse_down(1) and chord == '2' then
    Current_drawing_mode = 'line'
    local _,drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-2' and not App.mouse_down(1) then
    Current_drawing_mode = 'line'
  elseif App.mouse_down(1) and chord == 'm' then
    Current_drawing_mode = 'manhattan'
    local drawing = Drawing.select_drawing_at_mouse()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not App.mouse_down(1) then
    Current_drawing_mode = 'manhattan'
  elseif chord == 'C-r' and not App.mouse_down(1) then
    Current_drawing_mode = 'rectangle'
  elseif App.mouse_down(1) and chord == 'r' then
    Current_drawing_mode = 'rectangle'
    local _,drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'rectangle'
  elseif App.mouse_down(1) and chord == 'p' and Current_drawing_mode == 'rectangle' then
    local _,drawing = Drawing.current_drawing()
    local mx,my = Drawing.coord(App.mouse_x()-Margin_left), Drawing.coord(App.mouse_y()-drawing.y)
    local j = Drawing.insert_point(drawing.points, mx,my)
    while #drawing.pending.vertices >= 2 do
      table.remove(drawing.pending.vertices)
    end
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-3' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 3
  elseif chord == 'C-4' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 4
  elseif chord == 'C-5' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 5
  elseif chord == 'C-6' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 6
  elseif chord == 'C-7' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 7
  elseif chord == 'C-8' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 8
  elseif chord == 'C-9' and not App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 9
  elseif chord == '3' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 3
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '4' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 4
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '5' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 5
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '6' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 6
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '7' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 7
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '8' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 8
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == '9' and App.mouse_down(1) then
    Current_drawing_mode = 'polygon'
    Current_drawing_submode = 9
    Drawing.switch_current_drawing_pending_to_polygon()
  elseif chord == 'C-o' and not App.mouse_down(1) then
    Current_drawing_mode = 'circle'
  elseif App.mouse_down(1) and chord == 'a' and Current_drawing_mode == 'circle' then
    local _,drawing = Drawing.current_drawing()
    drawing.pending.mode = 'arc'
    local mx,my = Drawing.coord(App.mouse_x()-Margin_left), Drawing.coord(App.mouse_y()-drawing.y)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = geom.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = geom.angle(center.x,center.y, mx,my)
  elseif App.mouse_down(1) and chord == 'o' then
    Current_drawing_mode = 'circle'
    local _,drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' then
      -- reuse center
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif chord == 'C-u' and not App.mouse_down(1) then
    local drawing_index,drawing,i,p = Drawing.select_point_at_mouse()
    if drawing then
      if Previous_drawing_mode == nil then
        Previous_drawing_mode = Current_drawing_mode
      end
      Current_drawing_mode = 'move'
      drawing.pending = {mode=Current_drawing_mode, target_point=p, target_point_index=i}
      Lines.current_drawing_index = drawing_index
      Lines.current_drawing = drawing
    end
  elseif chord == 'C-n' and not App.mouse_down(1) then
    local drawing_index,drawing,point_index,p = Drawing.select_point_at_mouse()
    if drawing then
      if Previous_drawing_mode == nil then
        -- don't clobber
        Previous_drawing_mode = Current_drawing_mode
      end
      Current_drawing_mode = 'name'
      p.name = ''
      drawing.pending = {mode=Current_drawing_mode, target_point=point_index}
      Lines.current_drawing_index = drawing_index
      Lines.current_drawing = drawing
    end
  elseif chord == 'C-d' and not App.mouse_down(1) then
    local _,drawing,i,p = Drawing.select_point_at_mouse()
    if drawing then
      for _,shape in ipairs(drawing.shapes) do
        if Drawing.contains_point(shape, i) then
          shape.mode = 'deleted'
        end
      end
      drawing.points[i].deleted = true
    end
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not App.mouse_down(1) then
    local drawing = Drawing.select_drawing_at_mouse()
    if drawing then
      drawing.show_help = true
    end
  end
end

function Drawing.switch_current_drawing_pending_to_polygon()
  local _,drawing = Drawing.current_drawing()
  if drawing.pending.mode == 'freehand' then
    drawing.pending.center = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
  elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
    drawing.pending.center = drawing.pending.p1
  elseif drawing.pending.mode == 'rectangle' then
    drawing.pending.center = drawing.pending.vertices[1]
  elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
    -- reuse center
  end
  drawing.pending.mode = 'polygon'
  drawing.pending.num_vertices = Current_drawing_submode
end

function Drawing.complete_rectangle(firstx,firsty, secondx,secondy, x,y)
  if firstx == secondx then
    return x,secondy, x,firsty
  end
  if firsty == secondy then
    return secondx,y, firstx,y
  end
  local first_slope = (secondy-firsty)/(secondx-firstx)
  -- slope of second edge:
  --    -1/first_slope
  -- equation of line containing the second edge:
  --    y-secondy = -1/first_slope*(x-secondx)
  -- => 1/first_slope*x + y + (- secondy - secondx/first_slope) = 0
  -- now we want to find the point on this line that's closest to the mouse pointer.
  -- https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_an_equation
  local a = 1/first_slope
  local c = -secondy - secondx/first_slope
  local thirdx = ((x-a*y) - a*c) / (a*a + 1)
  local thirdy = (a*(-x + a*y) - c) / (a*a + 1)
  -- slope of third edge = first_slope
  -- equation of line containing third edge:
  --     y - thirdy = first_slope*(x-thirdx)
  --  => -first_slope*x + y + (-thirdy + thirdx*first_slope) = 0
  -- now we want to find the point on this line that's closest to the first point
  local a = -first_slope
  local c = -thirdy + thirdx*first_slope
  local fourthx = ((firstx-a*firsty) - a*c) / (a*a + 1)
  local fourthy = (a*(-firstx + a*firsty) - c) / (a*a + 1)
  return thirdx,thirdy, fourthx,fourthy
end

function Drawing.current_drawing()
  local x, y = App.mouse_x(), App.mouse_y()
  for drawing_index,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      if Drawing.in_drawing(drawing, x,y) then
        return drawing_index,drawing
      end
    end
  end
  return nil
end

function Drawing.select_shape_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y) then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        for i,shape in ipairs(drawing.shapes) do
          assert(shape)
          if geom.on_shape(mx,my, drawing, shape) then
            return drawing,i,shape
          end
        end
      end
    end
  end
end

function Drawing.select_point_at_mouse()
  for drawing_index,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y) then
        local mx,my = Drawing.coord(x-Margin_left), Drawing.coord(y-drawing.y)
        for i,point in ipairs(drawing.points) do
          assert(point)
          if Drawing.near(point, mx,my) then
            return drawing_index,drawing,i,point
          end
        end
      end
    end
  end
end

function Drawing.select_drawing_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y) then
        return drawing
      end
    end
  end
end

function Drawing.contains_point(shape, p)
  if shape.mode == 'freehand' then
    -- not supported
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    return shape.p1 == p or shape.p2 == p
  elseif shape.mode == 'rectangle' then
    return table.find(shape.vertices, p)
  elseif shape.mode == 'polygon' then
    return shape.center == p or shape.p1 == p
  elseif shape.mode == 'circle' then
    return shape.center == p
  elseif shape.mode == 'arc' then
    return shape.center == p
    -- ugh, how to support angles
  elseif shape.mode == 'deleted' then
    -- already done
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.insert_point(points, x,y)
  for i,point in ipairs(points) do
    if Drawing.near(point, x,y) then
      return i
    end
  end
  table.insert(points, {x=x, y=y})
  return #points
end

function Drawing.near(point, x,y)
  local px,py = Drawing.pixels(x),Drawing.pixels(y)
  local cx,cy = Drawing.pixels(point.x), Drawing.pixels(point.y)
  return (cx-px)*(cx-px) + (cy-py)*(cy-py) < Margin_left
end

function Drawing.pixels(n)  -- parts to pixels
  return math.floor(n*Line_width/256)
end
function Drawing.coord(n)  -- pixels to parts
  return math.floor(n*256/Line_width)
end

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end

return Drawing
