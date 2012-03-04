--[[ RiftPong
     A distracting ball.

]]--

local addoninfo, rp = ...
rp.diameter = 90
rp.radius = rp.diameter / 2

function rp.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function rp.hypot(dx, dy)
  return math.sqrt(dx * dx + dy * dy)
end

function rp.dist(o1, o2)
  if not o1.x or not o2.x or not o1.y or not o2.y then
    return 0
  end
  local dx = o1.x - o2.x
  local dy = o1.y - o2.y
  return rp.hypot(dx, dy)
end

function rp.velocitize(tab)
  if tab.x < 0 then
    tab.x = tab.x * -1
  end
  if tab.x > 1.2 then
    tab.x = 1.2
  end
  if tab.y < 0 then
    tab.y = tab.y * -1
  end
  if tab.y > 1.2 then
    tab.y = 1.2
  end
end

function rp.update()
  if not rp.active then
    return
  end
  if not rp.oldmouse then
    rp.oldmouse = Inspect.Mouse()
  end
  local mouse = Inspect.Mouse()
  local crash = rp.dist(mouse, rp.loc)
  local delta = { x = rp.delta.x, y = rp.delta.y }
  local velocity = { x = delta.x / rp.radius, y = delta.y / rp.radius }
  rp.velocitize(velocity)
  local mouse_velocity = { x = (mouse.x - rp.oldmouse.x) / rp.radius, y = (mouse.y - rp.oldmouse.y) / rp.radius }
  rp.velocitize(mouse_velocity)
  if crash < rp.radius then
    local bounce = (1 - (crash / rp.radius))
    local dx = rp.loc.x - mouse.x
    if dx < 1 and dx > -1 then
      dx = math.random(3) - 2
    end
    local dy = rp.loc.y - mouse.y
    if dy < 1 and dy > -1 then
      dy = math.random(3) - 2
    end
    if crash < 1 then
      crash = crash + 1
    end
    if crash + 1 > rp.radius then
      crash = rp.radius - 1
    end
    rp.printf("dx: %f, bounce: %f at velocity %f", dx, bounce, velocity.x)
    dx = dx * (bounce + mouse_velocity.x + velocity.x + 0.1)
    dy = dy * (bounce + mouse_velocity.y + velocity.y + 0.1)
    rp.delta.x = (rp.delta.x / 2) + dx
    rp.delta.y = (rp.delta.y / 2) + dy
    delta.x = rp.delta.x
    delta.y = rp.delta.y
    rp.printf("delta.x: %f", delta.x)
  end
  rp.loc.x = rp.loc.x + delta.x
  rp.loc.y = rp.loc.y + delta.y
  if rp.loc.x - rp.radius - rp.field.l < 0 then
    rp.delta.x = rp.delta.x * -1
    rp.loc.x = rp.loc.x - 2 * (rp.loc.x - rp.radius - rp.field.l)
  end
  if rp.loc.x + rp.radius - rp.field.r > 0 then
    rp.delta.x = rp.delta.x * -1
    rp.loc.x = rp.loc.x - 2 * (rp.loc.x + rp.radius - rp.field.r)
  end
  if rp.loc.y - rp.radius - rp.field.t < 0 then
    rp.delta.y = rp.delta.y * -1
    rp.loc.y = rp.loc.y - 2 * (rp.loc.y - rp.radius - rp.field.t)
  end
  if rp.loc.y + rp.radius - rp.field.b > 0 then
    rp.delta.y = rp.delta.y * -1
    rp.loc.y = rp.loc.y - 2 * (rp.loc.y + rp.radius - rp.field.b)
  end
  rp.delta.x = rp.delta.x * .99
  rp.delta.y = rp.delta.y * .99
  rp.ball:SetPoint("CENTER", UIParent, "TOPLEFT", rp.loc.x, rp.loc.y)
  rp.oldmouse = mouse
end

function rp.start()
  rp.oldmouse = Inspect.Mouse()
  table.insert(Event.System.Update.Begin, { rp.update, "RiftPong", "new frame" })
  rp.ui = rp.ui or UI.CreateContext("RiftPong")
  if not rp.ui then
    rp.printf("Couldn't create a UI context.")
    return
  end
  if not rp.ball then
    rp.ball = UI.CreateFrame('Texture', 'RiftPong', rp.ui)
    rp.ball:SetTexture('RiftPong', 'ball.png')
  end
  if not rp.field then
    local l, t, r, b = UIParent:GetBounds()
    rp.field = { l = l, t = t, r = r, b = b }
    rp.printf("Bounds: %d, %d, %d, %d", l, t, r, b)
  end
  rp.loc = { x = (rp.field.l + rp.field.r) / 2, y = (rp.field.t + rp.field.b) / 2 }
  rp.delta = { x = 0, y = 0 }
  rp.ball:SetPoint("CENTER", UIParent, "TOPLEFT", rp.loc.x, rp.loc.y)
  rp.ball:SetVisible(true)
  rp.active = 1
end

function rp.stop()
  if rp.ball then
    rp.ball:SetVisible(false)
  end
  rp.active = false
end

function rp.slashcommand()
  if rp.active then
    rp.stop()
  else
    rp.start()
  end
end

Library.LibGetOpt.makeslash("", "RiftPong", "riftpong", rp.slashcommand)

table.insert(Event.Addon.Startup.End, { rp.start, "RiftPong", "start pong" })
