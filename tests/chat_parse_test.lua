-- Run with: lua tests/chat_parse_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Chat/Parse.lua")
local Parse = ns.ChatParse

local command, rest = Parse.Command("/w Bob hi there")
check(command == "/W" and rest == "Bob hi there", "command and rest")
command, rest = Parse.Command("/dance")
check(command == "/DANCE" and rest == "", "command without rest")
command, rest = Parse.Command("/sui   test 5  ")
check(command == "/SUI" and rest == "test 5", "spaces trimmed")
check(Parse.Command("hello /w") == nil, "not a command")
check(Parse.Command("") == nil, "empty")

local function isFriend(name)
	return name == "Anna Maria" or name == "Bo"
end
local target, message, bnet = Parse.WhisperTarget("Bob hi there", isFriend)
check(target == "Bob" and message == "hi there" and not bnet, "character whisper")
target, message, bnet = Parse.WhisperTarget("Anna Maria  how are you", isFriend)
check(target == "Anna Maria" and message == "how are you" and bnet, "Battle.net name with a space")
target, message, bnet = Parse.WhisperTarget("Bo yo", isFriend)
check(target == "Bo" and message == "yo" and bnet, "one-word Battle.net name")
target, message = Parse.WhisperTarget("Bob-Thrall hi", nil)
check(target == "Bob-Thrall" and message == "hi", "realm name, no Battle.net check")
local function isCharacter(name)
	return name == "Jubylee Signatory"
end
target, message, bnet = Parse.WhisperTarget("Jubylee Signatory hi there", isFriend, isCharacter)
check(target == "Jubylee Signatory" and message == "hi there" and not bnet, "First Last character name (#42)")
target, message = Parse.WhisperTarget("Bob hi there", isFriend, isCharacter)
check(target == "Bob" and message == "hi there", "unknown name: first word")
check(Parse.WhisperTarget("Bob", isFriend) == nil, "no message")
check(Parse.WhisperTarget("", isFriend) == nil, "nothing")

local first, after = Parse.FirstWord("General hello all")
check(first == "General" and after == "hello all", "first word")
first, after = Parse.FirstWord("General")
check(first == "General" and after == nil, "single word")
check(Parse.FirstWord("") == nil, "empty first word")

print("chat parse tests passed")
