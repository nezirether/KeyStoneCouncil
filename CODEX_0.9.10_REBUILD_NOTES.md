# Keystone Council 0.9.10-alpha rebuild

Fixes a previous packaging/build issue where the TOC said 0.9.9-alpha but Core/Constants.lua still hardcoded KC.VERSION = 0.9.7-alpha. Diagnostics read KC.VERSION, so the game still printed 0.9.7-alpha.

Changed:
- KeystoneCouncil.toc Version: 0.9.10-alpha
- Core/Constants.lua KC.VERSION: 0.9.10-alpha
- Core/Constants.lua KC.PROTOCOL_VERSION: 2
- AstralKeys/BigWigs integration files retained from the prior patch.

Test:
/reload
/kc diag
Expected first line: Keystone Council 0.9.10-alpha
