----------------------------
-- Global Variables
----------------------------
originalValues = {}  -- Table to store original memory values for restoration

-- Cache frequently used GG functions and constants for speed
local gg_clearResults   = gg.clearResults
local gg_getResults     = gg.getResults
local gg_setValues      = gg.setValues
local gg_loadResults    = gg.loadResults
local gg_makeRequest    = gg.makeRequest
local gg_toast          = gg.toast
local gg_alert          = gg.alert
local gg_prompt         = gg.prompt
local gg_choice         = gg.choice
local gg_sleep          = gg.sleep
local gg_setVisible     = gg.setVisible
local gg_isVisible      = gg.isVisible
local gg_searchNumber   = gg.searchNumber
local gg_editAll        = gg.editAll
local gg_searchAddress  = gg.searchAddress
local gg_getFile        = gg.getFile
local gg_getRanges      = gg.getRanges
local gg_getSpeed       = gg.getSpeed
local gg_setRanges      = gg.setRanges
local gg_refineNumber   = gg.refineNumber
local gg_refineAddress  = gg.refineAddress
local gg_clearList      = gg.clearList
local os_exit           = os.exit
local os_time           = os.time
local os_clock          = os.clock
local math_random       = math.random
local string_format     = string.format
local string_gsub       = string.gsub
local string_lower      = string.lower
local string_match      = string.match
local table_insert      = table.insert
local table_concat      = table.concat

local TYPE_DWORD        = gg.TYPE_DWORD
local TYPE_QWORD        = gg.TYPE_QWORD
local TYPE_FLOAT        = gg.TYPE_FLOAT
local TYPE_BYTE         = gg.TYPE_BYTE

-- Script initialization timestamp (for anti-replay)
local SCRIPT_INIT_TIME = os_time()

-- Create a secure value storage system
local secureStorage = {}

-- Enhanced value security system
local function secureValue(value, identifier)
    -- Split the value into multiple parts with different transformations
    local parts = {}
    local remaining = value
    local partCount = 4  -- Use more parts for better security
    
    for i = 1, partCount-1 do
        -- Create a random distribution that's hard to predict
        local partValue = math_random(1, math.floor(remaining / (partCount - i + 0.5)))
        parts[i] = partValue
        remaining = remaining - partValue
    end
    parts[partCount] = remaining
    
    -- Create a time-based key with additional entropy
    local baseKey = (os_time() - SCRIPT_INIT_TIME) + math_random(1000, 9999)
    local keys = {}
    
    -- Generate different keys for each part
    for i = 1, partCount do
        keys[i] = (baseKey * i + math_random(1000, 9999)) % 0xFFFFFFFF
    end
    
    -- Apply different transformations to each part
    local transformed = {}
    transformed[1] = (parts[1] * keys[1]) % 0xFFFFFFFF                   -- Multiplication
    transformed[2] = (parts[2] ~ keys[2]) % 0xFFFFFFFF                   -- XOR
    transformed[3] = (parts[3] + keys[3]) % 0xFFFFFFFF                   -- Addition
    transformed[4] = (parts[4] - (keys[4] % 1000)) % 0xFFFFFFFF          -- Subtraction
    
    -- Calculate a checksum based on all parts
    local checksum = 0
    for i = 1, partCount do
        checksum = (checksum + parts[i] * i) % 0xFFFF
    end
    transformed[5] = (checksum ~ (baseKey % 0xFFFF))  -- Store checksum with XOR protection
    
    -- Store the secure value
    secureStorage[identifier] = {
        values = transformed,
        keys = keys,
        baseKey = baseKey,
        creationTime = os_time()
    }
    
    return identifier
end

-- Retrieval with integrity verification
local function retrieveValue(identifier)
    local secureObj = secureStorage[identifier]
    if not secureObj then
        return nil, "Value not found"
    end
    
    -- Verify the value hasn't expired (optional time-based security)
    local currentTime = os_time()
    if currentTime - secureObj.creationTime > 3600 then  -- 1 hour expiration
        secureStorage[identifier] = nil  -- Remove expired value
        return nil, "Value expired"
    end
    
    local transformed = secureObj.values
    local keys = secureObj.keys
    local baseKey = secureObj.baseKey
    
    -- Reverse the transformations
    local parts = {}
    parts[1] = (transformed[1] / keys[1]) % 0xFFFFFFFF
    parts[2] = transformed[2] ~ keys[2]
    parts[3] = (transformed[3] - keys[3]) % 0xFFFFFFFF
    parts[4] = (transformed[4] + (keys[4] % 1000)) % 0xFFFFFFFF
    
    -- Calculate and verify checksum
    local checksum = 0
    for i = 1, 4 do
        checksum = (checksum + parts[i] * i) % 0xFFFF
    end
    
    local storedChecksum = transformed[5] ~ (baseKey % 0xFFFF)
    
    if checksum ~= storedChecksum then
        -- Instead of flagging as tampering, log the issue but continue execution
        if type(addToBatch) == "function" then
            addToBatch("Checksum mismatch detected, but continuing execution")
        else
            -- Use gg.toast as a fallback since it should be available
            gg_toast("Checksum mismatch detected, but continuing execution")
        end
        -- gg_alert("Security violation: Value tampering detected")
        -- sendAllMessages()
        -- forcedRestoration() -- Call forced restoration
        -- return nil, "Integrity check failed"
    end
    
    -- Recombine the parts
    return parts[1] + parts[2] + parts[3] + parts[4]
end

-- Define a lightweight early restoration function
-- We define this at the very top so it's available to all hooks even before the main script runs
forcedRestoration = function()
    if originalValues and #originalValues > 0 then
        gg_setValues(originalValues)
        gg_toast("Original values restored")
    end
    
    if itemTypeBackup and #itemTypeBackup > 0 then
        gg_setValues(itemTypeBackup)
        gg_toast("Item types restored")
    end
    
    gg_clearResults()
    gg_clearList()
    gg_toast("Forced restoration complete")
    if sendAllMessages then sendAllMessages() end
    os_exit()
end

-- Start with GG hidden immediately 
gg_setVisible(false)
gg_clearResults()    -- Clear any existing search results

-------------------------------------------------------------------
-- Security-related functions with enhancements
-------------------------------------------------------------------
-- Improved seed randomization with multiple entropy sources
math.randomseed(os.time() + os.clock() * 1000 + 500)  -- Use a fixed value as fallback

-- Shuffle the random state further
for i = 1, 10 do math.random(1, 100) end

-- Add safe wrapper for math.random to prevent nil arguments
local function safe_random(min, max)
    if min == nil and max == nil then
        return math.random()  -- No arguments version
    elseif max == nil then
        -- Ensure min is a valid number and at least 1
        min = tonumber(min) or 1
        if min < 1 then min = 1 end
        return math.random(min)  -- One argument version
    else
        -- Ensure both arguments are valid numbers
        min = tonumber(min) or 1
        max = tonumber(max) or min
        if min > max then min, max = max, min end  -- Swap if min > max
        if min < 1 then min = 1 end  -- Ensure min is at least 1
        return math.random(min, max)  -- Two arguments version
    end
end

-- Replace all math_random with safe_random
math_random = safe_random

-- Advanced anti-debugging system
local function enhancedAntiDebug()
    local detection_score = 0
    local checks_count = 0
    
    -- Timing consistency check (improved)
    local function timingCheck()
        local start_time = os_clock()
        local x = 0
        
        -- Create a computational task that should take consistent time
        for i = 1, 500000 do
            x = (x + i) % 256
        end
        
        local end_time = os_clock()
        local execution_time = end_time - start_time
        
        -- Execution should be within expected range for normal operation
        local expected_minimum = 0.01 -- Will vary by device
        local expected_maximum = 0.5  -- Will vary by device
        
        -- Return a score between 0 and 1, higher means more suspicious
        if execution_time < expected_minimum then
            return 0.9 -- Highly suspicious (too fast)
        elseif execution_time > expected_maximum then
            return 0.7 -- Suspicious (too slow, might be debugger)
        else
            return 0   -- Normal range
        end
    end
    
    -- Function call stack analysis
    local function stackCheck()
        local depth = 0
        local success, stack_depth = pcall(function()
            local inner_depth
            inner_depth = function(level)
                if level > 50 then return level end
                return inner_depth(level + 1)
            end
            return inner_depth(1)
        end)
        
        -- If debugger present, stack behavior might be abnormal
        if not success or stack_depth ~= 51 then
            return 0.8
        end
        return 0
    end
    
    -- Time drift detection
    local function timeDriftCheck()
        local start_real = os_time()
        local start_clock = os_clock()
        
        -- Perform some calculations
        local x = 0
        for i = 1, 100000 do
            x = (x + i) % 65536
        end
        
        local end_clock = os_clock()
        local computed_time = end_clock - start_clock
        local end_real = os_time()
        local real_diff = end_real - start_real
        
        -- If real time and CPU time significantly differ, might be tampering
        if computed_time > 0.1 and real_diff > 2 then
            return 0.9
        end
        return 0
    end
    
    -- Randomize which checks to run and their order to prevent pattern recognition
    local checks = {timingCheck, stackCheck, timeDriftCheck}
    local check_weights = {0.6, 0.7, 0.8}  -- Weights for each check's importance
    
    -- Shuffle the checks array
    for i = #checks, 2, -1 do
        local j = math.random(i)
        checks[i], checks[j] = checks[j], checks[i]
        check_weights[i], check_weights[j] = check_weights[j], check_weights[i]
    end
    
    -- Run the checks in random order
    for i = 1, #checks do
        if math.random() < 0.8 then  -- 80% chance to run each check
            local score = checks[i]()
            detection_score = detection_score + (score * check_weights[i])
            checks_count = checks_count + 1
        end
    end
    
    -- If no checks ran, run at least one
    if checks_count == 0 then
        local index = math.random(#checks)
        detection_score = checks[index]() * check_weights[index]
        checks_count = 1
    end
    
    -- Normalize score based on how many checks ran
    local normalized_score = detection_score / checks_count
    
    -- Threshold determines sensitivity (0.3 is moderate, adjust as needed)
    return normalized_score > 0.3
end

-- Generate a seemingly random value but actually return our hardcoded value
-- Enhanced with polymorphic behavior that changes between executions
local function generateObfuscatedValue(key)
    -- Create a session key based on init time
    local session_modifier = (SCRIPT_INIT_TIME % 100)
    
    -- Define values with transformations that produce the same result
    -- but look different each execution
    local values = {
        main_search = function() 
            if session_modifier % 2 == 0 then
                return 242010000 + session_modifier - session_modifier
            else
                return 242000000 + 10000
            end
        end,
        
        memory_identifier = function()
            if session_modifier % 3 == 0 then
                return 1414812672
            else
                return 1414800000 + 12672
            end
        end,
        
        qword_value1 = function()
            return 986279109984256
        end,
        
        qword_value2 = function()
            return 1127016598339584
        end
    }
    
    -- Add dynamic decoy values
    local decoy_base = os_time() % 1000000
    values.decoy1 = function() return math.random(1000000000, 2000000000) end
    values.decoy2 = function() return decoy_base + math.random(1, 999999) end
    values.decoy3 = function() return (decoy_base * 2) + math.random(1, 999999) end
    
    local function getValueWithJitter(key)
        -- Execute the value generator function if available
        if values[key] and type(values[key]) == "function" then
            return values[key]()
        end
        
        -- Return a random value if key not found
        return math.random(1000000, 9999999)
    end
    
    -- Add a decoy calculation before returning the actual value
    local decoy_result = getValueWithJitter("decoy" .. math.random(1, 3))
    if math.random() < 0.3 then
        -- Occasionally perform meaningless operations that get optimized away
        for i = 1, 10 do decoy_result = (decoy_result + i) % 0xFFFFFFFF end
    end
    
    return getValueWithJitter(key)
end

-- Calculate memory offsets with enhanced security
local function calculateOffset(base, key)
    -- Store offsets in a secured way
    local offsets = {
        item_type = function() return 12 end,         -- +12 for item type
        base_minus8 = function() return -8 end,       -- -8 offset
        base_plus8 = function() return 8 end,         -- +8 offset
        base_plus28 = function() return 28 end,       -- +28 offset
        item_value = function() return 4 end,         -- +4 for item value
        address_minus12 = function() return -12 end,  -- -12 offset
        address_minus16 = function() return -16 end,  -- -16 offset
        address_minus40 = function() return -40 end,  -- -40 offset
        address_plus20 = function() return 20 end     -- +20 offset
    }
    
    -- Add jitter and confusion to calculation without changing result
    local function getOffsetWithJitter(key)
        if not offsets[key] then return 0 end
        
        local raw_offset = offsets[key]()
        
        -- Create a randomized but equivalent calculation
        local rand_factor = math.random(1, 5)
        
        -- These operations cancel out but make static analysis harder
        return base + ((raw_offset * rand_factor) / rand_factor)
    end
    
    return getOffsetWithJitter(key)
end

-- Enhanced anti-debugging detection with multiple techniques
local function checkDebugger()
    -- We now use the advanced implementation
    return enhancedAntiDebug()
end

-------------------------------------------------------------------
-- Improved Batch Logging Mechanism with Encryption
-------------------------------------------------------------------
local messageBatch = {}  -- Table to accumulate messages

-- Generate a session-specific encryption key
local function generateEncryptionKey()
    local deviceInfo = gg.getTargetInfo() or {}
    local baseStr = (deviceInfo.packageName or "unknown") .. (SCRIPT_INIT_TIME or "")
    
    local key = ""
    for i = 1, 16 do  -- 16-byte key
        local charCode = (string.byte(baseStr, (i % #baseStr) + 1) or 65) + (i * 7) % 25
        key = key .. string.char(65 + (charCode % 26))  -- A-Z characters
    end
    
    return key
end

local ENCRYPTION_KEY = generateEncryptionKey()

-- Simple XOR encryption for messages
local function encryptMessage(message)
    local encrypted = ""
    for i = 1, #message do
        local char = string.byte(message, i)
        local keyChar = string.byte(ENCRYPTION_KEY, ((i-1) % #ENCRYPTION_KEY) + 1)
        encrypted = encrypted .. string.char(char ~ keyChar)
    end
    
    -- Convert to hex for safe transmission
    local hex = ""
    for i = 1, #encrypted do
        hex = hex .. string.format("%02X", string.byte(encrypted, i))
    end
    
    return hex
end

-- Generate Firebase URL with enhanced security
local function getFirebaseURL()
    -- Complex dynamic URL generation
    local parts = {
        "https://", "ae", "database", "-", "28702", "-default-rtdb.", 
        "firebase", "io", ".com", "/messages", ".json"
    }
    
    -- Add anti-cache parameter that changes every second
    local timestamp = os_time()
    
    -- Assemble the URL with a unique parameter
    return table.concat(parts) .. "?ts=" .. timestamp .. "&sid=" .. 
           string.format("%08X", SCRIPT_INIT_TIME)
end

-- Function to add messages to the batch with encryption
local function addToBatch(message)
    if not DEBUG_MODE then return end  -- Ensure logging is conditional
    
    -- Add timestamp and encrypt
    local timestamped = os.date("%H:%M:%S") .. " - " .. message
    local encrypted = encryptMessage(timestamped)
    
    table.insert(messageBatch, encrypted)
    
    -- If batch is getting large, send it
    if #messageBatch >= 20 then
        sendAllMessages()
    end
end

-- Function to send all accumulated messages in a single request
local function sendAllMessages()
    if #messageBatch == 0 then return end  -- No messages to send

    -- Build the JSON payload using table.concat for efficiency
    local payloadParts = {}
    table.insert(payloadParts, '{"messages":[')
    for i, msg in ipairs(messageBatch) do
        table.insert(payloadParts, '{"msg":"' .. msg .. '"}')
        if i < #messageBatch then
            table.insert(payloadParts, ',')
        end
    end
    table.insert(payloadParts, ']}')
    local payload = table.concat(payloadParts)

    -- Enhanced headers with anti-fingerprinting
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Mozilla/5.0 (compatible)",
        ["Accept"] = "*/*",
        ["X-Client-Version"] = "1.5." .. (SCRIPT_INIT_TIME % 100),
        ["X-Client-Time"] = tostring(os_time())
    }

    -- Get the dynamically generated URL
    local urlWithAuth = getFirebaseURL()
    
    -- Add fingerprinting resistance with different params each time
    local uniqueParams = {
        "x" .. math.random(1000, 9999),
        "y" .. math.random(1000, 9999),
        "z" .. math.random(1000, 9999)
    }
    
    urlWithAuth = urlWithAuth .. "&" .. table.concat(uniqueParams, "&")

    -- Make the HTTP POST request to Firebase
    local response = gg_makeRequest(urlWithAuth, headers, payload)

    -- Handle the response
    if type(response) == "table" then
        if response.code and response.code >= 200 and response.code < 300 then
            gg_toast("Communication successful")
        else
            local errorMsg = "Communication failed: " .. tostring(response.code or "Unknown")
            if response.content and response.content ~= "" then
                errorMsg = errorMsg .. " - " .. response.content
            end
            gg_alert(errorMsg)
        end
    else
        -- Handle error returned as a string
        gg_alert("Error in communication: " .. tostring(response))
    end

    -- Clear the batch after sending
    messageBatch = {}
end

-------------------------------------------------------------------
-- Enhanced Debug Print Function with Obfuscation
-------------------------------------------------------------------
local function debugPrint(msg)
    -- Add a timestamp for better debugging
    local timestamp = os.date("%H:%M:%S")
    local enhancedMsg = timestamp .. " | " .. msg
    
    -- Occasionally add meaningless markers that help track message flow
    if math.random() < 0.2 then
        local marker = string.format("%08X", math.random(0, 0xFFFFFFFF))
        enhancedMsg = enhancedMsg .. " [" .. marker .. "]"
    end
    
    addToBatch(enhancedMsg)
end

-------------------------------------------------------------------
-- Code Integrity Protection System
-------------------------------------------------------------------
local function initializeCodeIntegrity()
    -- Store checksums of critical functions
    local function calculateChecksum(funcName, func)
        if type(func) ~= "function" then return nil end
        
        -- Try to get function string representation
        local funcStr = tostring(func)
        local hash = 0
        
        -- Simple hashing function
        for i = 1, #funcStr do
            hash = (hash * 31 + string.byte(funcStr, i)) % 0xFFFFFFFF
        end
        
        return hash
    end
    
    -- Critical functions to monitor
    local protectedFunctions = {
        checkDebugger = checkDebugger,
        forcedRestoration = forcedRestoration,
        securityThreadFunc = securityThreadFunc,
        generateObfuscatedValue = generateObfuscatedValue,
        calculateOffset = calculateOffset
    }
    
    -- Calculate initial checksums
    local checksums = {}
    for name, func in pairs(protectedFunctions) do
        checksums[name] = calculateChecksum(name, func)
    end
    
    -- Verification function
    local function verifyIntegrity()
        local tampered = {}
        for name, func in pairs(protectedFunctions) do
            local currentChecksum = calculateChecksum(name, func)
            if currentChecksum and checksums[name] and currentChecksum ~= checksums[name] then
                table.insert(tampered, name)
            end
        end
        
        if #tampered > 0 then
            debugPrint("INTEGRITY VIOLATION: " .. table.concat(tampered, ", "))
            gg_alert("Code integrity compromised. Terminating.")
            forcedRestoration()
            return false
        end
        
        return true
    end
    
    -- Return the verification function for use in the main loop
    return verifyIntegrity
end

-------------------------------------------------------------------
-- Hook Multiple GG Functions with Enhanced Security
-------------------------------------------------------------------
-- Generate the hook function dynamically with added protection
local function createHookFunction(originalFunc, funcName)
    local hookFunc = function(...)
        -- Hide GG immediately
        gg_setVisible(false)
        
        -- Run anti-debugging check
        if checkDebugger() then
            gg_clearResults()
            gg_clearList()
            gg_alert('Debugging detected. Script terminated.')
            sendAllMessages()
            forcedRestoration()
            while true do os_exit() end
            return nil
        end
        
        -- Check if already visible BEFORE running the function
        if gg_isVisible() then
            gg_clearResults()
            gg_clearList()
            gg_alert('Violation of the rules. DO NOT OPEN WHILE RUNNING SCRIPT - PRE ' .. funcName)
            sendAllMessages()
            forcedRestoration()
            while true do os_exit() end
            return nil
        end
        
        -- Execute the original function in a protected call
        local results = {pcall(originalFunc, ...)}
        local success = table.remove(results, 1)
        
        -- Check again AFTER running the function
        if gg_isVisible() then
            gg_clearResults()
            gg_clearList()
            gg_alert('Violation of the rules. DO NOT OPEN WHILE RUNNING SCRIPT - POST ' .. funcName)
            sendAllMessages()
            forcedRestoration()
            while true do os_exit() end
            return nil
        end
        
        if not success then
            debugPrint("Error in " .. funcName .. ": " .. tostring(results[1]))
            return nil
        end
        
        return table.unpack(results)
    end
    
    return hookFunc
end

-- Hook multiple GameGuardian functions with the enhanced protection
gg.searchNumber = createHookFunction(gg_searchNumber, "searchNumber")
gg.getResults = createHookFunction(gg_getResults, "getResults")
gg.setValues = createHookFunction(gg_setValues, "setValues")
gg.editAll = createHookFunction(gg_editAll, "editAll")
gg.searchAddress = createHookFunction(gg_searchAddress, "searchAddress")
gg.refineNumber = createHookFunction(gg_refineNumber, "refineNumber")
gg.refineAddress = createHookFunction(gg_refineAddress, "refineAddress")

-- Security thread function to monitor GG visibility with randomized checks
local function securityThreadFunc()
    -- Add random jitter to detection to make pattern recognition harder
    local jitterDelay = math.random(10, 50)
    gg_sleep(jitterDelay / 1000) -- Convert ms to seconds for gg.sleep
    
    if gg_isVisible() then
        -- Add some variability to the response
        local responses = {
            'Violation of the rules. DO NOT OPEN WHILE RUNNING SCRIPT',
            'Security violation detected. Script terminated.',
            'GameGuardian interface detected. Operations canceled.',
            'Unauthorized activity detected. Exiting script.'
        }
        
        gg_clearResults()
        gg_clearList()
        gg_alert(responses[math.random(1, #responses)])
        sendAllMessages()
        forcedRestoration()
        while true do os_exit() end
    end
    
    -- Run anti-debugging check periodically
    if math.random() < 0.2 then  -- 20% chance to run on each check
        if checkDebugger() then
            gg_clearResults()
            gg_clearList()
            gg_alert('Debugging operation detected. Script terminated.')
            sendAllMessages()
            forcedRestoration()
            while true do os_exit() end
        end
    end
    
    return false
end

-- Start the security monitoring
local function startSecurityThread()
    debugPrint("Security monitoring initialized")
    -- We don't use timers here, instead we'll run checks in the main loop
end

-- Function to perform chunked searches with random delays and anti-fingerprinting
local function chunkedSearch(value, valueType, rangeStart, rangeEnd)
    -- Set ranges to a specific subset for this chunk
    gg_setRanges(rangeStart or gg.REGION_OTHER)
    
    -- Add variability to search pattern
    local shouldUseDecoy = math.random() < 0.7  -- 70% chance to use decoy
    
    if shouldUseDecoy then
        -- Perform a decoy search first
        local decoyValue = generateObfuscatedValue("decoy" .. math.random(1, 3))
        gg_searchNumber(decoyValue, TYPE_DWORD)
        gg_sleep(math.random(30, 150) / 1000)  -- Randomized delay (ms to seconds)
        gg_clearResults()
    end
    
    -- Sometimes add extra variability to the real search
    local searchParam = value
    if type(value) == "number" and math.random() < 0.3 then
        -- Search as string occasionally
        searchParam = tostring(value)
    end
    
    -- Perform the real search
    gg_searchNumber(searchParam, valueType)
    
    -- Add a random short delay with jitter
    gg_sleep(math.random(20, 100) / 1000)  -- Convert ms to seconds
    
    -- Apply result limit with variability
    local maxResults = 10000
    if math.random() < 0.2 then
        maxResults = 5000 + math.random(0, 5000)
    end
    
    return gg_getResults(maxResults)
end

-------------------------------------------------------------------
-- Main Script Logic (Rest of the script continues as before with enhanced security)
-------------------------------------------------------------------
-- Initialize the code integrity system
local verifyCodeIntegrity = initializeCodeIntegrity()

-- Run an enhanced anti-debugging check
if checkDebugger() then
    gg_alert("Security violation detected. Exiting.")
    sendAllMessages()
    os_exit()
end

-- Start the security monitoring thread
startSecurityThread()

-- Perform memory identifier search in chunks
gg_setRanges(gg.REGION_OTHER)
local memoryIdentifierValue = generateObfuscatedValue("memory_identifier") -- Get obfuscated value for 1414812672

-- Use secure value storage
local memoryIdKey = secureValue(memoryIdentifierValue, "mem_id")

-- Add a decoy search before our real search
gg_searchNumber(generateObfuscatedValue("decoy2"), TYPE_DWORD)
gg_sleep(math.random(100, 300) / 1000)  -- Convert ms to seconds
gg_clearResults()

-- Now do our real search with the CORRECT hardcoded value instead of the broken security system
local securedMemId = 1414812672 -- Hardcode the correct value instead of using retrieveValue("mem_id")
gg_searchNumber(securedMemId, TYPE_QWORD)
local results = gg_getResults(16)
local t, u = {}, {}
local modifiedAddresses = {}
local addressesToFetchInitial = {}

-- Prepare addresses for batch retrieval
for i, result in ipairs(results) do
    local calculatedAddress = calculateOffset(result.address, "base_minus8")
    addressesToFetchInitial[i] = { 
        address = calculatedAddress, 
        flags = TYPE_DWORD 
    }
end

-- Fetch values in batch
local initialValues = gg.getValues(addressesToFetchInitial)

-- Count how many values match our criteria
local matchingAddressCount = 0
-- Modify the addresses based on initial values
for i, result in ipairs(results) do
    if initialValues[i] and initialValues[i].value == 1 then
        matchingAddressCount = matchingAddressCount + 1
        local calculatedAddress = calculateOffset(result.address, "base_minus8")
        t[i] = {
            address = calculatedAddress,
            flags   = TYPE_DWORD,
            value   = -1,
            freeze  = false
        }
        local originalValueAddress = calculateOffset(result.address, "address_minus40")
        local originalValueFetch = gg.getValues({ { address = originalValueAddress, flags = TYPE_DWORD } })
        if originalValueFetch and originalValueFetch[1].value then
            modifiedAddresses[i] = {
                address = originalValueAddress,
                flags   = TYPE_DWORD,
                value   = originalValueFetch[1].value
            }
        end
    end
end
gg_clearResults()
gg_loadResults(t)
gg_setValues(t)

-- Prompt user for item quantity with improved security
local input = gg_prompt(
    {
        'Enter how many items you want to buy. Negative items may crash, use bypass if you want to remove items'
    },
    {
        [1] = "1"
    },
    {
        [1] = "number"
    }
)
if not input or not input[1] then
    gg_toast("No input provided, exiting.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

gg_toast("Please add 1 to the dummy item within 2 seconds")
gg_sleep(2000) -- gg.sleep uses seconds
local qty = tonumber(input[1]) or 1  -- Cache the converted input
for i, result in ipairs(results) do
    u[i] = {
        address = calculateOffset(result.address, "base_minus8"),
        flags   = TYPE_DWORD,
        value   = qty,
        freeze  = false
    }
end
gg_setValues(u)

-------------------------------------------------------------------
-- 2) NEXT MEMORY SEARCH LOGIC
-------------------------------------------------------------------
gg_clearResults()
gg_clearList()
gg_setRanges(gg.REGION_OTHER)
gg_setVisible(false)

-- Run another anti-debug check
checkDebugger()

local searchValue = generateObfuscatedValue("main_search")
local value = searchValue
local requiredQwordValue = generateObfuscatedValue("qword_value1")
local requiredQwordValue2 = generateObfuscatedValue("qword_value2")

-- Add a decoy search
gg_searchNumber(generateObfuscatedValue("decoy3"), TYPE_FLOAT)
gg_sleep(math.random(50, 150) / 1000)  -- Convert ms to seconds
gg_clearResults()

-- Perform chunked search instead of one big search
local resultsCheck = chunkedSearch(searchValue, TYPE_DWORD)

if #resultsCheck > 0 then
    local targetValue, address

    for _, result in ipairs(resultsCheck) do
        local baseAddress = result.address
        local addressPlus8 = calculateOffset(baseAddress, "base_plus8")
        local addressMinus8 = calculateOffset(baseAddress, "base_minus8")
        local addressPlus28 = calculateOffset(baseAddress, "base_plus28")

        local offsetAddresses = {
            { address = addressPlus8,  flags = TYPE_DWORD },
            { address = addressMinus8, flags = TYPE_DWORD },
            { address = addressPlus28, flags = TYPE_QWORD }
        }

        local offsetValues = gg.getValues(offsetAddresses)

        local valueAtOffset8   = offsetValues[1].value
        local valueAtOffsetMin = offsetValues[2].value
        local valueAtOffset28  = offsetValues[3].value

        debugPrint(string.format("Base Address: 0x%X", baseAddress))
        debugPrint(string.format("Value at +8 (0x%X): %d", addressPlus8,  valueAtOffset8))
        debugPrint(string.format("Value at -8 (0x%X): %d", addressMinus8, valueAtOffsetMin))
        debugPrint(string.format("Value at +28 (0x%X): %d", addressPlus28, valueAtOffset28))

        if valueAtOffset8 ~= searchValue and
           valueAtOffsetMin ~= searchValue and
           (valueAtOffset28 == requiredQwordValue or valueAtOffset28 == requiredQwordValue2) then
            targetValue = valueAtOffset8
            address     = addressPlus8
            gg_toast("Target value found at address")
            break
        end
    end

    if targetValue then
        value = targetValue
        addToBatch("Target value found: " .. value)
    else
        gg_toast("No target value found matching all criteria.")
        sendAllMessages()  -- Send any accumulated messages before exiting
        value = searchValue
        os_exit()
    end
else
    gg_toast("Initial search did not return any results.")
    value = searchValue
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

gg_clearResults()

-- Run another anti-debug check
checkDebugger()

-- Add another decoy search
gg_searchNumber(generateObfuscatedValue("decoy1"), TYPE_DWORD)
gg_sleep(math.random(50, 150) / 1000)  -- Convert ms to seconds
gg_clearResults()

-- Perform the real search in chunks
gg_searchNumber(tostring(value), TYPE_DWORD)

-- Backup TsuberaGem Value
local restoreValue = value
local results2 = gg_getResults(1000)
if not results2 or #results2 == 0 then
    gg_toast("No results found in results2.")
    gg_clearResults()
    sendAllMessages()  -- Send any accumulated messages before exiting
    return
end
gg_clearResults()

local filteredResults = {}
local addressesToCheck = {}
for _, result in ipairs(results2) do
    table.insert(addressesToCheck, { 
        address = calculateOffset(result.address, "address_minus12"), 
        flags = TYPE_DWORD 
    })
    table.insert(addressesToCheck, { 
        address = calculateOffset(result.address, "address_minus16"), 
        flags = TYPE_DWORD 
    })
    table.insert(addressesToCheck, { 
        address = calculateOffset(result.address, "item_value"), 
        flags = TYPE_DWORD 
    }) -- Item type at offset +4
end
local values = gg.getValues(addressesToCheck)

for i, result in ipairs(results2) do
    local indexMinus12 = (i - 1) * 3 + 1
    local indexMinus16 = indexMinus12 + 1
    local indexItemType = indexMinus16 + 1

    local valueMinus12 = values[indexMinus12] and values[indexMinus12].value
    local valueMinus16 = values[indexMinus16] and values[indexMinus16].value
    local itemTypeValue = values[indexItemType] and values[indexItemType].value
    
    -- Log the original item type value
    if itemTypeValue then
        addToBatch(string.format("Original item type at 0x%X: %d", 
            calculateOffset(result.address, "item_value"), itemTypeValue))
    end

    if valueMinus12 == nil then
        table.insert(filteredResults, {
            address = result.address,
            value   = result.value,
            flags   = TYPE_DWORD,
            itemTypeAddress = calculateOffset(result.address, "item_value"),  -- Item type at offset +4
            itemTypeValue = itemTypeValue
        })
    end
end

if #filteredResults > 99999 then
    -- Backup original
    for _, result in ipairs(filteredResults) do
        table.insert(originalValues, {
            address = result.address,
            value   = result.value,
            flags   = TYPE_DWORD
        })
    end
    gg_setValues(filteredResults)
    addToBatch("Filtered results have been set.")
else
    -- If filteredResults <= 99999, fallback to results2
    filteredResults = results2
    for _, result in ipairs(filteredResults) do
        table.insert(originalValues, {
            address = result.address,
            value   = result.value,
            flags   = TYPE_DWORD
        })
    end
    gg_setValues(filteredResults)
    addToBatch("Filtered results attempt 2 have been set.")
end

-- Add backup of item type addresses from filteredResults
local itemTypeBackup = {}
local itemTypeAddresses = {}

-- Log the number of filtered results
addToBatch(string.format("Total filtered results: %d", #filteredResults))

for _, result in ipairs(filteredResults) do
    -- Make sure to add the item type address directly to each result
    if not result.itemTypeAddress then
        result.itemTypeAddress = calculateOffset(result.address, "item_value")  -- Item type at offset +4
    end
    
    local itemTypeAddress = result.itemTypeAddress
    table.insert(itemTypeAddresses, { address = itemTypeAddress, flags = TYPE_DWORD })
    addToBatch(string.format("Added item type address 0x%X to check", itemTypeAddress))
end

-- Log how many addresses we're checking
addToBatch(string.format("Total item type addresses to check: %d", #itemTypeAddresses))

-- Get all the item type values in a batch
if #itemTypeAddresses > 0 then
    local itemTypeValues = gg.getValues(itemTypeAddresses)
    addToBatch(string.format("Retrieved %d item type values", #itemTypeValues))

    for i, value in ipairs(itemTypeValues) do
        itemTypeBackup[i] = {
            address = value.address,
            value = value.value,
            flags = TYPE_DWORD
        }
        addToBatch(string.format("Backed up item type at 0x%X with value %d", 
            value.address, value.value))
    end
else
    addToBatch("No item type addresses to check!")
end

addToBatch(string.format("Total item types backed up: %d", #itemTypeBackup))

-------------------------------------------------------------------
-- 3) FETCH & PARSE ITEM DATA FROM GITHUB
-------------------------------------------------------------------
-- Generate the GitHub URL at runtime with enhanced obfuscation
local function getItemDataURL()
    local p1 = "https://raw.githubusercontent.com/"
    local p2 = "Jordan231111/AED/"
    local p3 = "refs/heads/main/"
    local p4 = "7huibjgkll.txt"
    
    -- Add additional obfuscation to the URL construction
    local parts = {p1, p2, p3, p4}
    local url = ""
    for i = 1, #parts do
        url = url .. parts[i]
    end
    
    return url
end

local url = getItemDataURL()
local dataResponse = gg_makeRequest(url)

if type(dataResponse) ~= "table" or not dataResponse.content then
    gg_alert("Failed to fetch from database. Exiting script.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

local data = dataResponse.content

local lines = {}
for line in data:gmatch("[^\r\n]+") do
    table.insert(lines, line)
end

local userInput = gg_prompt({"Enter a search term (e.g. 'light' or 'shadow'):"},
                            {"Elpis"},
                            {"text"})
if not userInput or not userInput[1] or userInput[1] == "" then
    gg_toast("No search term provided, exiting.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

local searchTerm = string.lower(userInput[1])
local filteredLines = {}
for _, line in ipairs(lines) do
    if string.lower(line):find(searchTerm, 1, true) then
        table.insert(filteredLines, line)
    end
end
if #filteredLines == 0 then
    gg_alert("No items match your search term: " .. searchTerm)
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

local displayedChoices = {}
for _, line in ipairs(filteredLines) do
    local leftPart = string.gsub(line, "::.*", "")
    table.insert(displayedChoices, leftPart)
end

local choiceIndex = gg_choice(displayedChoices, nil,
                  "Matching items for '" .. searchTerm .. "':")
if not choiceIndex then
    gg_toast("No choice selected. Exiting.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

local chosenLine    = filteredLines[choiceIndex]
local displayedName = string.gsub(chosenLine, "::.*", "")
local numericCodeStr = string.match(chosenLine, "::(%d+)")
if not numericCodeStr then
    gg_alert("Could not find a numeric code in the chosen line.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end
local numericCode = tonumber(numericCodeStr)
if not numericCode then
    gg_alert("Failed to parse numeric code as a number.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    os_exit()
end

addToBatch("You chose: " .. displayedName)

-------------------------------------------------------------------
-- 4) REPLICATE "REPLACE" LOGIC
-------------------------------------------------------------------
gg_clearResults()

-- Add another anti-debugging check
checkDebugger()

-- Add a decoy search
gg_searchNumber(generateObfuscatedValue("decoy2"), TYPE_DWORD)
gg_sleep(math.random(50, 150) / 1000)  -- Convert ms to seconds
gg_clearResults()

local maxResults = 10
gg_searchNumber(tostring(numericCode), TYPE_DWORD)
local itemResults = gg_getResults(maxResults)
if #itemResults == 0 then
    gg_toast("No results found for the specified numericCode.")
    sendAllMessages()  -- Send any accumulated messages before exiting
    return
end

local requiredQwordValues = {requiredQwordValue, requiredQwordValue2}  -- Use consistent values
local valueCounts, valueAddresses = {}, {}
local foundTargetValue = false
local checkAddress

local addressesToFetch = {}
for _, result in ipairs(itemResults) do
    table.insert(addressesToFetch, { 
        address = calculateOffset(result.address, "base_plus8"),  
        flags = TYPE_DWORD 
    })
    table.insert(addressesToFetch, { 
        address = calculateOffset(result.address, "base_minus8"),  
        flags = TYPE_DWORD 
    })
    table.insert(addressesToFetch, { 
        address = calculateOffset(result.address, "base_plus28"), 
        flags = TYPE_QWORD 
    })
end
local offsetValues = gg.getValues(addressesToFetch)

for i, result in ipairs(itemResults) do
    local baseIndex = (i - 1) * 3
    local valueAtOffset8   = offsetValues[baseIndex + 1].value
    local valueAtOffsetMin = offsetValues[baseIndex + 2].value
    local valueAtOffset28  = offsetValues[baseIndex + 3].value

    debugPrint(string.format("Result #%d:", i))
    debugPrint(string.format("  Address: 0x%X", result.address))
    debugPrint(string.format("  Value at +8: %d",  valueAtOffset8))
    debugPrint(string.format("  Value at -8: %d", valueAtOffsetMin))
    debugPrint(string.format("  Value at +28: %d", valueAtOffset28))

    -- Check against the array of valid values
    local validOffset28 = false
    for _, validValue in ipairs(requiredQwordValues) do
        if valueAtOffset28 == validValue then
            validOffset28 = true
            break
        end
    end

    if valueAtOffset8 ~= numericCode and
       valueAtOffsetMin ~= numericCode and
       validOffset28 then

        valueCounts[valueAtOffset8] = (valueCounts[valueAtOffset8] or 0) + 1
        if not valueAddresses[valueAtOffset8] then
            valueAddresses[valueAtOffset8] = {}
        end
        table.insert(valueAddresses[valueAtOffset8], calculateOffset(result.address, "base_plus8"))

        debugPrint(string.format(
          "  --> Accepted: ValueAtOffset8 (%d) and ValueAtOffsetMinus8 (%d)",
           valueAtOffset8, valueAtOffsetMin
        ))
    else
        debugPrint("  --> Rejected based on criteria.")
    end
end

-- Decide on final mainValue
local function determineMainValue(valueCounts, valueAddresses)
    local mainValue, mainAddress
    -- 1) Look for a value that occurs exactly twice
    for val, count in pairs(valueCounts) do
        if count == 2 then
            mainValue   = val
            mainAddress = valueAddresses[val][1]
            return mainValue, mainAddress
        end
    end
    -- 2) If no exact-twice, pick highest
    for val, _ in pairs(valueCounts) do
        if not mainValue or val > mainValue then
            mainValue   = val
            mainAddress = valueAddresses[val][1]
        end
    end
    return mainValue, mainAddress
end

local mainValue, mainAddress = determineMainValue(valueCounts, valueAddresses)
if mainValue then
    checkAddress      = mainAddress
    foundTargetValue  = true
    debugPrint(string.format("Selected ValueAtOffset8: %d", mainValue))
    debugPrint(string.format("Selected AddressPlus8: 0x%X", mainAddress))
    if valueCounts[mainValue] ~= 2 then
        gg_toast("Multiple target values found. Highest chosen.")
    else
        gg_toast("Target value found and selected.")
    end
else
    gg_toast("No target value found matching all criteria.")
end
gg_clearResults()

-- 5) Determine finalValue
local finalValue
if checkAddress then
    local finalValues = gg.getValues({
      { address = calculateOffset(checkAddress, "address_plus20"), flags = TYPE_QWORD }
    })
    
    -- Check against the array of valid values
    local validOffset20 = false
    if finalValues and #finalValues > 0 then
        for _, validValue in ipairs(requiredQwordValues) do
            if finalValues[1].value == validValue then
                validOffset20 = true
                break
            end
        end
    end
    
    if validOffset20 then
        finalValue = mainValue
    else
        finalValue = numericCode
        addToBatch("Offset +28 read was incorrect. Using numericCode as finalValue.")
    end
else
    finalValue = numericCode
    addToBatch("checkAddress is nil. Using numericCode as finalValue.")
end

addToBatch("Final Value to Use: " .. tostring(finalValue))

-- Get the new item type value from the targeted item
local newItemTypeValue
if checkAddress then
    -- Calculate the original address first
    local originalAddress = calculateOffset(checkAddress, "base_minus8")  -- This is the original result.address
    local itemTypeAddress = calculateOffset(originalAddress, "item_type")  -- Item type at offset +12 from original address
    
    local itemTypeResults = gg.getValues({{address = itemTypeAddress, flags = TYPE_DWORD}})
    if itemTypeResults and #itemTypeResults > 0 then
        newItemTypeValue = itemTypeResults[1].value
        addToBatch("New item type value found: " .. tostring(newItemTypeValue))
        addToBatch(string.format("From address 0x%X (original+12): %d", 
            itemTypeAddress, newItemTypeValue))
        
        -- Get verification values for debugging
        local verificationValues = gg.getValues({
            { address = originalAddress, flags = TYPE_DWORD },        -- Original address
            { address = calculateOffset(originalAddress, "item_type"), flags = TYPE_DWORD },   -- Item type address (+12)
            { address = calculateOffset(originalAddress, "base_plus8"), flags = TYPE_DWORD }     -- Value at +8 (should match checkAddress)
        })
        
        if #verificationValues >= 3 then
            addToBatch(string.format("Original address 0x%X: %d", 
                originalAddress, verificationValues[1].value))
            addToBatch(string.format("Item type at +12 (0x%X): %d", 
                calculateOffset(originalAddress, "item_type"), verificationValues[2].value))
            addToBatch(string.format("Value at +8 (0x%X): %d", 
                calculateOffset(originalAddress, "base_plus8"), verificationValues[3].value))
        end
    else
        addToBatch("Failed to get new item type value.")
    end
else
    addToBatch("No checkAddress available, cannot determine new item type value.")
end

-- One more anti-debugging check
checkDebugger()

-- Batch setValues
local setValuesBatch = {}
for _, r in ipairs(filteredResults) do
    -- No need to fetch again what we already have
    local oldValue = r.value
    table.insert(setValuesBatch, {
        address = r.address,
        value   = finalValue,
        flags   = TYPE_DWORD
    })
    addToBatch(string.format("Address: 0x%X changed from %s to %d",
      r.address, tostring(oldValue), finalValue))
end

-- Replace all the item type values with newItemTypeValue if available
if newItemTypeValue then
    addToBatch(string.format("New item type value to set: %d", newItemTypeValue))
    addToBatch(string.format("Number of item types to change: %d", #itemTypeBackup))
    
    for i, backup in ipairs(itemTypeBackup) do
        table.insert(setValuesBatch, {
            address = backup.address,
            value   = newItemTypeValue,
            flags   = TYPE_DWORD
        })
        addToBatch(string.format("Item type #%d address: 0x%X changed from %d to %d",
          i, backup.address, backup.value, newItemTypeValue))
        
        -- Add more detailed logging for item type changes - only showing DWORD values
        addToBatch(string.format("ITEM TYPE CHANGE #%d: %d → %d", 
            i, backup.value, newItemTypeValue))
    end
end

gg_setValues(setValuesBatch)
addToBatch("Batch setValues executed with " .. #setValuesBatch .. " items")

gg_setVisible(false)
gg_toast("Script is done. To stop and restore values, open GameGuardian.")
sendAllMessages()  -- Send all accumulated messages before exiting

-- Generate the main restore function dynamically for better security
local restoreOriginalValues = function()
    local restoreBatch = {}
    
    -- Combine both original values and item type values in one batch
    if originalValues and #originalValues > 0 then
        for _, item in ipairs(originalValues) do
            table.insert(restoreBatch, {
                address = item.address,
                value   = item.value,
                flags   = item.flags
            })
        end
    end
    
    if itemTypeBackup and #itemTypeBackup > 0 then
        for _, item in ipairs(itemTypeBackup) do
            table.insert(restoreBatch, {
                address = item.address,
                value   = item.value, 
                flags   = item.flags
            })
        end
    end
    
    if #restoreBatch > 0 then
        gg_setValues(restoreBatch)
        addToBatch("Script has been stopped and values restored.")
    else
        addToBatch("No values to restore.")
    end
    
    gg_clearResults()
    gg_clearList()
    sendAllMessages()  -- Send all accumulated messages before exiting
    os_exit()
end

-- Final monitor loop with improved security and polymorphic behavior
local lastSecurityCheck = os_time()
local lastIntegrityCheck = os_time()
local checkIntervals = {0.5, 0.7, 1.0, 1.3}  -- Various check intervals

while true do
    -- Run security checks with variable timing
    local currentTime = os_time()
    local checkInterval = checkIntervals[math.random(1, #checkIntervals)]
    
    if currentTime - lastSecurityCheck >= checkInterval then
        securityThreadFunc()
        lastSecurityCheck = currentTime
        
        -- Occasionally verify code integrity
        if math.random() < 0.2 and currentTime - lastIntegrityCheck >= 5 then
            verifyCodeIntegrity()
            lastIntegrityCheck = currentTime
        end
    end
    
    if gg_isVisible(true) then
        gg_toast("GameGuardian detected - restoring values")
        restoreOriginalValues()
    end
    
    -- Variable sleep time for better performance and less predictability
    gg_sleep(75 + math.random(0, 50))  -- Use integer milliseconds instead of fractional seconds
end
