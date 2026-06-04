local KC = KeystoneCouncil

-- ============================================================
-- QUOTE PACKS
-- Data-driven. New packs can be added by inserting into
-- KC.Quotes.packs at any time before OnEnable fires.
-- ============================================================

KC.Quotes = {
  selected    = nil,
  selectedTier = nil,
  packs       = {},  -- extensible: seasonal / expansion / community packs go here
}

-- ---- Generic Pack ------------------------------------------

KC.Quotes.packs.generic = {
  "Stop Arguing. Start Timing.",
  "The Key Won't Push Itself.",
  "Less Talking. More Pulling.",
  "Routes Over Excuses.",
  "Every Pull Matters.",
  "The Timer Is Watching.",
  "Make The Key Great Again.",
  "One Vote. One Key.",
  "Push Smarter.",
  "Trust The Process.",
  "Better Decisions. Better Keys.",
  "Majority Rules. Timers Judge.",
  "Pick The Key. Own The Result.",
  "Routes Before Recounts.",
  "Where Pugs Become Teams.",
  "Keys Over Egos.",
  "Victory Begins At The Portal.",
  "The Council Has Spoken.",
  "Consensus Before The Countdown.",
  "Timing Beats Complaining.",
  "Fewer Excuses. Higher Scores.",
  "Choose Violence. Choose Wisely.",
  "Every Vote Counts.",
  "Every Death Matters.",
  "Votes Are Temporary. The Timer Is Forever.",
  "Push First. Blame Later.",
  "Great Keys Start Here.",
  "Better Routes. Better Loot.",
  "For Keystone And Country.",
  "One Team. One Timer.",
  "United Against Depletes.",
  "The Key Chooses You.",
  "Vote Fast. Pull Faster.",
  "The Dungeon Decides.",
  "Your Weekly Starts Here.",
  "Built For Pushers.",
  "Organized Keys Since Login.",
  "Find The Best Key.",
  "Timing Is A Team Sport.",
  "Data Beats Feelings.",
  "The Route To Glory.",
  "Fewer Wipes. More Wins.",
  "Progress Through Pulls.",
  "The Meta Changes. Skill Doesn't.",
  "Plan. Pull. Profit.",
  "Your Next Upgrade Starts Here.",
  "Every Key Has A Story.",
  "Turn Keys Into Titles.",
  "Push Beyond Average.",
  "Because Guessing Isn't A Strategy.",
  "Turning Opinions Into Decisions.",
  "Push Harder. Tilt Less.",
  "Let The Numbers Decide.",
  "Peak Performance Starts Here.",
  "The Smartest Pull Wins.",
  "Chase The Timer.",
  "Leave No Key Behind.",
  "Serious About Timing.",
  "For Those Who Push.",
  "Every Second Counts.",
  "The Road To Title Starts Here.",
  "Built By Key Addicts.",
  "Where Good Keys Go Great.",
  "Less Drama. More Score.",
  "Dungeon Diplomacy.",
  "A Better Way To Pick Keys.",
  "Timing Through Teamwork.",
  "Never Waste A Vault Slot.",
  "Choose Your Destiny.",
  "The Science Of Keystone Success.",
  "Key Selection Perfected.",
  "Built For The Endless Push.",
  "Make Every Key Count.",
  "Push Like It Matters.",
  "One More Key.",
}

-- ---- Guild Pack --------------------------------------------

KC.Quotes.packs.guild = {
  -- Chopper
  "Chopper Says It's Fine.",
  "It Was Fine Until Chopper Saw It.",
  "Chopper Found Another Pack.",
  "Pull Count: Chopper.",
  "The Route Was Good. Chopper Wasn't.",
  "Chopper's GPS Is Broken.",
  "One More Pack Won't Hurt.",
  "Chopper Has A Different Route.",
  "Chopper Is Tanking Again Somehow.",
  "The Council Blames Chopper.",
  "Chopper Pulled For Democracy.",
  "That Mob Wasn't On The Route.",
  "Chopper Saw A Shortcut.",
  "Chopper's In Combat Again.",
  "The Pull Was Authorized By Chopper.",
  "Chopper's Threat Radius Is Unlimited.",
  "Chopper Has Questions. The Mobs Have Answers.",
  "Every Pack Is Mandatory According To Chopper.",
  "Chopper Didn't Mean To.",
  "We Have Determined It Was Chopper.",
  -- Nez
  "Trust Nez. Probably.",
  "Nez Already Started The Key.",
  "Nez Is Looking At Raider.IO Again.",
  "The Key Was Pulled Before The Vote Ended.",
  "Nez Has Another Addon Idea.",
  "This Could Have Been A Spreadsheet.",
  "Nez Says We Time This.",
  "The Tank Is Never Wrong.",
  "Nez Already Invited The Group.",
  "One More Key Before Bed.",
  "Nez Is Still Streaming.",
  "Title Push Delusions Activated.",
  "The Pull Is Bigger In Nez's Head.",
  "According To Nez, It's Free.",
  "Nez Has A Plan.",
  "Nez Forgot The Plan.",
  "Route First. Regret Later.",
  "Nez Is Watching The Timer.",
  "Everything Is Fine Until The Timer Turns Red.",
  "Another Scientific Experiment By Nez.",
  -- Volk
  "Volk Still Owes You PI.",
  "Ask Volk For PI Again.",
  "PI Is Pending Approval.",
  "Volk Says Barrier Next Pull.",
  "Volk Has A Spreadsheet For This.",
  "Disc Priest Magic.",
  "Volk Already Predicted The Wipe.",
  "PI Not Found.",
  "Volk Is Out Of Mana And Patience.",
  "Barrier Solves Everything.",
  "Volk Knew This Would Happen.",
  "The Logs Will Judge Us.",
  "PI Reserved For The Wrong Player.",
  "Volk's Notes Were Ignored Again.",
  "We Should Have Listened To Volk.",
  -- Dym
  "Dym Wants A Bigger Pull.",
  "Dym Wants An Even Bigger Pull.",
  "Dym Thinks We're Underpulling.",
  "Dym Is Already Charging.",
  "Dym Voted For Violence.",
  "Dym Has No Reverse Gear.",
  "The Pull Limit Does Not Exist.",
  "Dym Marked Everything Skull.",
  "Zug Approved.",
  "Dym Has Entered Zug Mode.",
  "Tactical Aggression.",
  "Dym Is Pulling With Confidence.",
  "Nobody Told Dym To Stop.",
  "Dym Solved It With Damage.",
  "Bigger. Pull Bigger.",
  -- Troke
  "Troke Says It's Safe.",
  "It Was Not Safe.",
  "Troke's Forecast Was Incorrect.",
  "Aug Says Send It.",
  "Troke Buffed The Wrong Decision.",
  "We Trusted Troke Again.",
  "The Math Checked Out.",
  "The Pull Did Not.",
  "Troke Believes In Us.",
  "Troke Probably Shouldn't.",
  -- Crio
  "Crio Is Already Flying Somewhere.",
  "Crio Found A New Way To Die.",
  "Crio Says It's Fine Too.",
  "Chaos Courtesy Of Crio.",
  "Crio Pressed Something.",
  "Crio Has Momentum.",
  "Crio Is Technically Alive.",
  "The Floor Loves Crio.",
  "Crio Has A Different Strategy.",
  "Nobody Understands Crio's Strategy.",
  -- Pickle / Tuck / Buckee
  "Pickle Chose Violence.",
  "Pickle Is In Range Somewhere.",
  "Pickle Pulled It On Purpose.",
  "Tuck Has Questions.",
  "Tuck Needs More Cooldowns.",
  "Tuck Wasn't Ready.",
  "Buckee Misses Taco Tuesday.",
  "Costco Would Have Been Safer.",
  "Buckee Deserved Better.",
  "Tater Tot Casserole Diff.",
}

-- ---- Rare Pack (≈1% chance) --------------------------------

KC.Quotes.packs.rare = {
  "The Key Is Fine. The Group Is Experimental.",
  "Many Mobs. One Chopper.",
  "461 MS And A Dream.",
  "7% Mana. Full Confidence.",
  "Purplexity Quality Assurance Failed.",
  "Emergency Meeting: Chopper Explain.",
  "Nobody Knows What Troke Is Doing.",
  "PI Has Been Delayed Due To Budget Cuts.",
  "Dym Has Escalated The Situation.",
  "Nez Is Building Another Addon Instead Of Sleeping.",
}

-- ============================================================
-- SETTINGS HELPERS
-- ============================================================

local function ProfileOptions()
  KeystoneCouncilDB = KeystoneCouncilDB or {}
  KeystoneCouncilDB.profile = KeystoneCouncilDB.profile or {}
  KeystoneCouncilDB.profile.options = KeystoneCouncilDB.profile.options or {}
  return KeystoneCouncilDB.profile.options
end

local function GuildQuotesEnabled()
  return ProfileOptions().includeGuildMemeQuotes == true
end

local function RareQuotesEnabled()
  return ProfileOptions().includeRareQuotes == true
end

-- ============================================================
-- SELECTION LOGIC
-- ============================================================

-- Roll returns "rare", "guild", or "generic" based on current
-- settings and the configured probability thresholds.
-- Rare quotes have a 1-in-100 chance when enabled, and only
-- appear if the rare pack is non-empty.
local function RollTier()
  local rarePack  = KC.Quotes.packs.rare  or {}
  local guildPack = KC.Quotes.packs.guild or {}

  if RareQuotesEnabled() and #rarePack > 0 and math.random(100) == 1 then
    return "rare"
  end

  if GuildQuotesEnabled() and #guildPack > 0 then
    return math.random(2) == 1 and "guild" or "generic"
  end

  return "generic"
end

-- Pick a random entry from the named pack. Falls back to
-- generic if the requested pack is empty.
local function PickFromPack(tier)
  local pack = KC.Quotes.packs[tier]
  if pack and #pack > 0 then
    return pack[math.random(#pack)], tier
  end
  local generic = KC.Quotes.packs.generic or {}
  if #generic > 0 then
    return generic[math.random(#generic)], "generic"
  end
  return "Stop Arguing. Start Pushing.", "generic"
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Select (and cache) a new quote. Pass force=true to reroll.
-- When force=false and a quote is already cached, returns it
-- immediately without any random calls (stable while UI open).
function KC.Quotes:Select(force)
  if self.selected and not force then
    return self.selected
  end

  local tier = RollTier()
  local quote, resolvedTier = PickFromPack(tier)
  self.selected      = quote
  self.selectedTier  = resolvedTier
  return self.selected
end

-- Force a specific tier regardless of settings / roll.
-- Used by /kc quote guild|rare|generic commands.
function KC.Quotes:ForceSelect(tier)
  tier = tostring(tier or "generic")
  if not self.packs[tier] then
    tier = "generic"
  end
  local quote, resolvedTier = PickFromPack(tier)
  self.selected     = quote
  self.selectedTier = resolvedTier
  self:ApplyToMainFrame()
  return self.selected
end

-- Reroll using normal probability rules and push to the UI.
function KC.Quotes:Reroll()
  local quote = self:Select(true)
  self:ApplyToMainFrame()
  return quote
end

-- ============================================================
-- FONT-FIT HELPER
-- Slightly shrinks long quotes so they don't overflow.
-- Thresholds tuned for the MainFrame tagline width.
-- ============================================================

function KC.Quotes:FitFontString(fontString, quote)
  if not fontString then return end

  local font, size, flags = fontString:GetFont()
  -- Cache base values once so repeated calls don't drift.
  fontString.baseFont      = fontString.baseFont      or font
  fontString.baseFontSize  = fontString.baseFontSize  or size or 10
  fontString.baseFontFlags = fontString.baseFontFlags or flags

  local len     = string.len(tostring(quote or ""))
  local base    = fontString.baseFontSize
  local nextSize

  if     len > 60 then nextSize = math.max(7, base - 3)
  elseif len > 54 then nextSize = math.max(8, base - 2)
  elseif len > 42 then nextSize = math.max(9, base - 1)
  else                 nextSize = base
  end

  fontString:SetFont(fontString.baseFont, nextSize, fontString.baseFontFlags)
end

-- ============================================================
-- APPLY TO UI
-- ============================================================

function KC.Quotes:Apply(fontString)
  if not fontString then return end
  local quote = self:Select(false)
  fontString:SetText(quote)
  self:FitFontString(fontString, quote)
end

function KC.Quotes:ApplyToMainFrame()
  if KC.MainFrame and KC.MainFrame.frame and KC.MainFrame.frame.tagline then
    self:Apply(KC.MainFrame.frame.tagline)
  end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function KC.Quotes:OnEnable()
  -- Seed RNG with time + three warm-up calls so first random()
  -- call is not correlated with the seed itself (LCG quirk).
  if math.randomseed and time then
    math.randomseed(time())
    math.random(); math.random(); math.random()
  end
  -- Always select on enable so the quote is ready before the
  -- MainFrame calls Apply during its own Create phase.
  self:Select(true)
end

KC:RegisterModule("Quotes", KC.Quotes)
