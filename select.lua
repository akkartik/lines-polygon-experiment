-- helpers for selecting portions of text

local utf8 = require 'utf8'

-- Return any intersection of the region from Selection1 to Cursor1 (or
-- current mouse, if mouse is pressed; or recent mouse if mouse is pressed and
-- currently over a drawing) with the region between {line=line_index, pos=apos}
-- and {line=line_index, pos=bpos}.
-- apos must be less than bpos. However Selection1 and Cursor1 can be in any order.
-- Result: positions spos,epos between apos,bpos.
function Text.clip_selection(line_index, apos, bpos)
  if Selection1.line == nil then return nil,nil end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp
  if love.mouse.isDown('1') then
    maxl,maxp = Text.mouse_pos()
  else
    maxl,maxp = Cursor1.line,Cursor1.pos
  end
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- check if intervals are disjoint
  if line_index < minl then return nil,nil end
  if line_index > maxl then return nil,nil end
  if line_index == minl and bpos <= minp then return nil,nil end
  if line_index == maxl and apos >= maxp then return nil,nil end
  -- compare bounds more carefully (start inclusive, end exclusive)
  local a_ge = Text.le1({line=minl, pos=minp}, {line=line_index, pos=apos})
  local b_lt = Text.lt1({line=line_index, pos=bpos}, {line=maxl, pos=maxp})
--?   print(minl,line_index,maxl, '--', minp,apos,bpos,maxp, '--', a_ge,b_lt)
  if a_ge and b_lt then
    -- fully contained
    return apos,bpos
  elseif a_ge then
    assert(maxl == line_index)
    return apos,maxp
  elseif b_lt then
    assert(minl == line_index)
    return minp,bpos
  else
    assert(minl == maxl and minl == line_index)
    return minp,maxp
  end
end

-- draw highlight for line corresponding to (lo,hi) given an approximate x,y and pos on the same screen line
function Text.draw_highlight(line, x,y, pos, lo,hi)
  if lo then
    local lo_offset = utf8.offset(line.data, lo)
    local hi_offset = utf8.offset(line.data, hi)
    local pos_offset = utf8.offset(line.data, pos)
    local lo_px
    if pos == lo then
      lo_px = 0
    else
      local before = line.data:sub(pos_offset, lo_offset-1)
      local before_text = App.newText(love.graphics.getFont(), before)
      lo_px = App.width(before_text)
    end
--?     print(lo,pos,hi, '--', lo_offset,pos_offset,hi_offset, '--', lo_px)
    local s = line.data:sub(lo_offset, hi_offset-1)
    local text = App.newText(love.graphics.getFont(), s)
    local text_width = App.width(text)
    love.graphics.setColor(0.7,0.7,0.9)
    love.graphics.rectangle('fill', x+lo_px,y, text_width,Line_height)
    love.graphics.setColor(0,0,0)
  end
end

-- inefficient for some reason, so don't do it on every frame
function Text.mouse_pos()
  local time = love.timer.getTime()
  if Recent_mouse.time and Recent_mouse.time > time-0.1 then
    return Recent_mouse.line, Recent_mouse.pos
  end
  Recent_mouse.time = time
  local line,pos = Text.to_pos(love.mouse.getX(), love.mouse.getY())
  if line then
    Recent_mouse.line = line
    Recent_mouse.pos = pos
  end
  return Recent_mouse.line, Recent_mouse.pos
end

function Text.to_pos(x,y)
  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y) then
        return line_index, Text.to_pos_on_line(line, x,y)
      end
    end
  end
end

function Text.delete_selection()
  local minl,maxl = minmax(Selection1.line, Cursor1.line)
  local before = snapshot(minl, maxl)
  Text.delete_selection_without_undo()
  record_undo_event({before=before, after=snapshot(Cursor1.line)})
end

function Text.delete_selection_without_undo()
  if Selection1.line == nil then return end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp = Cursor1.line,Cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- update Cursor1 and Selection1
  Cursor1.line = minl
  Cursor1.pos = minp
  Selection1 = {}
  -- delete everything between min (inclusive) and max (exclusive)
  Lines[minl].fragments = nil
  Lines[minl].screen_line_starting_pos = nil
  local min_offset = utf8.offset(Lines[minl].data, minp)
  local max_offset = utf8.offset(Lines[maxl].data, maxp)
  if minl == maxl then
--?     print('minl == maxl')
    Lines[minl].data = Lines[minl].data:sub(1, min_offset-1)..Lines[minl].data:sub(max_offset)
    return
  end
  assert(minl < maxl)
  local rhs = Lines[maxl].data:sub(max_offset)
  for i=maxl,minl+1,-1 do
    table.remove(Lines, i)
  end
  Lines[minl].data = Lines[minl].data:sub(1, min_offset-1)..rhs
end

function Text.selection()
  if Selection1.line == nil then return end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp = Cursor1.line,Cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  local min_offset = utf8.offset(Lines[minl].data, minp)
  local max_offset = utf8.offset(Lines[maxl].data, maxp)
  if minl == maxl then
    return Lines[minl].data:sub(min_offset, max_offset-1)
  end
  assert(minl < maxl)
  local result = Lines[minl].data:sub(min_offset)..'\n'
  for i=minl+1,maxl-1 do
    if Lines[i].mode == 'text' then
      result = result..Lines[i].data..'\n'
    end
  end
  result = result..Lines[maxl].data:sub(1, max_offset-1)
  return result
end

function Text.cut_selection()
  local result = Text.selection()
  Text.delete_selection()
  return result
end
