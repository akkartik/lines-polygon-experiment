-- primitives for saving to file and loading from file
function file_exists(filename)
  local infile = App.open_for_reading(filename)
  if infile then
    infile:close()
    return true
  else
    return false
  end
end

function load_from_disk(State)
  local infile = App.open_for_reading(State.filename)
  State.lines = load_from_file(infile)
  if infile then infile:close() end
end

function load_from_file(infile)
  local result = {}
  if infile then
    local infile_next_line = infile:lines()  -- works with both Lua files and LÖVE Files (https://www.love2d.org/wiki/File)
    while true do
      local line = infile_next_line()
      if line == nil then break end
      if line == '```lines' then  -- inflexible with whitespace since these files are always autogenerated
        table.insert(result, load_drawing(infile_next_line))
      else
        table.insert(result, {mode='text', data=line})
      end
    end
  end
  if #result == 0 then
    table.insert(result, {mode='text', data=''})
  end
  return result
end

function save_to_disk(State)
  local outfile = App.open_for_writing(State.filename)
  if outfile == nil then
    error('failed to write to "'..State.filename..'"')
  end
  for _,line in ipairs(State.lines) do
    if line.mode == 'drawing' then
      store_drawing(outfile, line)
    else
      outfile:write(line.data)
      outfile:write('\n')
    end
  end
  outfile:close()
end

function load_drawing(infile_next_line)
  local drawing = {mode='drawing', h=256/2, points={}, shapes={}, pending={}}
  while true do
    local line = infile_next_line()
    assert(line)
    if line == '```' then break end
    local shape = json.decode(line)
    if shape.mode == 'freehand' then
      -- no changes needed
    elseif shape.mode == 'line' or shape.mode == 'manhattan' then
      local name = shape.p1.name
      shape.p1 = Drawing.find_or_insert_point(drawing.points, shape.p1.x, shape.p1.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p1].name = name
      name = shape.p2.name
      shape.p2 = Drawing.find_or_insert_point(drawing.points, shape.p2.x, shape.p2.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p2].name = name
    elseif shape.mode == 'rectangle' then
      for i,p in ipairs(shape.vertices) do
        local name = p.name
        shape.vertices[i] = Drawing.find_or_insert_point(drawing.points, p.x,p.y, --[[large width to minimize overlap]] 1600)
        drawing.points[shape.vertices[i]].name = name
      end
    elseif shape.mode == 'polygon' then
      local name = shape.center.name
      shape.center = Drawing.find_or_insert_point(drawing.points, shape.center.x,shape.center.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.center].name = name
      local name = shape.p1.name
      shape.p1 = Drawing.find_or_insert_point(drawing.points, shape.p1.x,shape.p1.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p1].name = name
    elseif shape.mode == 'circle' or shape.mode == 'arc' then
      local name = shape.center.name
      shape.center = Drawing.find_or_insert_point(drawing.points, shape.center.x,shape.center.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.center].name = name
    elseif shape.mode == 'deleted' then
      -- ignore
    else
      print(shape.mode)
      assert(false)
    end
    table.insert(drawing.shapes, shape)
  end
  return drawing
end

function store_drawing(outfile, drawing)
  outfile:write('```lines\n')
  for _,shape in ipairs(drawing.shapes) do
    if shape.mode == 'freehand' then
      outfile:write(json.encode(shape), '\n')
    elseif shape.mode == 'line' or shape.mode == 'manhattan' then
      local line = json.encode({mode=shape.mode, p1=drawing.points[shape.p1], p2=drawing.points[shape.p2]})
      outfile:write(line, '\n')
    elseif shape.mode == 'rectangle' then
      local obj = {mode=shape.mode, vertices={}}
      for _,p in ipairs(shape.vertices) do
        table.insert(obj.vertices, drawing.points[p])
      end
      local line = json.encode(obj)
      outfile:write(line, '\n')
    elseif shape.mode == 'polygon' then
      outfile:write(json.encode({mode=shape.mode, num_vertices=shape.num_vertices, center=drawing.points[shape.center], p1=drawing.points[shape.p1]}), '\n')
    elseif shape.mode == 'circle' then
      outfile:write(json.encode({mode=shape.mode, center=drawing.points[shape.center], radius=shape.radius}), '\n')
    elseif shape.mode == 'arc' then
      outfile:write(json.encode({mode=shape.mode, center=drawing.points[shape.center], radius=shape.radius, start_angle=shape.start_angle, end_angle=shape.end_angle}), '\n')
    elseif shape.mode == 'deleted' then
      -- ignore
    else
      print(shape.mode)
      assert(false)
    end
  end
  outfile:write('```\n')
end

-- for tests
function load_array(a)
  local result = {}
  local next_line = ipairs(a)
  local i,line,drawing = 0, ''
  while true do
    i,line = next_line(a, i)
    if i == nil then break end
--?     print(line)
    if line == '```lines' then  -- inflexible with whitespace since these files are always autogenerated
--?       print('inserting drawing')
      i, drawing = load_drawing_from_array(next_line, a, i)
--?       print('i now', i)
      table.insert(result, drawing)
    else
--?       print('inserting text')
      table.insert(result, {mode='text', data=line})
    end
  end
  if #result == 0 then
    table.insert(result, {mode='text', data=''})
  end
  return result
end

function load_drawing_from_array(iter, a, i)
  local drawing = {mode='drawing', h=256/2, points={}, shapes={}, pending={}}
  local line
  while true do
    i, line = iter(a, i)
    assert(i)
--?     print(i)
    if line == '```' then break end
    local shape = json.decode(line)
    if shape.mode == 'freehand' then
      -- no changes needed
    elseif shape.mode == 'line' or shape.mode == 'manhattan' then
      local name = shape.p1.name
      shape.p1 = Drawing.find_or_insert_point(drawing.points, shape.p1.x, shape.p1.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p1].name = name
      name = shape.p2.name
      shape.p2 = Drawing.find_or_insert_point(drawing.points, shape.p2.x, shape.p2.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p2].name = name
    elseif shape.mode == 'rectangle' then
      for i,p in ipairs(shape.vertices) do
        local name = p.name
        shape.vertices[i] = Drawing.find_or_insert_point(drawing.points, p.x,p.y, --[[large width to minimize overlap]] 1600)
        drawing.points[shape.vertices[i]].name = name
      end
    elseif shape.mode == 'polygon' then
      local name = shape.center.name
      shape.center = Drawing.find_or_insert_point(drawing.points, shape.center.x,shape.center.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.center].name = name
      local name = shape.p1.name
      shape.p1 = Drawing.find_or_insert_point(drawing.points, shape.p1.x,shape.p1.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.p1].name = name
    elseif shape.mode == 'circle' or shape.mode == 'arc' then
      local name = shape.center.name
      shape.center = Drawing.find_or_insert_point(drawing.points, shape.center.x,shape.center.y, --[[large width to minimize overlap]] 1600)
      drawing.points[shape.center].name = name
    elseif shape.mode == 'deleted' then
      -- ignore
    else
      print(shape.mode)
      assert(false)
    end
    table.insert(drawing.shapes, shape)
  end
  return i, drawing
end
