-- The magic bar shown in the game screen.

local hud_position = {}

function hud_position:new(game)

  local object = {}
  setmetatable(object, self)
  self.__index = self

  object:initialize(game)

  return object
end

function hud_position:initialize(game)

  self.game = game
  self.hero = game:get_hero()
  self.surface = sol.surface.create(128, 12)
  self.digits_text = sol.text_surface.create{
    font = "white_digits",
    horizontal_alignment = "left",
  }
  self.x, self.y, self.layer = self.hero:get_position()
  self.digits_text:set_text(self.x..", "..self.y..", "..self.layer)

  self:check()
  self:rebuild_surface()
end

-- Checks whether the view displays the correct info
-- and updates it if necessary.
function hud_position:check()

  -- Redraw the surface only if something has changed. 
  self.x, self.y, self.layer = self.hero:get_position() 
  self:rebuild_surface()

  -- Schedule the next check.
  sol.timer.start(self.game, 20, function()
    self:check()
  end)
end

function hud_position:rebuild_surface()

  self.surface:clear()

  -- Max magic.
  self.digits_text:set_text(self.x.." "..self.y.." "..self.layer)
  self.digits_text:draw(self.surface, 16, 5)
end

function hud_position:set_dst_position(x, y)
  self.dst_x = x
  self.dst_y = y
end

function hud_position:on_draw(dst_surface)

  local x, y = self.dst_x, self.dst_y
  local width, height = dst_surface:get_size()
  if x < 0 then
    x = width + x
  end
  if y < 0 then
    y = height + y
  end

  self.surface:draw(dst_surface, x, y)
end

return hud_position

