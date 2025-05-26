# Minecord

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![ComputerCraft](https://img.shields.io/badge/CC:Tweaked-1.100.8-orange.svg)

A powerful Discord bot library for ComputerCraft: Tweaked that connects Minecraft computers to Discord.

<div align="center">
  <img src="https://i.imgur.com/YhXwSHZ.png" alt="Minecord Logo" width="400px">
</div>

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Features](#features)
  - [Event Handling](#event-handling)
  - [Message Commands](#message-commands)
  - [Slash Commands](#slash-commands)
  - [Embeds](#embeds)
  - [Interactive Components](#interactive-components)
  - [Message Management](#message-management)
  - [Reactions](#reactions)
  - [User Management](#user-management)
  - [Channel Management](#channel-management)
  - [Message Collectors](#message-collectors)
  - [File Attachments](#file-attachments)
  - [Activity Status](#activity-status)
  - [Ping Measurement](#ping-measurement)
- [Full Example](#full-example)
- [Modular Architecture](#modular-architecture)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Overview

Minecord is a comprehensive Lua library for CC: Tweaked that allows you to create Discord bots that run entirely inside Minecraft computers. Originally created as a basic message detection utility, Minecord has evolved into a full-featured Discord bot framework with support for:

- Message and slash commands
- Interactive components (buttons)
- Rich embeds and message formatting
- Reactions API
- User and channel management
- Message collectors
- File attachments
- And much more!

## Installation

```bash
# Option 1: Using wget (recommended)
wget https://raw.githubusercontent.com/stealtech/minecord/main/Minecord.lua Minecord

# Option 2: Using pastebin
pastebin get JyjSq96A Minecord.lua
```

### Requirements

1. ComputerCraft: Tweaked (CC:T) version 1.95.0 or higher
2. A Discord bot created through the [Discord Developer Portal](https://discord.com/developers/applications)
3. Bot token and application ID

## Quick Start

```lua
local Discord = require("Minecord")

-- Set up event handlers
Discord.on("READY", function(data)
    print("Bot is ready as " .. data.user.username .. "!")
    
    -- Set the bot's activity
    Discord.setActivity(0, "with CC:Tweaked")  -- "Playing with CC:Tweaked"
end)

-- Handle messages
Discord.on("MESSAGE_CREATE", function(message)
    if message.content then
        print(message.author.username .. ": " .. message.content)
    end
end)

-- Register a simple message command
Discord.registerCommand("ping", function(message, args)
    Discord.sendMessage(message.channel_id, "Pong!")
end)

-- Enable command handling
Discord.handleCommands(true)

-- Start the bot (replace with your actual token, intents, and application ID)
Discord.login("YOUR_BOT_TOKEN", 33283, "YOUR_APPLICATION_ID")
```

## Features

### Event Handling

Subscribe to Discord gateway events:

```lua
Discord.on("MESSAGE_CREATE", function(message)
    -- Handle new messages
end)

Discord.on("READY", function(data)
    -- Bot is ready
end)

Discord.on("INTERACTION_CREATE", function(interaction)
    -- Handle interactions
end)
```

### Message Commands

Message commands are triggered by a prefix (default: `!`) followed by the command name:

```lua
-- Set a custom prefix
Discord.setPrefix("?")

-- Register a command
Discord.registerCommand("echo", function(message, args)
    local text = table.concat(args, " ")
    if text ~= "" then
        Discord.sendMessage(message.channel_id, text)
    else
        Discord.sendMessage(message.channel_id, "You didn't provide anything to echo!")
    end
end)
```

### Slash Commands

Slash commands are registered with Discord and appear in the Discord UI:

```lua
-- Define slash commands
local commands = {
    {
        name = "ping",
        description = "Check the bot's latency",
        type = 1
    },
    {
        name = "echo",
        description = "Echo back a message",
        type = 1,
        options = {
            {
                name = "message",
                description = "The message to echo back",
                type = 3, -- STRING
                required = true
            }
        }
    }
}

-- Register commands with Discord
Discord.registerApplicationCommands("YOUR_GUILD_ID", commands)

-- Handle the commands
Discord.onApplicationCommand("ping", function(interaction)
    Discord.acknowledgeInteraction(interaction.id, interaction.token, {
        content = "Pong!"
    })
end)

Discord.onApplicationCommand("echo", function(interaction)
    local message = interaction.data.options[1].value
    Discord.acknowledgeInteraction(interaction.id, interaction.token, {
        content = message
    })
end)

-- Enable application command handling
Discord.handleApplicationCommands(true)
```

### Embeds

Create rich embeds for your messages:

```lua
local embed = Discord.createEmbed({
    title = "Hello World",
    description = "This is an embed message",
    color = 0x00AAFF, -- Blue color
    footer = {
        text = "Powered by CC:Tweaked"
    },
    thumbnail = {
        url = "https://i.imgur.com/YhXwSHZ.png"
    },
    author = {
        name = "Minecord Bot",
        icon_url = "https://i.imgur.com/YhXwSHZ.png"
    },
    fields = {
        {
            name = "Field 1",
            value = "This is a field",
            inline = true
        },
        {
            name = "Field 2",
            value = "This is another field",
            inline = true
        }
    },
    timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
})

Discord.sendMessage(channelId, "", { embeds = {embed} })
```

### Interactive Components

Create interactive buttons and handle interactions:

```lua
-- Create different types of buttons
local primaryButton = Discord.createButton(1, "btn_primary", "Primary", nil, nil, false)
local secondaryButton = Discord.createButton(2, "btn_secondary", "Secondary")
local successButton = Discord.createButton(3, "btn_success", "Success")
local dangerButton = Discord.createButton(4, "btn_danger", "Danger")
local linkButton = Discord.createButton(5, nil, "Link", nil, "https://github.com")

-- Create an action row with buttons
local actionRow = Discord.createActionRow({
    primaryButton, secondaryButton, successButton, dangerButton, linkButton
})

-- Send a message with components
Discord.sendComponentMessage(channelId, "Interactive buttons:", {actionRow})

-- Handle button interactions
Discord.onComponent("btn_primary", function(interaction)
    Discord.acknowledgeInteraction(interaction.id, interaction.token, {
        content = "You clicked the primary button!"
    })
end)

-- Enable component handling
Discord.handleComponents(true)
```

### Message Management

Edit and delete messages:

```lua
-- Send a message and get the message data
local messageData = Discord.sendMessage(channelId, "Initial content")

-- Edit a message
Discord.editMessage(channelId, messageData.id, "Updated content")

-- Edit a message with an embed
local embed = Discord.createEmbed({
    title = "Updated Embed",
    description = "This message was updated",
    color = 0xFF0000
})
Discord.editEmbed(channelId, messageData.id, embed, "Updated content")

-- Delete a message
Discord.deleteMessage(channelId, messageData.id)
```

### Reactions

Add and manage reactions on messages:

```lua
-- Add a reaction to a message
Discord.addReaction(channelId, messageId, "👍")

-- Remove a reaction
Discord.removeReaction(channelId, messageId, "👍")

-- Get users who reacted with a specific emoji
local reactors = Discord.getReactions(channelId, messageId, "👍", { limit = 10 })
for _, user in ipairs(reactors) do
    print(user.username .. " reacted")
end
```

### User Management

Get information about users and manage nicknames:

```lua
-- Get information about a user
local userData = Discord.getUser(userId)
print("Username: " .. userData.username)

-- Change a user's nickname in a guild
Discord.setNickname(guildId, userId, "New Nickname")

-- Change the bot's own nickname
Discord.setNickname(guildId, "@me", "Bot Nickname")
```

### Channel Management

Create and manage Discord channels:

```lua
-- Create a new text channel
local channelData = Discord.createChannel(guildId, "new-channel", {
    type = 0, -- Text channel
    topic = "A channel created via Minecord"
})
print("Created channel: " .. channelData.name)

-- Delete a channel
Discord.deleteChannel(channelId)
```

### Message Collectors

Collect messages that match specific criteria:

```lua
-- Create a message collector
local collector = Discord.createMessageCollector({
    channelId = channelId,
    filter = function(message)
        -- Only collect messages from a specific user
        return message.author.id == userId
    end,
    max = 5, -- Collect up to 5 messages
    time = 60, -- Collect for 60 seconds
    collect = function(message)
        print("Collected message: " .. message.content)
    end,
    ["end"] = function(collected)
        print("Collected " .. #collected .. " messages")
    end
})
```

### File Attachments

Send messages with file attachments:

```lua
-- Send a message with file attachments
Discord.sendFileMessage(
    channelId,
    "Here are some files:",
    {"disk/file1.txt", "disk/image.png"},
    {
        embeds = {
            Discord.createEmbed({
                title = "Files Attached",
                description = "Check out these files"
            })
        }
    }
)
```

### Activity Status

Set the bot's activity status:

```lua
-- Activity types:
-- 0 = Playing
-- 1 = Streaming
-- 2 = Listening
-- 3 = Watching
-- 4 = Custom
-- 5 = Competing

-- Set the bot to "Playing Minecraft"
Discord.setActivity(0, "Minecraft")

-- Set the bot to "Watching users"
Discord.setActivity(3, "users")

-- Set the bot to "Streaming" (with URL)
Discord.setActivity(1, "ComputerCraft", "https://twitch.tv/username")
```

### Ping Measurement

Measure the latency between your bot and Discord:

```lua
Discord.measurePing(function(pingTime)
    print("Current ping: " .. pingTime .. "ms")
end)
```

## Modular Architecture

Minecord now supports a modular architecture for better organization and maintainability. The legacy single-file version will automatically fall back to the modular version when available.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to help improve Minecord.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Originally created as a basic message detection utility
- Enhanced with modern Discord API features in 2024
- Built for ComputerCraft: Tweaked
- Inspired by Discord.js
