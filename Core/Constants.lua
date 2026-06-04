KeystoneCouncil = KeystoneCouncil or {}

local KC = KeystoneCouncil

KC.ADDON_NAME = "KeystoneCouncil"
KC.VERSION = "0.9.14-alpha"
KC.PROTOCOL_VERSION = "2"
KC.COMM_PREFIX = "KCNL"
KC.EVENTS = {
  KEYS_CHANGED = "KEYS_CHANGED",
  VOTES_CHANGED = "VOTES_CHANGED",
  COUNCIL_RESULT = "COUNCIL_RESULT",
  SESSION_CHANGED = "SESSION_CHANGED",
  INTEGRATIONS_CHANGED = "INTEGRATIONS_CHANGED",
}

KC.COLORS = {
  slate = { 0.08, 0.09, 0.11, 0.94 },
  panel = { 0.12, 0.13, 0.16, 0.96 },
  border = { 0.42, 0.36, 0.22, 0.9 },
  gold = { 1.0, 0.78, 0.24, 1 },
  blue = { 0.23, 0.53, 0.96, 1 },
  green = { 0.25, 0.85, 0.55, 1 },
  red = { 0.95, 0.28, 0.28, 1 },
  text = { 0.95, 0.92, 0.84, 1 },
  muted = { 0.62, 0.62, 0.66, 1 },
}
