function love.load()
    -- import libraries 
    sti = require 'libraries/sti'
    camera = require 'libraries/camera'
    wf = require 'libraries/windfield'

    -- disable blur  
    love.graphics.setDefaultFilter('nearest', 'nearest')
    
    -- Game state
    gameState = "menu" -- "menu", "playing", "gameover"
    
    -- Load sounds
    sounds = {}
    sounds.gunshot = love.audio.newSource("sound/gun-shot.mp3", "static")
    sounds.walking = love.audio.newSource("sound/walking.mp3", "static")
    sounds.item = love.audio.newSource("sound/item.mp3", "static")
    sounds.music = love.audio.newSource("sound/the-return-of-the-8-bit-era.mp3", "stream")
    
    -- Set walking sound to loop
    sounds.walking:setLooping(true)
    sounds.music:setLooping(true)
    
    -- Walking sound state
    isWalking = false
    
    -- Start button
    startButton = {}
    startButton.sprite = love.graphics.newImage('sprite/button/sprite_0.png')
    startButton.x = love.graphics.getWidth() / 2
    startButton.y = love.graphics.getHeight() / 2
    startButton.width = startButton.sprite:getWidth()
    startButton.height = startButton.sprite:getHeight()
    
    -- Menu background
    menuBackground = love.graphics.newImage('sprite/screen/screen_0.jpg')

    -- libraries function
    gameMap = sti('map/Map.lua')
    world = wf.newWorld(0, 0)
    cam = camera()

    initializeGame()
end

function initializeGame()
    -- player parameter
    player = {}
    player.collider = world:newCircleCollider(620, 620, 16)
    player.collider:setFixedRotation(true)
    player.x = 620
    player.y = 620
    player.speed = 300
    player.scale = 1
    player.spriteSheet = love.graphics.newImage('sprite/player/sprite_0.png')

    player.detectionRadius = 320
    player.sensor = world:newCircleCollider(player.x, player.y, player.detectionRadius)
    player.sensor:setSensor(true) 

    -- Hunger system
    player.hunger = 100
    player.maxHunger = 100
    player.hungerRate = 5
    player.isAlive = true
    player.deathReason = "starved" -- Track death reason
    player.zombiesKilled = 0 -- Kill counter
    
    -- zombies parameter
    zombies = {}
    if gameMap.layers["Zombies_Object"] then
        for _, obj in pairs(gameMap.layers["Zombies_Object"].objects) do
            local zombie = {}
            zombie.x = obj.x
            zombie.y = obj.y
            zombie.speed = 100
            zombie.follow = false
            zombie.hits = 0
            zombie.spriteSheet = love.graphics.newImage('sprite/zombies/sprite_0.png')

            zombie.collider = world:newCircleCollider(zombie.x, zombie.y, 16)
            zombie.collider:setFixedRotation(true)

           table.insert(zombies, zombie)
           end
    end

    -- player hand parameter
    hand = {}
    hand.spriteFree = love.graphics.newImage("sprite/hand/sprite_0.png")
    hand.spriteGun = love.graphics.newImage("sprite/hand/sprite_1.png")
    hand.currentSprite = hand.spriteFree
    hand.offset = 30     
    hand.angle = 0    
    hand.hasGun = false  -- Track gun state separately

    -- bullets parameter
    bullets = {}
    bulletSpeed = 500
    bulletCooldown = 0.1
    bulletTimer = 0

    -- food parameter 
    foodSprites = {
        love.graphics.newImage("sprite/items/sprite_0.png"),
        love.graphics.newImage("sprite/items/sprite_1.png"),
        love.graphics.newImage("sprite/items/sprite_2.png"),
        love.graphics.newImage("sprite/items/sprite_3.png")
    }

    -- All items on map
    items = {}

    if gameMap.layers["Items_Object"] then
        for _, obj in pairs(gameMap.layers["Items_Object"].objects) do
            local item = {
            x = obj.x,
            y = obj.y,
            sprite = foodSprites[math.random(1, #foodSprites)],
            collected = false
        }
        table.insert(items, item)
        end
    end

    -- walls parameter
    Blocks = {}
    if gameMap.layers["Wall_Object"] then
        for i, obj in pairs(gameMap.layers["Wall_Object"].objects) do
            local block = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            block:setType('static')
            table.insert(Blocks, block)
        end
    end
    
    isWalking = false
    sounds.walking:stop()
end

function love.update(dt)
    if gameState == "menu" then
        return
    elseif gameState == "gameover" then
        return
    end

    if not player.isAlive then 
        gameState = "gameover"
        -- Stop walking sound when player dies
        sounds.walking:stop()
        isWalking = false
        return 
    end -- Stop all logic if player is dead

    -- Player control
    local vx, vy = 0, 0
    player.sensor:setPosition(player.x, player.y)

    local wasWalking = isWalking
    isWalking = false

    if love.keyboard.isDown("left") then 
        vx = -player.speed 
        isWalking = true
    end
    if love.keyboard.isDown("right") then 
        vx = player.speed 
        isWalking = true
    end
    if love.keyboard.isDown("up") then 
        vy = -player.speed 
        isWalking = true
    end
    if love.keyboard.isDown("down") then 
        vy = player.speed 
        isWalking = true
    end

    -- Handle walking sound
    if isWalking and not wasWalking then
        sounds.walking:play()
    elseif not isWalking and wasWalking then
        sounds.walking:stop()
    end

    player.collider:setLinearVelocity(vx, vy)

    -- Update player position first
    player.x = player.collider:getX()
    player.y = player.collider:getY()

    -- Zombie movement
    for _, zombie in ipairs(zombies) do
        local dx = player.x - zombie.collider:getX()
        local dy = player.y - zombie.collider:getY()
        local distance = math.sqrt(dx * dx + dy * dy)

        zombie.follow = distance <= player.detectionRadius

        if zombie.follow then
            local dirX = dx / distance
            local dirY = dy / distance
            zombie.collider:setLinearVelocity(dirX * zombie.speed, dirY * zombie.speed)
        else
            zombie.collider:setLinearVelocity(0, 0)
        end

        zombie.x = zombie.collider:getX()
        zombie.y = zombie.collider:getY()
    end

    for _, zombie in ipairs(zombies) do
        local dx = player.x - zombie.x
        local dy = player.y - zombie.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 32 then
            player.isAlive = false
            player.deathReason = "eaten"
            sounds.walking:stop()
            isWalking = false
            return -- Exit immediately when player dies
        end
    end

    -- Hand rotation + position 
    local mx, my = cam:worldCoords(love.mouse.getPosition())
    local dx = mx - player.x
    local dy = my - player.y
    hand.angle = math.atan2(dy, dx)
    hand.x = player.x + math.cos(hand.angle) * hand.offset
    hand.y = player.y + math.sin(hand.angle) * hand.offset

    -- bullet timer
    if bulletTimer > 0 then
        bulletTimer = bulletTimer - dt
    end

    -- Bullet spawning (machine gun effect)
    if love.mouse.isDown(1) and hand.hasGun and bulletTimer <= 0 then
        table.insert(bullets, {
            x = hand.x,
            y = hand.y,
            angle = hand.angle,
            speed = bulletSpeed
        })
        bulletTimer = bulletCooldown
        -- Play gunshot sound
        sounds.gunshot:play()
    end

    -- Bullet movement + collision
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = bullet.x + math.cos(bullet.angle) * bullet.speed * dt
        bullet.y = bullet.y + math.sin(bullet.angle) * bullet.speed * dt

        -- Remove bullet if far from player
        local bdx = bullet.x - player.x
        local bdy = bullet.y - player.y
        if math.sqrt(bdx * bdx + bdy * bdy) > 1000 then
            table.remove(bullets, i)
        else
            -- Check wall collision
            local hitWall = false
            for _, block in ipairs(Blocks) do
                local left, top, right, bottom = block:getBoundingBox()
                if bullet.x > left and bullet.x < right and bullet.y > top and bullet.y < bottom then
                    hitWall = true
                    break
                end
            end

            if hitWall then
                table.remove(bullets, i)
            else
                -- Check zombie collision
                for j = #zombies, 1, -1 do
                    local zombie = zombies[j]
                    local dx = bullet.x - zombie.x
                    local dy = bullet.y - zombie.y
                    local distance = math.sqrt(dx * dx + dy * dy)

                    if distance < 16 then
                        zombie.hits = zombie.hits + 1
                        if zombie.hits >= 3 then
                            zombie.collider:destroy()
                            table.remove(zombies, j)
                            player.zombiesKilled = player.zombiesKilled + 1 -- Increment kill counter
                        end
                        table.remove(bullets, i)
                        break
                    end
                end
            end
        end
    end

    -- Hunger system
    player.hunger = player.hunger - player.hungerRate * dt
    if player.hunger <= 0 then
        player.hunger = 0
        player.isAlive = false
        player.deathReason = "starved"
        sounds.walking:stop()
        isWalking = false
        return -- Exit immediately when player dies
    end

    -- Check for item collisions
    for _, item in ipairs(items) do
        if not item.collected then
            local dx = player.x - item.x
            local dy = player.y - item.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < 20 then
                item.collected = true
                player.hunger = player.maxHunger
                sounds.item:play()
            end
        end
    end

    -- Physics + camera
    world:update(dt)
    cam:lookAt(player.x, player.y)

    -- Clamp camera to map
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    if cam.x < w/2 then cam.x = w/2 end
    if cam.y < h/2 then cam.y = h/2 end
    if cam.x > (mapW - w/2) then cam.x = (mapW - w/2) end
    if cam.y > (mapH - h/2) then cam.y = (mapH - h/2) end
end


function love.draw()
    if gameState == "menu" then
        -- Draw menu background
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(menuBackground, 0, 0, 0, 
            love.graphics.getWidth() / menuBackground:getWidth(), 
            love.graphics.getHeight() / menuBackground:getHeight())
                
        -- Draw start button
        love.graphics.draw(startButton.sprite, startButton.x, startButton.y, 0, 1, 1, startButton.width/2, startButton.height/2)
        return
    elseif gameState == "gameover" then
        -- Draw game over screen
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        local reason = "GAME OVER"
        if player.deathReason == "starved" then
           reason = "GAME OVER"
        elseif player.deathReason == "eaten" then
           reason = "GAME OVER"
        end

        love.graphics.setColor(1, 0, 0)
        love.graphics.printf(reason, 0, love.graphics.getHeight()/2 - 80, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Final Score: " .. player.zombiesKilled .. " zombies killed", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
        love.graphics.printf("Click to restart or press R", 0, startButton.y + 60, love.graphics.getWidth(), "center")
        return
    end

    -- Game playing state
    cam:attach() -- start the camera 
         -- draw map layers          
         gameMap:drawLayer(gameMap.layers["sea"])
         gameMap:drawLayer(gameMap.layers["sand"])
         gameMap:drawLayer(gameMap.layers["grass"])
         gameMap:drawLayer(gameMap.layers["grass_2"])
         gameMap:drawLayer(gameMap.layers["parking"])
         gameMap:drawLayer(gameMap.layers["building"])
         gameMap:drawLayer(gameMap.layers["port"])
         gameMap:drawLayer(gameMap.layers["border"])
         gameMap:drawLayer(gameMap.layers["deco"]) 
         -- draw food
         for _, item in ipairs(items) do
            if not item.collected then
                love.graphics.draw(item.sprite, item.x, item.y, 0, 1, 1, item.sprite:getWidth()/2, item.sprite:getHeight()/2)
            end
         end
         -- draw player (only if alive)
         if player.isAlive then
             love.graphics.draw(player.spriteSheet, player.x, player.y, 0, 1, 1, 16, 16)
         end
         -- draw zombies
         for _, zombie in ipairs(zombies) do 
             love.graphics.draw(zombie.spriteSheet, zombie.x, zombie.y, 0, 1, 1, 16, 16) 
         end
         -- draw hands (only if alive)
         if player.isAlive then
             love.graphics.draw(hand.currentSprite, hand.x, hand.y, hand.angle, 1, 1, hand.currentSprite:getWidth() / 2, hand.currentSprite:getHeight() / 2)
         end
         -- Draw bullets
         for _, bullet in ipairs(bullets) do
            local x1 = bullet.x
            local y1 = bullet.y
            local x2 = bullet.x + math.cos(bullet.angle) * 10
            local y2 = bullet.y + math.sin(bullet.angle) * 10
            love.graphics.setColor(1, 1, 0)
            love.graphics.setLineWidth(2)
            love.graphics.line(x1, y1, x2, y2)
         end
         
         love.graphics.setColor(1, 1, 1)
         love.graphics.setLineWidth(1)
    cam:detach()  -- stop it

    -- hunger bar
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Hunger: ", 20, 20)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", 100, 20, 200, 20)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 100, 20, (player.hunger / player.maxHunger) * 200, 20)
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Zombies Killed: " .. player.zombiesKilled, 20, 50)

    if not player.isAlive then
       local reason = "GAME OVER"
       if player.deathReason == "starved" then
          reason = "GAME OVER"
       elseif player.deathReason == "eaten" then
          reason = "GAME OVER"
       end

       love.graphics.setColor(1, 0, 0)
       love.graphics.printf(reason, 0, love.graphics.getHeight()/2 - 50, love.graphics.getWidth(), "center")
       love.graphics.printf("Final Score: " .. player.zombiesKilled .. " zombies killed", 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
       love.graphics.printf("Press R to restart", 0, love.graphics.getHeight()/2 + 10, love.graphics.getWidth(), "center")
       love.graphics.setColor(1, 1, 1)
    end
end 

-- mouse control 
function love.mousepressed(x, y, button)
    if gameState == "menu" then
        local dx = x - startButton.x
        local dy = y - startButton.y
        if math.abs(dx) < startButton.width/2 and math.abs(dy) < startButton.height/2 then
            gameState = "playing"
            sounds.music:play()
        end
        return
    elseif gameState == "gameover" then
        local dx = x - startButton.x
        local dy = y - startButton.y
        if math.abs(dx) < startButton.width/2 and math.abs(dy) < startButton.height/2 then
            initializeGame()
            gameState = "playing"
            sounds.music:play()
        end
        return
    end
    
    if not player.isAlive then return end 
    
    if button == 1 then -- left click
        hand.hasGun = not hand.hasGun
        if hand.hasGun then
            hand.currentSprite = hand.spriteGun
        else
            hand.currentSprite = hand.spriteFree
        end
    end
end

function love.keypressed(key)
    if key == "r" and gameState == "gameover" then
        initializeGame()
        gameState = "playing"
        sounds.music:play()
    end
end