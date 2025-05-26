-- This file exists for backward compatibility
-- It loads the modular version of Minecord

-- Check if the modular version is available
local success, modularMinecord = pcall(require, "Minecord.init")

if success then
    -- Use the modular version
    return modularMinecord
else
    -- Fall back to the legacy version if the modular version failed to load
    local Minecord = {}
    local ws = nil -- WebSocket
    local json = {}

    -- ######### INTERNAL API ######### --
    function json.encode(data)
        return textutils.serialiseJSON(data)
    end
    function json.decode(data)
        return textutils.unserialiseJSON(data) or {}
    end
    function send(data)
        if not ws then
            error("WebSocket is not initialized")
        end

        term.setTextColor(colors.lightGray)
        -- print(data)
        ws.send(data)
    end

    local Heartbeat = 5
    local Events = {}
    local Commands = {}
    local commandPrefix = "!"  -- Default command prefix

    -- ######### PUBLIC API ######### --
    function Minecord.on(event,callback)
        -- Check if there is a table in Events[event]
        if not Events[event] then
            Events[event] = {}
        end

        -- Insert the callback into the table
        table.insert(Events[event], callback)
    end

    function Minecord.invoke(event, data)
        -- Check if there is a table in Events[event]
        if not Events[event] then
            return
        end

        -- Call all callbacks
        for _,callback in pairs(Events[event]) do
            callback(data)
        end
    end

    function Minecord.setPrefix(prefix)
        if type(prefix) == "string" then
            commandPrefix = prefix
        else
            error("Prefix must be a string")
        end
    end

    function Minecord.getPrefix()
        return commandPrefix
    end

    function Minecord.registerCommand(name, callback)
        if type(name) ~= "string" then
            error("Command name must be a string")
        end
        if type(callback) ~= "function" then
            error("Command callback must be a function")
        end
        
        Commands[name:lower()] = callback
    end

    function Minecord.handleCommands(enabled)
        if enabled == nil then
            enabled = true
        end
        
        if enabled then
            Minecord.on("MESSAGE_CREATE", function(message)
                if message.content and message.content:sub(1, #commandPrefix) == commandPrefix then
                    local content = message.content:sub(#commandPrefix + 1)
                    local args = {}
                    
                    for arg in content:gmatch("%S+") do
                        table.insert(args, arg)
                    end
                    
                    local commandName = table.remove(args, 1)
                    if commandName then
                        commandName = commandName:lower()
                        local commandCallback = Commands[commandName]
                        
                        if commandCallback then
                            commandCallback(message, args)
                        end
                    end
                end
            end)
        end
    end

    function Minecord.sendMessage(channelId, content, options)
        if not ws then
            error("WebSocket is not initialized")
        end
        
        if type(channelId) ~= "string" then
            error("Channel ID must be a string")
        end
        
        if type(content) ~= "string" then
            error("Content must be a string")
        end
        
        options = options or {}
        
        local payload = {
            content = content,
            tts = options.tts or false,
            embeds = options.embeds
        }
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages"
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN -- Store token globally when login is called
        }
        
        local response = http.post({
            url = url,
            body = json.encode(payload),
            headers = headers
        })
        
        return response
    end

    -- Modify login function to store token globally
    function Minecord.login(token, intentsNumber, applicationId) -- https://discord-intents-calculator.vercel.app/
        _G._DISCORD_TOKEN = token -- Store token for later use
        _G._DISCORD_APPLICATION_ID = applicationId -- Store application ID for slash commands
        
        ws = assert(http.websocket("wss://gateway.discord.gg/?v=10&encoding=json"))

        function heartbeat()
            while ws do
                ws.send(json.encode({op = 1, d = os.time()}))
                os.sleep(Heartbeat)
            end
        end

        function socketMessageReceive()
            while ws do
                local msg,err = ws.receive()
                if(err or not msg) then return end

                term.setTextColor(colors.gray)
                -- print(msg)
                term.setTextColor(colors.white)

                local JS = json.decode(msg)

                if(JS.op == 10) then
                    -- print("Request to identify")
                    Heartbeat = JS.d.heartbeat_interval / 1000
                    send(json.encode({
                        op = 2,
                        d = {
                            token = token,
                            intents = intentsNumber,
                            properties = {
                                ["os"] = "windows",
                                ["browser"] = "CC",
                                ["device"] = "CC"
                            }
                        }
                    }))
                elseif(JS.op == 11) then
                    -- Handle heartbeat ACK for ping measurement
                    Minecord.invoke("HEARTBEAT_ACK", {})
                elseif(JS.op == 0) then
                    Minecord.invoke(JS.t, JS.d)
                end
            end
        end
        parallel.waitForAll(heartbeat, socketMessageReceive) 
    end

    function Minecord.measurePing(callback)
        if not ws then
            error("WebSocket is not initialized")
        end
        
        local startTime = os.epoch("utc")
        
        -- Create a one-time event handler for the heartbeat ACK
        local pingHandler = function(data)
            local endTime = os.epoch("utc")
            local pingTime = endTime - startTime
            
            if callback then
                callback(pingTime)
            end
            
            -- Remove this handler after it's called
            Events["HEARTBEAT_ACK"] = nil
        end
        
        if not Events["HEARTBEAT_ACK"] then
            Events["HEARTBEAT_ACK"] = {}
        end
        
        table.insert(Events["HEARTBEAT_ACK"], pingHandler)
        
        -- Send a heartbeat to measure ping
        send(json.encode({op = 1, d = os.time()}))
        
        return startTime
    end

    -- Activity types:
    -- 0 = Playing
    -- 1 = Streaming
    -- 2 = Listening
    -- 3 = Watching
    -- 4 = Custom
    -- 5 = Competing
    function Minecord.setActivity(type, name, url)
        if not ws then
            error("WebSocket is not initialized")
        end
        
        local activity = {
            name = name,
            type = type,
            url = url
        }
        
        send(json.encode({
            op = 3,
            d = {
                since = os.time() * 1000,
                activities = {activity},
                status = "online",
                afk = false
            }
        }))
    end

    -- Edit a message
    function Minecord.editMessage(channelId, messageId, content, options)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        options = options or {}
        
        local payload = {
            content = content,
            embeds = options.embeds,
            components = options.components,
            allowed_mentions = options.allowed_mentions,
            attachments = options.attachments,
            flags = options.flags,
            tts = options.tts
        }
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages/" .. messageId
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "PATCH",
            body = json.encode(payload),
            headers = headers
        })
        
        if response then
            local responseData = json.decode(response.readAll())
            response.close()
            return responseData
        end
        
        return nil
    end

    -- Add a convenience function for editing embeds specifically
    function Minecord.editEmbed(channelId, messageId, embed, content, options)
        options = options or {}
        options.embeds = {embed}
        
        return Minecord.editMessage(channelId, messageId, content or "", options)
    end

    -- Delete a message
    function Minecord.deleteMessage(channelId, messageId)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages/" .. messageId
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "DELETE",
            headers = headers
        })
        
        return response
    end

    -- Create a button
    function Minecord.createButton(style, customId, label, emoji, url, disabled)
        return {
            type = 2, -- Button type
            style = style, -- 1: Primary, 2: Secondary, 3: Success, 4: Danger, 5: Link
            custom_id = style == 5 and nil or (customId or "button_" .. os.epoch("utc")),
            label = label,
            emoji = emoji,
            url = style == 5 and url or nil,
            disabled = disabled or false
        }
    end

    -- Create an action row (container for components)
    function Minecord.createActionRow(components)
        return {
            type = 1, -- Action Row type
            components = components or {}
        }
    end

    -- Send a message with components
    function Minecord.sendComponentMessage(channelId, content, components, options)
        options = options or {}
        options.components = components
        
        return Minecord.sendMessage(channelId, content, options)
    end

    -- Handle component interactions
    function Minecord.handleComponents(enabled)
        if enabled == nil then
            enabled = true
        end
        
        if enabled then
            Minecord.on("INTERACTION_CREATE", function(interaction)
                if interaction.type == 3 then -- MESSAGE_COMPONENT interaction
                    local customId = interaction.data.custom_id
                    
                    -- Find and invoke the associated callback
                    local componentCallback = Minecord._componentCallbacks and Minecord._componentCallbacks[customId]
                    if componentCallback then
                        componentCallback(interaction)
                    end
                    
                    -- Acknowledge the interaction to prevent "This interaction failed" message
                    Minecord.acknowledgeInteraction(interaction.id, interaction.token)
                end
            end)
        end
    end

    -- Register a component callback
    function Minecord.onComponent(customId, callback)
        if not Minecord._componentCallbacks then
            Minecord._componentCallbacks = {}
        end
        
        Minecord._componentCallbacks[customId] = callback
    end

    -- Acknowledge an interaction
    function Minecord.acknowledgeInteraction(interactionId, interactionToken, data)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        local url = "https://discord.com/api/v10/interactions/" .. interactionId .. "/" .. interactionToken .. "/callback"
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local payload = {
            type = 4, -- CHANNEL_MESSAGE_WITH_SOURCE
            data = data or { content = "Acknowledged" }
        }
        
        http.request({
            url = url,
            method = "POST",
            body = json.encode(payload),
            headers = headers
        })
    end

    -- Register application (slash) commands
    function Minecord.registerApplicationCommands(guildId, commands)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        if not _G._DISCORD_APPLICATION_ID then
            error("Application ID not set")
        end
        
        local url
        if guildId then
            url = "https://discord.com/api/v10/applications/" .. _G._DISCORD_APPLICATION_ID .. "/guilds/" .. guildId .. "/commands"
        else
            url = "https://discord.com/api/v10/applications/" .. _G._DISCORD_APPLICATION_ID .. "/commands"
        end
        
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "PUT",
            body = json.encode(commands),
            headers = headers
        })
        
        return response
    end

    -- Handle application command interactions
    function Minecord.handleApplicationCommands(enabled)
        if enabled == nil then
            enabled = true
        end
        
        if enabled then
            Minecord.on("INTERACTION_CREATE", function(interaction)
                if interaction.type == 2 then -- APPLICATION_COMMAND interaction
                    local commandName = interaction.data.name
                    
                    -- Find and invoke the associated callback
                    local commandCallback = Minecord._appCommandCallbacks and Minecord._appCommandCallbacks[commandName]
                    if commandCallback then
                        commandCallback(interaction)
                    end
                end
            end)
        end
    end

    -- Register an application command callback
    function Minecord.onApplicationCommand(commandName, callback)
        if not Minecord._appCommandCallbacks then
            Minecord._appCommandCallbacks = {}
        end
        
        Minecord._appCommandCallbacks[commandName] = callback
    end

    -- Create an embed
    function Minecord.createEmbed(options)
        options = options or {}
        
        return {
            title = options.title,
            description = options.description,
            url = options.url,
            timestamp = options.timestamp,
            color = options.color,
            footer = options.footer,
            image = options.image,
            thumbnail = options.thumbnail,
            author = options.author,
            fields = options.fields or {}
        }
    end

    -- ######### REACTIONS API ######### --

    -- Add a reaction to a message
    function Minecord.addReaction(channelId, messageId, emoji)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        -- URL encode the emoji if it's a Unicode emoji
        local encodedEmoji = emoji
        if not emoji:match(":") then
            encodedEmoji = textutils.urlEncode(emoji)
        end
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages/" .. messageId .. "/reactions/" .. encodedEmoji .. "/@me"
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "PUT",
            headers = headers
        })
        
        return response
    end

    -- Remove a reaction from a message
    function Minecord.removeReaction(channelId, messageId, emoji, userId)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        -- URL encode the emoji if it's a Unicode emoji
        local encodedEmoji = emoji
        if not emoji:match(":") then
            encodedEmoji = textutils.urlEncode(emoji)
        end
        
        local userPart = userId or "@me"
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages/" .. messageId .. "/reactions/" .. encodedEmoji .. "/" .. userPart
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "DELETE",
            headers = headers
        })
        
        return response
    end

    -- Get users who reacted with a specific emoji
    function Minecord.getReactions(channelId, messageId, emoji, options)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        options = options or {}
        
        -- URL encode the emoji if it's a Unicode emoji
        local encodedEmoji = emoji
        if not emoji:match(":") then
            encodedEmoji = textutils.urlEncode(emoji)
        end
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages/" .. messageId .. "/reactions/" .. encodedEmoji
        
        -- Add query parameters if provided
        local queryParams = {}
        if options.limit then table.insert(queryParams, "limit=" .. options.limit) end
        if options.after then table.insert(queryParams, "after=" .. options.after) end
        
        if #queryParams > 0 then
            url = url .. "?" .. table.concat(queryParams, "&")
        end
        
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "GET",
            headers = headers
        })
        
        if response then
            local responseData = json.decode(response.readAll())
            response.close()
            return responseData
        end
        
        return nil
    end

    -- ######### USER MANAGEMENT ######### --

    -- Get information about a user
    function Minecord.getUser(userId)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        local url = "https://discord.com/api/v10/users/" .. userId
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "GET",
            headers = headers
        })
        
        if response then
            local userData = json.decode(response.readAll())
            response.close()
            return userData
        end
        
        return nil
    end

    -- Change a user's nickname in a guild
    function Minecord.setNickname(guildId, userId, nickname)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        local url
        local payload = {}
        
        if userId == "@me" or userId == _G._DISCORD_SELF_ID then
            -- Change bot's own nickname
            url = "https://discord.com/api/v10/guilds/" .. guildId .. "/members/@me/nick"
            payload = { nick = nickname or "" }
        else
            -- Change another user's nickname
            url = "https://discord.com/api/v10/guilds/" .. guildId .. "/members/" .. userId
            payload = { nick = nickname or "" }
        end
        
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local method = userId == "@me" or userId == _G._DISCORD_SELF_ID and "PATCH" or "PATCH"
        
        local response = http.request({
            url = url,
            method = method,
            body = json.encode(payload),
            headers = headers
        })
        
        return response
    end

    -- ######### CHANNEL MANAGEMENT ######### --

    -- Create a new channel in a guild
    function Minecord.createChannel(guildId, name, options)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        options = options or {}
        
        local payload = {
            name = name,
            type = options.type or 0, -- Default to text channel
            topic = options.topic,
            bitrate = options.bitrate,
            user_limit = options.user_limit,
            rate_limit_per_user = options.rate_limit_per_user,
            position = options.position,
            permission_overwrites = options.permission_overwrites,
            parent_id = options.parent_id,
            nsfw = options.nsfw
        }
        
        local url = "https://discord.com/api/v10/guilds/" .. guildId .. "/channels"
        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "POST",
            body = json.encode(payload),
            headers = headers
        })
        
        if response then
            local channelData = json.decode(response.readAll())
            response.close()
            return channelData
        end
        
        return nil
    end

    -- Delete a channel
    function Minecord.deleteChannel(channelId)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        local url = "https://discord.com/api/v10/channels/" .. channelId
        local headers = {
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "DELETE",
            headers = headers
        })
        
        if response then
            local responseData = json.decode(response.readAll())
            response.close()
            return responseData
        end
        
        return nil
    end

    -- ######### MESSAGE COLLECTORS ######### --

    -- Create a message collector that collects messages matching a filter
    function Minecord.createMessageCollector(options)
        options = options or {}
        
        local collector = {
            channelId = options.channelId,
            filter = options.filter or function() return true end,
            max = options.max,
            time = options.time,
            collected = {},
            _eventHandler = nil,
            _timeoutId = nil
        }
        
        -- Set up message collection
        collector._eventHandler = function(message)
            if message.channel_id == collector.channelId and collector.filter(message) then
                table.insert(collector.collected, message)
                
                -- Call the collect callback if provided
                if options.collect then
                    options.collect(message)
                end
                
                -- Stop collecting if we've reached the maximum
                if collector.max and #collector.collected >= collector.max then
                    collector:stop()
                end
            end
        end
        
        -- Add the event handler
        Minecord.on("MESSAGE_CREATE", collector._eventHandler)
        
        -- Set up a timeout if specified
        if collector.time then
            collector._timeoutId = os.startTimer(collector.time)
            
            -- Add a parallel task to handle the timeout
            parallel.waitForAny(function()
                local event, id
                repeat
                    event, id = os.pullEvent("timer")
                until id == collector._timeoutId
                
                collector:stop()
            end)
        end
        
        -- Method to stop collecting
        function collector:stop()
            -- Remove the event handler
            local newHandlers = {}
            for _, handler in ipairs(Events["MESSAGE_CREATE"] or {}) do
                if handler ~= self._eventHandler then
                    table.insert(newHandlers, handler)
                end
            end
            Events["MESSAGE_CREATE"] = newHandlers
            
            -- Call the end callback if provided
            if options["end"] then
                options["end"](self.collected)
            end
        end
        
        return collector
    end

    -- ######### FILE ATTACHMENTS ######### --

    -- Send a message with file attachments
    function Minecord.sendFileMessage(channelId, content, filePaths, options)
        if not _G._DISCORD_TOKEN then
            error("Not logged in")
        end
        
        options = options or {}
        
        -- Prepare multipart form data
        local boundary = "Boundary-" .. os.epoch("utc")
        local multipartBody = ""
        
        -- Add payload_json part
        local payload = {
            content = content,
            tts = options.tts or false,
            embeds = options.embeds,
            components = options.components
        }
        
        multipartBody = multipartBody .. "--" .. boundary .. "\r\n"
        multipartBody = multipartBody .. "Content-Disposition: form-data; name=\"payload_json\"\r\n"
        multipartBody = multipartBody .. "Content-Type: application/json\r\n\r\n"
        multipartBody = multipartBody .. json.encode(payload) .. "\r\n"
        
        -- Add file parts
        for i, filePath in ipairs(filePaths) do
            local file = fs.open(filePath, "rb")
            if file then
                local fileContent = file.readAll()
                file.close()
                
                local fileName = fs.getName(filePath)
                
                multipartBody = multipartBody .. "--" .. boundary .. "\r\n"
                multipartBody = multipartBody .. "Content-Disposition: form-data; name=\"file" .. i .. "\"; filename=\"" .. fileName .. "\"\r\n"
                multipartBody = multipartBody .. "Content-Type: application/octet-stream\r\n\r\n"
                multipartBody = multipartBody .. fileContent .. "\r\n"
            end
        end
        
        multipartBody = multipartBody .. "--" .. boundary .. "--\r\n"
        
        local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages"
        local headers = {
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Authorization"] = "Bot " .. _G._DISCORD_TOKEN
        }
        
        local response = http.request({
            url = url,
            method = "POST",
            body = multipartBody,
            headers = headers
        })
        
        if response then
            local responseData = json.decode(response.readAll())
            response.close()
            return responseData
        end
        
        return nil
    end

    -- Store the bot's user information when received in READY event
    Minecord.on("READY", function(data)
        if data and data.user and data.user.id then
            _G._DISCORD_SELF_ID = data.user.id
        end
    end)

    return Minecord
end