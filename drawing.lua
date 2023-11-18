-- primitives for editing drawings
Drawing = {}
require 'drawing_tests'

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts.
function Drawing.draw(State, line_index, y)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  line_cache.starty = y
  local pmx,pmy = App.mouse_x(), App.mouse_y()
  if pmx < State.right and pmy > line_cache.starty and pmy < line_cache.starty+Drawing.pixels(line.h, State.width) then
    App.color(Icon_color)
    love.graphics.rectangle('line', State.left,line_cache.starty, State.width,Drawing.pixels(line.h, State.width))
    if icon[State.current_drawing_mode] then
      icon[State.current_drawing_mode](State.right-22, line_cache.starty+4)
    else
      icon[State.previous_drawing_mode](State.right-22, line_cache.starty+4)
    end

    if App.mouse_down(1) and love.keyboard.isDown('h') then
      draw_help_with_mouse_pressed(State, line_index)
      return
    end
  end

  if line.show_help then
    draw_help_without_mouse_pressed(State, line_index)
    return
  end

  local mx = Drawing.coord(pmx-State.left, State.width)
  local my = Drawing.coord(pmy-line_cache.starty, State.width)

  for _,shape in ipairs(line.shapes) do
    if geom.on_shape(mx,my, line, shape) then
      App.color(Focus_stroke_color)
    else
      App.color(Stroke_color)
    end
    Drawing.draw_shape(line, shape, line_cache.starty, State.left,State.right)
  end

  local function px(x) return Drawing.pixels(x, State.width)+State.left end
  local function py(y) return Drawing.pixels(y, State.width)+line_cache.starty end
  for i,p in ipairs(line.points) do
    if p.deleted == nil then
      if Drawing.near(p, mx,my, State.width) then
        App.color(Focus_stroke_color)
        love.graphics.circle('line', px(p.x),py(p.y), Same_point_distance)
      else
        App.color(Stroke_color)
        love.graphics.circle('fill', px(p.x),py(p.y), 2)
      end
      if p.name then
        -- TODO: clip
        local x,y = px(p.x)+5, py(p.y)+5
        love.graphics.print(p.name, x,y)
        if State.current_drawing_mode == 'name' and i == line.pending.target_point then
          -- create a faint red box for the name
          App.color(Current_name_background_color)
          local name_width
          if p.name == '' then
            name_width = App.width('m')
          else
            name_width = App.width(p.name)
          end
          love.graphics.rectangle('fill', x,y, name_width, State.line_height)
        end
      end
    end
  end
  App.color(Current_stroke_color)
  Drawing.draw_pending_shape(State, line, line_cache.starty, State.left,State.right)
end

function Drawing.draw_shape(drawing, shape, top, left,right)
  local width = right-left
  local function px(x) return Drawing.pixels(x, width)+left end
  local function py(y) return Drawing.pixels(y, width)+top end
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(px(prev.x),py(prev.y), px(point.x),py(point.y))
      end
      prev = point
    end
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    love.graphics.line(px(p1.x),py(p1.y), px(p2.x),py(p2.y))
  elseif shape.mode == 'rectangle' then
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(px(prev.x),py(prev.y), px(curr.x),py(curr.y))
      end
      prev = curr
    end
    -- close the loop
    local curr = drawing.points[shape.vertices[1]]
    love.graphics.line(px(prev.x),py(prev.y), px(curr.x),py(curr.y))
  elseif shape.mode == 'polygon' then
    local center = drawing.points[shape.center]
    local p1 = drawing.points[shape.p1]
    Drawing.draw_polygon(shape.num_vertices, px(center.x),py(center.y), px(p1.x),py(p1.y))
  elseif shape.mode == 'circle' then
    -- TODO: clip
    local center = drawing.points[shape.center]
    love.graphics.circle('line', px(center.x),py(center.y), Drawing.pixels(shape.radius, width))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    love.graphics.arc('line', 'open', px(center.x),py(center.y), Drawing.pixels(shape.radius, width), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'deleted' then
    -- ignore
  else
    assert(false, ('unknown drawing mode %s'):format(shape.mode))
  end
end

function Drawing.draw_pending_shape(State, drawing, top, left,right)
  local width = right-left
  local pmx,pmy = App.mouse_x(), App.mouse_y()
  local function px(x) return Drawing.pixels(x, width)+left end
  local function py(y) return Drawing.pixels(y, width)+top end
  local mx = Drawing.coord(pmx-left, width)
  local my = Drawing.coord(pmy-top, width)
  -- recreate pixels from coords to precisely mimic how the drawing will look
  -- after mouse_release
  pmx,pmy = px(mx), py(my)
  local shape = drawing.pending
  if shape.mode == nil then
    -- nothing pending
  elseif shape.mode == 'freehand' then
    local shape_copy = deepcopy(shape)
    Drawing.smoothen(shape_copy)
    Drawing.draw_shape(drawing, shape_copy, top, left,right)
  elseif shape.mode == 'line' then
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    love.graphics.line(px(p1.x),py(p1.y), pmx,pmy)
  elseif shape.mode == 'manhattan' then
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    if math.abs(mx-p1.x) > math.abs(my-p1.y) then
      love.graphics.line(px(p1.x),py(p1.y), pmx,     py(p1.y))
    else
      love.graphics.line(px(p1.x),py(p1.y), px(p1.x),pmy)
    end
  elseif shape.mode == 'rectangle' then
    local first = drawing.points[shape.vertices[1]]
    if #shape.vertices == 1 then
      love.graphics.line(px(first.x),py(first.y), pmx,pmy)
      return
    end
    local second = drawing.points[shape.vertices[2]]
    local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
    love.graphics.line(px(first.x),py(first.y), px(second.x),py(second.y))
    love.graphics.line(px(second.x),py(second.y), px(thirdx),py(thirdy))
    love.graphics.line(px(thirdx),py(thirdy), px(fourthx),py(fourthy))
    love.graphics.line(px(fourthx),py(fourthy), px(first.x),py(first.y))
  elseif shape.mode == 'polygon' then
    local center = drawing.points[shape.center]
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    Drawing.draw_polygon(State.current_drawing_submode, px(center.x),py(center.y), pmx,pmy)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local r = round(geom.dist(center.x, center.y, mx, my))
    local cx,cy = px(center.x), py(center.y)
    love.graphics.circle('line', cx,cy, Drawing.pixels(r, width))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    shape.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, shape.end_angle)
    local cx,cy = px(center.x), py(center.y)
    love.graphics.arc('line', 'open', cx,cy, Drawing.pixels(shape.radius, width), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'move' then
    -- nothing pending; changes are immediately committed
  elseif shape.mode == 'name' then
    -- nothing pending; changes are immediately committed
  else
    assert(false, ('unknown drawing mode %s'):format(shape.mode))
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

function Drawing.in_drawing(drawing, line_cache, x,y, left,right)
  if line_cache.starty == nil then return false end  -- outside current page
  local width = right-left
  return y >= line_cache.starty and y < line_cache.starty + Drawing.pixels(drawing.h, width) and x >= left and x < right
end

function Drawing.mouse_press(State, drawing_index, x,y, mouse_button)
  local drawing = State.lines[drawing_index]
  local line_cache = State.line_cache[drawing_index]
  local cx = Drawing.coord(x-State.left, State.width)
  local cy = Drawing.coord(y-line_cache.starty, State.width)
  if State.current_drawing_mode == 'freehand' then
    drawing.pending = {mode=State.current_drawing_mode, points={{x=cx, y=cy}}}
  elseif State.current_drawing_mode == 'line' or State.current_drawing_mode == 'manhattan' then
    local j = Drawing.find_or_insert_point(drawing.points, cx, cy, State.width)
    drawing.pending = {mode=State.current_drawing_mode, p1=j}
  elseif State.current_drawing_mode == 'rectangle' then
    local j = Drawing.find_or_insert_point(drawing.points, cx, cy, State.width)
    drawing.pending = {mode=State.current_drawing_mode, vertices={j}}
  elseif State.current_drawing_mode == 'polygon' then
    local j = Drawing.find_or_insert_point(drawing.points, cx, cy, State.width)
    drawing.pending = {mode=State.current_drawing_mode, num_vertices=State.current_drawing_submode, center=j}
  elseif State.current_drawing_mode == 'circle' then
    local j = Drawing.find_or_insert_point(drawing.points, cx, cy, State.width)
    drawing.pending = {mode=State.current_drawing_mode, center=j}
  elseif State.current_drawing_mode == 'move' then
    -- all the action is in mouse_release
  elseif State.current_drawing_mode == 'name' then
    -- nothing
  else
    assert(false, ('unknown drawing mode %s'):format(State.current_drawing_mode))
  end
end

-- a couple of operations on drawings need to constantly check the state of the mouse
function Drawing.update(State)
  if State.lines.current_drawing == nil then return end
  local drawing = State.lines.current_drawing
  local line_cache = State.line_cache[State.lines.current_drawing_index]
  if line_cache.starty == nil then
    -- some event cleared starty just this frame
    -- draw in this frame will soon set starty
    -- just skip this frame
    return
  end
  assert(drawing.mode == 'drawing', 'Drawing.update: line is not a drawing')
  local pmx, pmy = App.mouse_x(), App.mouse_y()
  local mx = Drawing.coord(pmx-State.left, State.width)
  local my = Drawing.coord(pmy-line_cache.starty, State.width)
  if App.mouse_down(1) then
    if Drawing.in_drawing(drawing, line_cache, pmx,pmy, State.left,State.right) then
      if drawing.pending.mode == 'freehand' then
        table.insert(drawing.pending.points, {x=mx, y=my})
      elseif drawing.pending.mode == 'move' then
        drawing.pending.target_point.x = mx
        drawing.pending.target_point.y = my
        Drawing.relax_constraints(drawing, drawing.pending.target_point_index)
      end
    end
  elseif State.current_drawing_mode == 'move' then
    if Drawing.in_drawing(drawing, line_cache, pmx, pmy, State.left,State.right) then
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

function Drawing.mouse_release(State, x,y, mouse_button)
  if State.current_drawing_mode == 'move' then
    State.current_drawing_mode = State.previous_drawing_mode
    State.previous_drawing_mode = nil
    if State.lines.current_drawing then
      State.lines.current_drawing.pending = {}
      State.lines.current_drawing = nil
    end
  elseif State.lines.current_drawing then
    local drawing = State.lines.current_drawing
    local line_cache = State.line_cache[State.lines.current_drawing_index]
    if drawing.pending then
      if drawing.pending.mode == nil then
        -- nothing pending
      elseif drawing.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        Drawing.smoothen(drawing.pending)
        table.insert(drawing.shapes, drawing.pending)
      elseif drawing.pending.mode == 'line' then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'manhattan' then
        local p1 = drawing.points[drawing.pending.p1]
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, mx, p1.y, State.width)
          else
            drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, p1.x, my, State.width)
          end
          local p2 = drawing.points[drawing.pending.p2]
          App.mouse_move(State.left+Drawing.pixels(p2.x, State.width), line_cache.starty+Drawing.pixels(p2.y, State.width))
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'rectangle' then
        assert(#drawing.pending.vertices <= 2, 'Drawing.mouse_release: rectangle has too many pending vertices')
        if #drawing.pending.vertices == 2 then
          local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
          if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
            local first = drawing.points[drawing.pending.vertices[1]]
            local second = drawing.points[drawing.pending.vertices[2]]
            local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, thirdx,thirdy, State.width))
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, fourthx,fourthy, State.width))
            table.insert(drawing.shapes, drawing.pending)
          end
        else
          -- too few points; draw nothing
        end
      elseif drawing.pending.mode == 'polygon' then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        drawing.pending.p1 = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
        table.insert(drawing.shapes, drawing.pending)
      elseif drawing.pending.mode == 'circle' then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.radius = round(geom.dist(center.x,center.y, mx,my))
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'arc' then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, drawing.pending.end_angle)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'name' then
        -- drop it
      else
        assert(false, ('unknown drawing mode %s'):format(drawing.pending.mode))
      end
      State.lines.current_drawing.pending = {}
      State.lines.current_drawing = nil
    end
  end
end

function Drawing.keychord_press(State, chord)
  if chord == 'C-p' and not App.mouse_down(1) then
    State.current_drawing_mode = 'freehand'
  elseif App.mouse_down(1) and chord == '2' then
    State.current_drawing_mode = 'line'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-2' and not App.mouse_down(1) then
    State.current_drawing_mode = 'line'
  elseif App.mouse_down(1) and chord == 'm' then
    State.current_drawing_mode = 'manhattan'
    local drawing = Drawing.select_drawing_at_mouse(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not App.mouse_down(1) then
    State.current_drawing_mode = 'manhattan'
  elseif chord == 'C-r' and not App.mouse_down(1) then
    State.current_drawing_mode = 'rectangle'
  elseif App.mouse_down(1) and chord == 'r' then
    State.current_drawing_mode = 'rectangle'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'rectangle'
  elseif App.mouse_down(1) and chord == 'p' and State.current_drawing_mode == 'rectangle' then
    local _,drawing,line_cache = Drawing.current_drawing(State)
    local mx,my = Drawing.coord(App.mouse_x()-State.left, State.width), Drawing.coord(App.mouse_y()-line_cache.starty, State.width)
    local j = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
    while #drawing.pending.vertices >= 2 do
      table.remove(drawing.pending.vertices)
    end
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-3' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 3
  elseif chord == 'C-4' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 4
  elseif chord == 'C-5' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 5
  elseif chord == 'C-6' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 6
  elseif chord == 'C-7' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 7
  elseif chord == 'C-8' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 8
  elseif chord == 'C-9' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 9
  elseif chord == '3' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 3
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '4' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 4
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '5' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 5
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '6' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 6
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '7' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 7
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '8' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 8
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == '9' and App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
    State.current_drawing_submode = 9
    Drawing.switch_current_drawing_pending_to_polygon(State)
  elseif chord == 'C-o' and not App.mouse_down(1) then
    State.current_drawing_mode = 'circle'
  elseif App.mouse_down(1) and chord == 'a' and State.current_drawing_mode == 'circle' then
    local _,drawing,line_cache = Drawing.current_drawing(State)
    drawing.pending.mode = 'arc'
    local mx,my = Drawing.coord(App.mouse_x()-State.left, State.width), Drawing.coord(App.mouse_y()-line_cache.starty, State.width)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = round(geom.dist(center.x,center.y, mx,my))
    drawing.pending.start_angle = geom.angle(center.x,center.y, mx,my)
  elseif App.mouse_down(1) and chord == 'o' then
    State.current_drawing_mode = 'circle'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' then
      -- reuse center
    elseif drawing.pending.mode == 'rectangle' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif chord == 'C-u' and not App.mouse_down(1) then
    local drawing_index,drawing,line_cache,i,p = Drawing.select_point_at_mouse(State)
    if drawing then
      if State.previous_drawing_mode == nil then
        State.previous_drawing_mode = State.current_drawing_mode
      end
      State.current_drawing_mode = 'move'
      drawing.pending = {mode=State.current_drawing_mode, target_point=p, target_point_index=i}
      State.lines.current_drawing_index = drawing_index
      State.lines.current_drawing = drawing
    end
  elseif chord == 'C-n' and not App.mouse_down(1) then
    local drawing_index,drawing,line_cache,point_index,p = Drawing.select_point_at_mouse(State)
    if drawing then
      if State.previous_drawing_mode == nil then
        -- don't clobber
        State.previous_drawing_mode = State.current_drawing_mode
      end
      State.current_drawing_mode = 'name'
      p.name = ''
      drawing.pending = {mode=State.current_drawing_mode, target_point=point_index}
      State.lines.current_drawing_index = drawing_index
      State.lines.current_drawing = drawing
    end
  elseif chord == 'C-d' and not App.mouse_down(1) then
    local _,drawing,_,i,p = Drawing.select_point_at_mouse(State)
    if drawing then
      for _,shape in ipairs(drawing.shapes) do
        if Drawing.contains_point(shape, i) then
          shape.mode = 'deleted'
        end
      end
      drawing.points[i].deleted = true
    end
    local drawing,_,_,shape = Drawing.select_shape_at_mouse(State)
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not App.mouse_down(1) then
    local drawing = Drawing.select_drawing_at_mouse(State)
    if drawing then
      drawing.show_help = true
    end
  elseif chord == 'escape' and App.mouse_down(1) then
    local _,drawing = Drawing.current_drawing(State)
    drawing.pending = {}
  end
end

function Drawing.switch_current_drawing_pending_to_polygon(State)
  local _,drawing = Drawing.current_drawing(State)
  if drawing.pending.mode == 'freehand' then
    drawing.pending.center = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
  elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
    drawing.pending.center = drawing.pending.p1
  elseif drawing.pending.mode == 'rectangle' then
    drawing.pending.center = drawing.pending.vertices[1]
  elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
    -- reuse center
  end
  drawing.pending.mode = 'polygon'
  drawing.pending.num_vertices = State.current_drawing_submode
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
  local thirdx = round(((x-a*y) - a*c) / (a*a + 1))
  local thirdy = round((a*(-x + a*y) - c) / (a*a + 1))
  -- slope of third edge = first_slope
  -- equation of line containing third edge:
  --     y - thirdy = first_slope*(x-thirdx)
  --  => -first_slope*x + y + (-thirdy + thirdx*first_slope) = 0
  -- now we want to find the point on this line that's closest to the first point
  local a = -first_slope
  local c = -thirdy + thirdx*first_slope
  local fourthx = round(((firstx-a*firsty) - a*c) / (a*a + 1))
  local fourthy = round((a*(-firstx + a*firsty) - c) / (a*a + 1))
  return thirdx,thirdy, fourthx,fourthy
end

function Drawing.current_drawing(State)
  local x, y = App.mouse_x(), App.mouse_y()
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local line_cache = State.line_cache[drawing_index]
      if Drawing.in_drawing(drawing, line_cache, x,y, State.left,State.right) then
        return drawing_index,drawing,line_cache
      end
    end
  end
  return nil
end

function Drawing.select_shape_at_mouse(State)
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      local line_cache = State.line_cache[drawing_index]
      if Drawing.in_drawing(drawing, line_cache, x,y, State.left,State.right) then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        for i,shape in ipairs(drawing.shapes) do
          if geom.on_shape(mx,my, drawing, shape) then
            return drawing,line_cache,i,shape
          end
        end
      end
    end
  end
end

function Drawing.select_point_at_mouse(State)
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      local line_cache = State.line_cache[drawing_index]
      if Drawing.in_drawing(drawing, line_cache, x,y, State.left,State.right) then
        local mx,my = Drawing.coord(x-State.left, State.width), Drawing.coord(y-line_cache.starty, State.width)
        for i,point in ipairs(drawing.points) do
          if Drawing.near(point, mx,my, State.width) then
            return drawing_index,drawing,line_cache,i,point
          end
        end
      end
    end
  end
end

function Drawing.select_drawing_at_mouse(State)
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      local line_cache = State.line_cache[drawing_index]
      if Drawing.in_drawing(drawing, line_cache, x,y, State.left,State.right) then
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
    assert(false, ('unknown drawing mode %s'):format(shape.mode))
  end
end

function Drawing.smoothen(shape)
  assert(shape.mode == 'freehand', 'can only smoothen freehand shapes')
  for _=1,7 do
    for i=2,#shape.points-1 do
      local a = shape.points[i-1]
      local b = shape.points[i]
      local c = shape.points[i+1]
      b.x = round((a.x + b.x + c.x)/3)
      b.y = round((a.y + b.y + c.y)/3)
    end
  end
end

function round(num)
  return math.floor(num+.5)
end

function Drawing.find_or_insert_point(points, x,y, width)
  -- check if UI would snap the two points together
  for i,point in ipairs(points) do
    if Drawing.near(point, x,y, width) then
      return i
    end
  end
  table.insert(points, {x=x, y=y})
  return #points
end

function Drawing.near(point, x,y, width)
  local px,py = Drawing.pixels(x, width),Drawing.pixels(y, width)
  local cx,cy = Drawing.pixels(point.x, width), Drawing.pixels(point.y, width)
  return (cx-px)*(cx-px) + (cy-py)*(cy-py) < Same_point_distance*Same_point_distance
end

function Drawing.pixels(n, width)  -- parts to pixels
  return math.floor(n*width/256)
end
function Drawing.coord(n, width)  -- pixels to parts
  return math.floor(n*256/width)
end

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end
