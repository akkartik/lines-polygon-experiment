-- main entrypoint for LÖVE
--
-- Most apps can just use the default, but we need to override it to
-- install a test harness.
--
-- A test harness needs to check what the 'real' code did.
-- To do this it needs to hook into primitive operations performed by code.
-- Our hooks all go through the `App` global. When running tests they operate
-- on fake screen, keyboard and so on. Once all tests pass, the App global
-- will hook into the real screen, keyboard and so on.
--
-- Scroll below this function for more details.
function love.run()
  -- Tests always run at the start.
  App.run_tests()

--?   print('==')
  App.disable_tests()
  if App.initialize_globals then App.initialize_globals() end
  if App.initialize then App.initialize(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end

  local dt = 0

  return function()
    if love.event then
      love.event.pump()
      for name, a,b,c,d,e,f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            return a or 0
          end
        end
        love.handlers[name](a,b,c,d,e,f)
      end
    end

    if love.timer then dt = love.timer.step() end

    if App.update then App.update(dt) end -- will pass 0 if love.timer is disabled

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if App.draw then App.draw() end

      love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end

-- I've been building LÖVE apps for a couple of months now, and often feel
-- stupid. I seem to have a smaller short-term memory than most people, and
-- LÖVE apps quickly grow to a point where I need longer and longer chunks of
-- focused time to make changes to them. The reason: I don't have a way to
-- write tests yet. So before I can change any piece of an app, I have to
-- bring into my head all the ways it can break. This isn't the case on other
-- platforms, where I can be productive in 5- or 10-minute increments. Because
-- I have tests.
--
-- Most test harnesses punt on testing I/O, and conventional wisdom is to test
-- business logic, not I/O. However, any non-trivial app does non-trivial I/O
-- that benefits from tests. And tests aren't very useful if it isn't obvious
-- after reading them what the intent is. Including the I/O allows us to write
-- tests that mimic how people use our program.
--
-- There's a major open research problem in testing I/O: how to write tests
-- for graphics. Pixel-by-pixel assertions get too verbose, and they're often
-- brittle because you don't care about the precise state of every last pixel.
-- Except when you do. Pixels are usually -- but not always -- the trees
-- rather than the forest.
--
-- I'm not in the business of doing research, so I'm going to shave off a
-- small subset of the problem for myself here: how to write tests about text
-- (ignoring font, color, etc.) on a graphic screen.
--
-- For example, here's how you may write a test of a simple text paginator
-- like `less`:
--   function test_paginator()
--     -- initialize environment
--     App.filesystem['/tmp/foo'] = filename([[
--       >abc
--       >def
--       >ghi
--       >jkl
--     ]])
--     App.args = {'/tmp/foo'}
--     -- define a screen with room for 2 lines of text
--     App.screen.init{
--       width=100
--       height=30
--     }
--     App.font.init{
--       height=15
--     }
--     -- check that screen shows next 2 lines of text after hitting pagedown
--     App.run_after_keychord('pagedown')
--     App.screen.check(0, 'ghi')
--     App.screen.check(15, 'jkl')
--   end
--
-- All functions starting with 'test_' (no modules) will run before the app
-- runs "for real". Each such test is a fake run of our entire program. It can
-- set as much of the environment as it wants, then run the app. Here we've
-- got a 30px screen and a 15px font, so the screen has room for 2 lines. The
-- file we're viewing has 4 lines. We assert that hitting the 'pagedown' key
-- shows the third and fourth lines.
--
-- Programs can still perform graphics, and all graphics will work in the real
-- program. We can't yet write tests for graphics, though. Those pixels are
-- basically always blank in tests. Really, there isn't even any
-- representation for them. All our fake screens know about is lines of text,
-- and what (x,y) coordinates they start at. There's some rudimentary support
-- for concatenating all blobs of text that start at the same 'y' coordinate,
-- but beware: text at y=100 is separate and non-overlapping with text at
-- y=101. You have to use the test harness within these limitations for your
-- tests to faithfully model the real world.
--
-- One drawback of this approach: the y coordinate used depends on font size,
-- which feels brittle.
--
-- In the fullness of time App will support all side-effecting primitives
-- exposed by LÖVE, but so far it supports just a rudimentary set of things I
-- happen to have needed so far.

App = {screen={}}

function App.initialize_for_test()
  App.screen.init({width=100, height=50})
  App.screen.contents = {}  -- clear screen
  App.filesystem = {}
  App.fake_key_pressed = {}
  App.fake_mouse_state = {x=-1, y=-1}
  if App.initialize_globals then App.initialize_globals() end
end

function App.screen.init(dims)
  App.screen.width = dims.width
  App.screen.height = dims.height
end

function App.screen.print(msg, x,y)
  local screen_row = 'y'..tostring(y)
--?   print('drawing "'..msg..'" at y '..tostring(y))
  local screen = App.screen
  if screen.contents[screen_row] == nil then
    screen.contents[screen_row] = {}
    for i=0,screen.width-1 do
      screen.contents[screen_row][i] = ''
    end
  end
  if x < screen.width then
    screen.contents[screen_row][x] = msg
  end
end

-- LÖVE's Text primitive retains no trace of the string it was created from,
-- so we'll wrap it for our tests.
--
-- This implies that we need to hook any operations we need on Text objects.
function App.newText(font, s)
  return {type='text', data=s, text=love.graphics.newText(font, s)}
end

function App.width(text)
  return text.text:getWidth()
end

function App.screen.draw(obj, x,y)
  if type(obj) == 'userdata' then
    -- ignore most things as graphics the test harness can't handle
  elseif obj.type == 'text' then
    App.screen.print(obj.data, x,y)
  else
    print(obj.type)
    assert(false)
  end
end

App.clipboard = ''
function App.getClipboardText()
  return App.clipboard
end
function App.setClipboardText(s)
  App.clipboard = s
end

App.fake_key_pressed = {}
function App.fake_key_press(key)
  App.fake_key_pressed[key] = true
end
function App.fake_key_release(key)
  App.fake_key_pressed[key] = nil
end
function App.modifier_down(key)
  return App.fake_key_pressed[key]
end

App.fake_mouse_state = {x=-1, y=-1}  -- x,y always set
function App.fake_mouse_press(x,y, button)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
  App.fake_mouse_state[button] = true
end
function App.fake_mouse_release(x,y, button)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
  App.fake_mouse_state[button] = nil
end
function App.mouse_move(x,y)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
end
function App.mouse_down(button)
  return App.fake_mouse_state[button]
end
function App.mouse_x()
  return App.fake_mouse_state.x
end
function App.mouse_y()
  return App.fake_mouse_state.y
end

function App.run_after_textinput(t)
  App.textinput(t)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_keychord(key)
  App.keychord_pressed(key)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_click(x,y, button)
  App.fake_mouse_press(x,y, button)
  App.mousepressed(x,y, button)
  App.fake_mouse_release(x,y, button)
  App.mousereleased(x,y, button)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_press(x,y, button)
  App.fake_mouse_press(x,y, button)
  App.mousepressed(x,y, button)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_release(x,y, button)
  App.fake_mouse_release(x,y, button)
  App.mousereleased(x,y, button)
  App.screen.contents = {}
  App.draw()
end

function App.screen.check(y, expected_contents, msg)
--?   print('checking for "'..expected_contents..'" at y '..tostring(y))
  local screen_row = 'y'..tostring(y)
  local contents = ''
  if App.screen.contents[screen_row] == nil then
    error('no text at y '..tostring(y))
  end
  for i,s in ipairs(App.screen.contents[screen_row]) do
    contents = contents..s
  end
  check_eq(contents, expected_contents, msg)
end

-- fake files
function App.open_for_writing(filename)
  App.filesystem[filename] = ''
  return {
    write = function(self, s)
              App.filesystem[filename] = App.filesystem[filename]..s
            end,
    close = function(self)
            end
  }
end

function App.run_tests()
  local sorted_names = {}
  for name,binding in pairs(_G) do
    if name:find('test_') == 1 then
      table.insert(sorted_names, name)
    end
  end
  table.sort(sorted_names)
  for _,name in ipairs(sorted_names) do
    App.initialize_for_test()
    _G[name]()
  end
  print()
  -- clean up all test methods
  for _,name in ipairs(sorted_names) do
    _G[name] = nil
  end
end

-- call this once all tests are run
-- can't run any tests after this
function App.disable_tests()
  -- have LÖVE delegate all handlers to App if they exist
  for name in pairs(love.handlers) do
    if App[name] then
      love.handlers[name] = App[name]
    end
  end

  -- test methods are disallowed outside tests
  App.screen.init = nil
  App.filesystem = nil
  App.run_after_textinput = nil
  App.run_after_keychord = nil
  App.keypress = nil
  App.keyrelease = nil
  App.fake_key_pressed = nil
  App.fake_key_press = nil
  App.fake_key_release = nil
  App.fake_mouse_state = nil
  App.fake_mouse_press = nil
  App.fake_mouse_release = nil
  -- other methods dispatch to real hardware
  App.screen.print = love.graphics.print
  App.newText = love.graphics.newText
  App.screen.draw = love.graphics.draw
  App.width = function(text) return text:getWidth() end
  App.open_for_writing = function(filename) return io.open(filename, 'w') end
  App.getClipboardText = love.system.getClipboardText
  App.setClipboardText = love.system.setClipboardText
  App.modifier_down = love.keyboard.isDown
  App.mouse_move = love.mouse.setPosition
  App.mouse_down = love.mouse.isDown
  App.mouse_x = love.mouse.getX
  App.mouse_y = love.mouse.getY
end
