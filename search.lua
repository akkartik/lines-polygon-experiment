-- helpers for the search bar (C-f)

function Text.draw_search_bar(State)
  local h = State.line_height+2
  local y = App.screen.height-h
  love.graphics.setColor(0.9,0.9,0.9)
  love.graphics.rectangle('fill', 0, y-10, App.screen.width-1, h+8)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.line(0, y-10, App.screen.width-1, y-10)
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle('fill', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.rectangle('line', 20, y-6, App.screen.width-40, h+2, 2,2)
  App.color(Text_color)
  App.screen.print(State.search_term, 25,y-5)
  App.color(Cursor_color)
  if State.search_text == nil then
    State.search_text = App.newText(love.graphics.getFont(), State.search_term)
  end
  love.graphics.circle('fill', 25+App.width(State.search_text),y-5+h, 2)
  App.color(Text_color)
end

function Text.search_next(State)
  -- search current line
  local pos = State.lines[State.cursor1.line].data:find(State.search_term, State.cursor1.pos)
  if pos then
    State.cursor1.pos = pos
  end
  if pos == nil then
    for i=State.cursor1.line+1,#State.lines do
      pos = State.lines[i].data:find(State.search_term)
      if pos then
        State.cursor1.line = i
        State.cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=1,State.cursor1.line-1 do
      pos = State.lines[i].data:find(State.search_term)
      if pos then
        State.cursor1.line = i
        State.cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(State.screen_bottom1, State.cursor1) then
    State.screen_top1.line = State.cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line(State, State.left, State.right)
    State.screen_top1.pos = pos
  end
end

function Text.search_previous(State)
  -- search current line
  local pos = rfind(State.lines[State.cursor1.line].data, State.search_term, State.cursor1.pos)
  if pos then
    State.cursor1.pos = pos
  end
  if pos == nil then
    for i=State.cursor1.line-1,1,-1 do
      pos = rfind(State.lines[i].data, State.search_term)
      if pos then
        State.cursor1.line = i
        State.cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=#State.lines,State.cursor1.line+1,-1 do
      pos = rfind(State.lines[i].data, State.search_term)
      if pos then
        State.cursor1.line = i
        State.cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(State.screen_bottom1, State.cursor1) then
    State.screen_top1.line = State.cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line(State, State.left, State.right)
    State.screen_top1.pos = pos
  end
end

function rfind(s, pat, i)
  local rs = s:reverse()
  local rpat = pat:reverse()
  if i == nil then i = #s end
  local ri = #s - i + 1
  local rendpos = rs:find(rpat, ri)
  if rendpos == nil then return nil end
  local endpos = #s - rendpos + 1
  assert (endpos >= #pat)
  return endpos-#pat+1
end
