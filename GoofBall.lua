--[[ GoofBall
     A distracting ball.

     { prev = { x = , y = },
       loc = { x =, y = },
       delta = { x =, y = },
       radius = N,
       immovable = false
     }
]]--

local addoninfo, gb = ...
gb.active = {}
gb.inactive = {}
gb.friction = .99
gb.diameter = 90
gb.tick_counter = 0
gb.gravity = true
gb.mouse_gravity = false
gb.use_brick = false
gb.points = 0
gb.default_timer = 250
gb.brick_timer = gb.default_timer

function gb.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function gb.diag(fmt, ...)
  if gb.tick_counter == 1 then
    gb.printf(fmt, ...)
  end
end

function gb.hypot(dx, dy)
  if not dy then
    dy = dx.y
    dx = dx.x
  end
  return math.sqrt(dx * dx + dy * dy)
end

function gb.dist(o1, o2)
  local dx = o1.loc.x - o2.loc.x
  local dy = o1.loc.y - o2.loc.y
  return gb.hypot(dx, dy)
end

function gb.normalize(vec)
  local len = gb.hypot(vec)
  if len == 0 then
    len = 0.1
  end
  return { x = vec.x / len, y = vec.y / len }
end

function gb.scale(vec, n)
  return { x = vec.x * n, y = vec.y * n }
end

function gb.direction(o1, o2)
  local vec = { x = o2.loc.x - o1.loc.x, y = o2.loc.y - o1.loc.y }
  return gb.normalize(vec)
end

function gb.add_vec(vec1, vec2, scale)
  scale = scale or 1
  vec1.x = vec1.x + vec2.x * scale
  vec1.y = vec1.y + vec2.y * scale
end

function gb.cap_delta(obj, scale, max)
  if scale then
    obj.delta = gb.scale(obj.delta, scale)
  end
  local velocity = gb.hypot(obj.delta)
  if velocity < 0 then
    velocity = 0.1
  end
  if velocity > (max * obj.radius) then
    obj.delta = gb.scale(obj.delta, (max * obj.radius) / velocity)
  end
end

function gb.collide(data)
  local o1 = gb.active[data[1]] or data[1]
  local o2 = gb.active[data[2]] or data[2]
  local dist = data[3]
  local wanted_dist = o1.radius + o2.radius
  -- if they're too close together, the first one gets nudged
  while dist < 0.01 do
    o1.loc.x = o1.loc.x + math.random(5) - 3
    o1.loc.y = o1.loc.y + math.random(5) - 3
    dist = gb.dist(o1, o2)
  end
  o1.velocity = gb.hypot(o1.delta)
  if o1.velocity == 0 then
    o1.velocity = 0.1
  end
  o2.velocity = gb.hypot(o2.delta)
  if o2.velocity == 0 then
    o2.velocity = 0.1
  end
  --[[ gb.diag("Collision: %s [%f] and %s [%f], distance %f",
  	tostring(o1.index), o1.velocity,
	tostring(o2.index), o2.velocity,
	dist) ]]--
  local bounce_scale = (wanted_dist - dist) / 2
  local o1_to_o2 = gb.direction(o1, o2)
  local o2_to_o1 = gb.direction(o2, o1)
  local o1_to_o2_scaled = gb.scale(o1_to_o2, bounce_scale)
  local o2_to_o1_scaled = gb.scale(o2_to_o1, bounce_scale)

  local bonus_velocity = (1 - (dist / wanted_dist)) * (o1.radius + o2.radius / 2)

  if o2.immovable then
    -- o1 gets all the movement.
    gb.move(o1, o2_to_o1_scaled)
    gb.move(o1, o2_to_o1_scaled)

    -- velocity change:  direction of o2->o1, velocity of o1.
    -- ... then add again so a bounce will reverse direction
    gb.add_vec(o1.delta, o2_to_o1, o1.velocity + bonus_velocity)
    gb.add_vec(o1.delta, o2_to_o1, o1.velocity + bonus_velocity)

    -- and impart some velocity from the mouse, if it's the immovable
    gb.add_vec(o1.delta, o2.delta, 0.5)

    -- scale to original velocity plus part of mouse velocity
    local new_velocity = gb.hypot(o1.delta)

    if new_velocity then
      gb.cap_delta(o1, (o1.velocity + o2.velocity / 2) / new_velocity, 1.5)
    else
      gb.cap_delta(o1, 1, 1.5)
    end

    --[[ gb.diag("Ball velocity %f, mouse velocity %f, total %f",
      o1.velocity, o2.velocity, gb.hypot(o1.delta)) ]]--
  else
    gb.move(o2, o1_to_o2_scaled)
    gb.move(o1, o2_to_o1_scaled)
    gb.add_vec(o1.delta, o2_to_o1_scaled, o2.velocity + bonus_velocity)
    gb.add_vec(o2.delta, o1_to_o2_scaled, o1.velocity + bonus_velocity)
    local speed_change = (o1.velocity + o2.velocity + bonus_velocity) / (gb.hypot(o1.delta) + gb.hypot(o2.delta))
    gb.cap_delta(o1, speed_change, 1.5)
    gb.cap_delta(o2, speed_change, 1.5)
    --[[ gb.diag("old: %f + %f = %f, speed_change: %f, new deltas %f + %f = %f",
    	o1.velocity, o2.velocity, o1.velocity + o2.velocity, speed_change,
	gb.hypot(o1.delta), gb.hypot(o2.delta),
	gb.hypot(o1.delta) + gb.hypot(o2.delta)) ]]--
  end
end

function gb.update()
  local mouse = Inspect.Mouse()
  local ball_hit_brick = false
  local mouse_hit_brick = false
  gb.tick_counter = gb.tick_counter + 1
  if gb.tick_counter == 10 then
    gb.tick_counter = 0
  end
  if not gb.mouse then
    return
  end
  -- hackery: The mouse's center is not the tip of the arrow.
  gb.mouse.loc.x = mouse.x + 5
  gb.mouse.loc.y = mouse.y + 5
  gb.mouse.delta.x = gb.mouse.loc.x - gb.mouse.prev.x
  gb.mouse.delta.y = gb.mouse.loc.y - gb.mouse.prev.y
  -- DO STUFF
  -- move
  for idx, obj in ipairs(gb.active) do
    gb.move(obj)
  end

  -- check for all collisions
  local maybe_collisions = 3

  --[[
  local before_speed = 0
  local after_speed = 0
  for idx, obj in ipairs(gb.active) do
    before_speed = before_speed + gb.hypot(obj.delta)
  end
  --]]

  while maybe_collisions and maybe_collisions > 0 do
    gb.collisions = {}
    for idx, obj in ipairs(gb.active) do
      for i = idx + 1, #gb.active do
	dist = gb.dist(obj, gb.active[i])
	if dist < (obj.radius + gb.active[i].radius) then
	  table.insert(gb.collisions, { idx, i, dist })
	end
      end
      dist = gb.dist(obj, gb.mouse)
      if dist < (obj.radius + gb.mouse.radius) then
	table.insert(gb.collisions, { idx, gb.mouse, dist })
      end
      if gb.use_brick then
	if gb.brick then
	  dist = gb.dist(obj, gb.brick)
	  if dist < (obj.radius + gb.brick.radius) then
	    table.insert(gb.collisions, { idx, gb.brick, dist })
	    ball_hit_brick = true
	  end
	end
      end
    end
    if gb.use_brick then
      if gb.brick then
	dist = gb.dist(gb.mouse, gb.brick)
	if dist < (gb.mouse.radius + gb.brick.radius) then
	  mouse_hit_brick = true
	end
      end
    end
    -- resolve each collision
    for _, coll in ipairs(gb.collisions) do
      gb.collide(coll)
    end
    -- if there were no collisions, we're done
    if #gb.collisions == 0 then
      maybe_collisions = false
    else
      maybe_collisions = maybe_collisions - 1
    end
  end
  --[[
  for idx, obj in ipairs(gb.active) do
    after_speed = after_speed + gb.hypot(obj.delta)
  end
  gb.diag("before: %f  after: %f", before_speed, after_speed)
  ]]--

  -- draw
  for idx, obj in ipairs(gb.active) do
    if obj.draw then
      obj.draw:SetPoint("CENTER", UIParent, "TOPLEFT", obj.loc.x, obj.loc.y)
      obj.draw:SetVisible(true)
    end
    if obj.shadow then
      obj.shadow:SetPoint("CENTER", UIParent, "TOPLEFT", obj.prev.x, obj.prev.y)
      obj.shadow:SetVisible(true)
    end
  end
  -- Finish up:
  if gb.use_brick then
    if mouse_hit_brick or ball_hit_brick then
      if ball_hit_brick then
	local active = #gb.active
	if active < 1 then
	  active = 1
	end
	gb.brick.points = math.floor(gb.brick.points / (active * active))
	gb.points = gb.points + gb.brick.points
	gb.printf("More dots!  %d DKP!  TOTAL SCORE: %d", gb.brick.points, gb.points)
      else
	gb.points = gb.points - 300
	gb.printf("Mouse hit brick!  300 DKP PENALTY!  TOTAL SCORE: %d", gb.points)
      end
      gb.brick.draw:SetVisible(false)
      gb.brick.shadow:SetVisible(false)
      gb.brick.text:SetVisible(false)
      gb.no_brick = gb.brick
      gb.brick = nil
      gb.brick_timer = gb.default_timer
    else
      if not gb.brick then
	if math.random(100) >= gb.brick_timer then
	  if gb.no_brick then
	    gb.brick = gb.no_brick
	    gb.no_brick = nil
	  else
	    gb.brick = gb.newbrick()
	  end
	  gb.brick.draw:SetVisible(true)
	  gb.brick.shadow:SetVisible(true)
	  gb.brick.points = 300
	  gb.brick.text:SetText(tostring(gb.brick.points))
	  local tries = 10
	  local collided = true
	  while collided and tries > 0 do
	    collided = false
	    local dist
	    
	    gb.brick.loc.x = math.random(gb.field.r - (gb.brick.radius * 2)) + gb.brick.radius
	    gb.brick.loc.y = math.random(gb.field.b - (gb.brick.radius * 2)) + gb.brick.radius
	    for idx, obj in ipairs(gb.active) do
	      dist = gb.dist(gb.brick, obj)
	      if obj.radius + gb.brick.radius > (dist / 1.2) then
	        collided = true
		break
	      end
	    end
	    dist = gb.dist(gb.brick, gb.mouse)
	    if gb.brick.radius + gb.mouse.radius > (dist / 1.2) then
	      collided = true
	    end
	    tries = tries - 1
	  end
	  if collided then
	    gb.printf("A brick peeks around the corner, then shyly wanders off.")
	  else
	    gb.brick.draw:SetPoint("CENTER", UIParent, "TOPLEFT", gb.brick.loc.x, gb.brick.loc.y)
	    gb.brick.shadow:SetPoint("CENTER", UIParent, "TOPLEFT", gb.brick.loc.x, gb.brick.loc.y)
	    gb.brick.draw:SetVisible(true)
	    gb.brick.shadow:SetVisible(true)
	    gb.brick.text:SetVisible(true)
	    gb.brick.text:SetPoint("CENTER", gb.brick.shadow, "CENTER")
	    gb.printf("A brick appears!")
	  end
	else
	  gb.brick_timer = gb.brick_timer - 1
	end
      else
	gb.brick.points = gb.brick.points - 1
	if gb.brick.points > 0 then
	  gb.brick.text:SetText(tostring(gb.brick.points))
	  gb.brick.text:SetPoint("CENTER", gb.brick.shadow, "CENTER")
	else
	  gb.printf("A brick dissipates harmlessly.")
	  gb.brick.draw:SetVisible(false)
	  gb.brick.shadow:SetVisible(false)
	  gb.brick.text:SetVisible(false)
	  gb.no_brick = gb.brick
	  gb.brick = nil
	  gb.brick_timer = gb.default_timer
	end
      end
    end
  end
  gb.mouse.prev.x = gb.mouse.loc.x
  gb.mouse.prev.y = gb.mouse.loc.y
end

function gb.move(obj, delta)
  local dist
  if not delta then
    obj.prev.x = obj.loc.x
    obj.prev.y = obj.loc.y
    obj.delta.x = obj.delta.x * gb.friction
    obj.delta.y = obj.delta.y * gb.friction
    if gb.gravity then
      obj.delta.y = obj.delta.y + 1
      gb.cap_delta(obj, 1, 1.3)
    end
    if gb.mouse_gravity then
      local mousewards = { x = gb.mouse.loc.x - obj.loc.x, y = gb.mouse.loc.y - obj.loc.y }
      gb.add_vec(obj.delta, gb.normalize(mousewards))
    end
    delta = obj.delta
  end

  obj.loc.x = obj.loc.x + delta.x
  obj.loc.y = obj.loc.y + delta.y
  if obj.loc.x - obj.radius - gb.field.l < 0 then
    delta.x = delta.x * -1
    obj.loc.x = obj.loc.x - 2 * (obj.loc.x - obj.radius - gb.field.l)
  end
  if obj.loc.x + obj.radius - gb.field.r > 0 then
    delta.x = delta.x * -1
    obj.loc.x = obj.loc.x - 2 * (obj.loc.x + obj.radius - gb.field.r)
  end
  if obj.loc.y - obj.radius - gb.field.t < 0 then
    delta.y = delta.y * -1
    obj.loc.y = obj.loc.y - 2 * (obj.loc.y - obj.radius - gb.field.t)
  end
  if obj.loc.y + obj.radius - gb.field.b > 0 then
    delta.y = delta.y * -1
    obj.loc.y = obj.loc.y - 2 * (obj.loc.y + obj.radius - gb.field.b)
  end
end

function gb.newbrick()
  local obj = gb.newobj()
  obj.points = 300
  obj.shadow:SetLayer(15)
  obj.text = UI.CreateFrame('Text', 'GoofBall', obj.shadow)
  obj.text:SetPoint("CENTER", obj.shadow, "CENTER")
  obj.text:SetFontSize(gb.diameter / 3)
  obj.shadow:SetAlpha(1)
  obj.immovable = true
  return obj
end

function gb.newobj(nodraw)
  local new
  if not nodraw and #gb.inactive > 0 then
    new = gb.inactive[1]
    table.remove(gb.inactive, 1)
  else
    new = {
      prev = { x = 0, y = 0 },
      loc = { x = 0, y = 0 },
      delta = { x = 0, y = 0 },
    }
    if nodraw then
      new.radius = 15
    else
      new.radius = 45
      -- local filename = string.format("ball%d.png", gb.ball_counter)
      -- gb.ball_counter = gb.ball_counter + 1
      -- if gb.ball_counter > 8 then
      --   gb.ball_counter = 0
      -- end
      local filename = 'ball.png'
      new.draw = UI.CreateFrame('Texture', 'GoofBall', gb.ui)
      new.shadow = UI.CreateFrame('Texture', 'GoofBall', gb.ui)
      new.draw:SetTexture('GoofBall', filename)
      new.draw:SetLayer(10)
      new.draw:SetMouseMasking('limited')
      new.shadow:SetTexture('GoofBall', filename)
      new.shadow:SetAlpha(0.4)
      new.shadow:SetMouseMasking('limited')
      gb.resize(new)
      new.shadow:SetLayer(5)
    end
  end
  gb.return_new = new
  return new
end

function gb.resize(object)
  if not object
    then return
  end
  if object.draw then
    object.draw:SetHeight(gb.diameter)
    object.draw:SetWidth(gb.diameter)
  end
  if object.shadow then
    object.shadow:SetHeight(gb.diameter)
    object.shadow:SetWidth(gb.diameter)
  end
  if object.text then
    object.text:SetFontSize(gb.diameter / 3)
  end
  object.radius = gb.diameter / 2
end

function gb.start()
  local event_index = nil
  gb.ui = gb.ui or UI.CreateContext("GoofBall")
  if not gb.ui then
    gb.printf("Couldn't create a UI context.")
    return
  end
  gb.ui:SetStrata('modal')
  if not gb.field then
    local l, t, r, b = UIParent:GetBounds()
    gb.field = { l = l, t = t, r = r, b = b }
    -- gb.printf("Bounds: %d, %d, %d, %d", l, t, r, b)
  end
  local ball = gb.newobj()
  ball.loc.x = (gb.field.l + gb.field.r) / 2
  ball.loc.y = (gb.field.t + gb.field.b) / 2
  ball.delta = { x = 0, y = 0 }
  if ball.draw then
    ball.draw:SetPoint("CENTER", UIParent, "TOPLEFT", ball.loc.x, ball.loc.y)
    ball.draw:SetVisible(true)
  end
  table.insert(gb.active, ball)
  ball.index = #gb.active
  if not gb.mouse then
    gb.mouse = gb.newobj(true)
    gb.mouse.immovable = true
    local mouse = Inspect.Mouse()
    gb.mouse.prev.x = mouse.x
    gb.mouse.prev.y = mouse.y
    gb.mouse.loc.x = mouse.x
    gb.mouse.loc.y = mouse.y
  end
  for idx, event in ipairs(Event.System.Update.Begin) do
    if event[1] == gb.update then
      event_index = idx
    end
  end
  if not event_index then
    table.insert(Event.System.Update.Begin, { gb.update, "GoofBall", "new frame" })
  end
end

function gb.deactivate(object)
  object.index = nil
  if object.draw then
    object.draw:SetVisible(false)
  end
  if object.shadow then
    object.shadow:SetVisible(false)
  end
end

function gb.stop()
  local event_index = nil
  for idx, event in ipairs(Event.System.Update.Begin) do
    if event[1] == gb.update then
      event_index = idx
    end
  end
  if event_index then
    table.remove(Event.System.Update.Begin, event_index)
  end

  for idx, object in ipairs(gb.active) do
    table.insert(gb.inactive, object)
    gb.deactivate(object)
  end
  if gb.use_brick then
    if gb.brick then
      gb.brick.draw:SetVisible(false)
      gb.brick.shadow:SetVisible(false)
      gb.brick.text:SetVisible(false)
      gb.brick.points = 0
      gb.no_brick = gb.brick
      gb.brick = nil
    end
  end
  gb.active = {}
end

function gb.slashcommand(args)
  local did_something = false
  if not args then
    return
  end
  if args.g then
    if gb.use_brick then
      gb.points = gb.points - 300
      gb.printf("Can't toggle gravity when in scoring mode!  CHEATER!  300 DKP MINUS!  TOTAL SCORE: %d", gb.points)
    else
      gb.gravity = not gb.gravity
      GoofBallSettings.gravity = gb.gravity
    end
    did_something = true
  end
  if args.m then
    if gb.use_brick then
      gb.points = gb.points - 300
      gb.printf("Can't toggle mouse gravity when in scoring mode!  CHEATER!  300 DKP MINUS!  TOTAL SCORE: %d", gb.points)
    else
      gb.mouse_gravity = not gb.mouse_gravity
      GoofBallSettings.mouse_gravity = gb.mouse_gravity
    end
    did_something = true
  end
  if args.a then
    if #gb.active > 25 then
      gb.printf("Not adding more balls.")
    else
      gb.start()
      GoofBallSettings.active = #gb.active
    end
    did_something = true
  end
  if args.b then
    gb.use_brick = not gb.use_brick
    GoofBallSettings.use_brick = gb.use_brick
    if gb.use_brick then
      gb.printf("LEEEEEROOY JENNNNKINNNNS.")
      gb.gravity = false
      gb.mouse_gravity = true
      gb.points = 0
    else
      gb.printf("Oh, no, tail swipe!  Game over, man!  TOTAL POINTS: %d", gb.points)
      gb.points = 0
      if gb.brick then
        gb.brick.draw:SetVisible(false)
        gb.brick.shadow:SetVisible(false)
        gb.brick.text:SetVisible(false)
        gb.no_brick = gb.brick
	gb.brick = nil
      end
    end
    did_something = true
  end
  if args.d then
    if #gb.active > 0 then
      local ball = gb.active[1]
      gb.deactivate(ball)
      table.insert(gb.inactive, ball)
      table.remove(gb.active, 1)
    end
    GoofBallSettings.active = #gb.active
    did_something = true
  end
  if args.f then
    if args.f > 100 then
      gb.printf("Friction must be 0 through 100.")
      gb.friction = .9
    elseif args.f < 0 then
      gb.printf("Friction must be 0 through 100.")
      gb.friction = 0
    else
      gb.friction = 1 - (args.f / 1000)
    end
    GoofBallSettings.friction = gb.friction
    did_something = true
  end
  if args.s then
    if args.s > 150 or args.s < 20 then
      gb.printf("Size must be between 20 and 150.")
    else
      GoofBallSettings.diameter = args.s
      gb.diameter = args.s
      for _, object in ipairs(gb.active) do
        gb.resize(object, args.s)
      end
      for _, object in ipairs(gb.inactive) do
        gb.resize(object)
      end
      if gb.use_brick then
	gb.resize(gb.brick)
	gb.resize(gb.no_brick)
      end
    end
    did_something = true
  end
  if not did_something then
    if #gb.active > 0 then
      gb.stop()
    else
      for i = 1, GoofBallSettings.active or 1 do
        gb.start()
      end
    end
  end
end

function gb.startup()
  if gb.use_brick then
    gb.gravity = false
    gb.mouse_gravity = true
    GoofBallSettings.gravity = false
    GoofBallSettings.mouse_gravity = true
  end
  for i = 1, GoofBallSettings.active do
    gb.start()
  end
end

function gb.variables_loaded(addon)
  if addon == 'GoofBall' then
    if GoofBallSettings then
      gb.gravity = GoofBallSettings.gravity
      gb.mouse_gravity = GoofBallSettings.mouse_gravity
      gb.friction = GoofBallSettings.friction or .99
      gb.diameter = GoofBallSettings.diameter or 90
      gb.use_brick = GoofBallSettings.use_brick
    else
      GoofBallSettings = { use_brick = false, mouse_gravity = false, gravity = true, diameter = 90, active = 0, friction = .99 }
    end
  end
end

Library.LibGetOpt.makeslash("abdf#gms#", "GoofBall", "goofball", gb.slashcommand)

table.insert(Event.Addon.SavedVariables.Load.End, { gb.variables_loaded, "GoofBall", "variable loaded hook" })
table.insert(Event.Addon.Startup.End, { gb.startup, "GoofBall", "start goofball" })
