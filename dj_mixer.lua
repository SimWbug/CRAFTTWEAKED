-- ============================================================
--  DJ MIXER PRO  v8.2 (STABLE) |  CC:Tweaked
-- ============================================================
local dfpwm = require "cc.audio.dfpwm"
local API   = "https://ipod-2to6magyna-uc.a.run.app/"
local VER   = "2.1"
local W, H  = term.getSize()

-- ============================================================
--  COULEURS & PALETTE
-- ============================================================
local C = {
  BLACK="0", ORANGE="1", MAGENTA="2", LBLUE="3", YELLOW="4", 
  LIME="5", PINK="6", GRAY="7", LGRAY="8", CYAN="9", 
  PURPLE="a", BLUE="b", BROWN="c", GREEN="d", RED="e", WHITE="f"
}

local function applyPalette()
  term.setPaletteColor(colors.black, 0x000000)
  term.setPaletteColor(colors.gray, 0x0a0a1a)
  term.setPaletteColor(colors.lightGray, 0x1e1e3a)
  term.setPaletteColor(colors.brown, 0x12122a)
  term.setPaletteColor(colors.cyan, 0x00e5ff)
  term.setPaletteColor(colors.lightBlue, 0x006080)
  term.setPaletteColor(colors.magenta, 0xff0080)
  term.setPaletteColor(colors.pink, 0x600030)
  term.setPaletteColor(colors.lime, 0x00ff44)
  term.setPaletteColor(colors.yellow, 0xffee00)
  term.setPaletteColor(colors.orange, 0xff6600)
  term.setPaletteColor(colors.red, 0xff1111)
  term.setPaletteColor(colors.green, 0x00cc55)
  term.setPaletteColor(colors.blue, 0x2255ff)
  term.setPaletteColor(colors.purple, 0xcc8800)
  term.setPaletteColor(colors.white, 0xffffff)
end

local function restorePalette()
  for i=0,15 do local c=2^i term.setPaletteColor(c, term.nativePaletteColor(c)) end
end

-- ============================================================
--  FONCTION BLIT SÉCURISÉE (Empêche l'erreur de longueur)
-- ============================================================
local function safeBlit(x, y, text, fg, bg)
  local len = #text
  if len == 0 then return end
  -- On ajuste fg et bg pour qu'ils fassent EXACTEMENT la taille du texte
  local s_fg = (fg .. string.rep(fg:sub(-1), len)):sub(1, len)
  local s_bg = (bg .. string.rep(bg:sub(-1), len)):sub(1, len)
  term.setCursorPos(x, y)
  term.blit(text, s_fg, s_bg)
end

local function fill(x1, x2, y, fg, bg)
  local len = math.max(0, x2 - x1 + 1)
  if len > 0 then safeBlit(x1, y, string.rep(" ", len), fg, bg) end
end

-- ============================================================
--  INITIALISATION DES DECK
-- ============================================================
local MID = math.floor(W / 2)
local Y_HDR, Y_DNAME, Y_TITLE, Y_ARTIST, Y_BTNS, Y_VOL = 1, 2, 3, 4, 5, 6
local Y_VU_TOP, Y_VU_BOT = 7, H - 6
local Y_CF_BAR, Y_HELP, Y_STATUS = H-4, H-1, H

local function newDeck(col, dark, side)
  return {
    title="[ VIDE ]", artist="", state="stopped", handle=nil,
    dec=dfpwm.make_decoder(), vol=1.0, status="PRET",
    col=col, darkCol=dark, side=side
  }
end

local decks = { A = newDeck(C.CYAN, C.LBLUE, "L"), B = newDeck(C.MAGENTA, C.PINK, "R") }
local cf, masterVol, beat = 0.5, 1.0, 0
local btnPos = { A = {}, B = {} }

-- ============================================================
--  DETECTION SPEAKERS
-- ============================================================
applyPalette()
local found = {}
for _, n in ipairs(peripheral.getNames()) do
  if peripheral.getType(n) == "speaker" then table.insert(found, peripheral.wrap(n)) end
end
if #found == 0 then restorePalette() error("Besoin d'un speaker !") end
local spkL, spkR = found[1], found[2] or found[1]

-- ============================================================
--  DESSIN DE L'INTERFACE
-- ============================================================
local function drawUI()
  term.setBackgroundColor(colors.gray)
  term.clear()

  -- Header
  fill(1, W, Y_HDR, C.GRAY, C.GRAY)
  local hText = " DJ MIXER PRO v8.2 "
  safeBlit(math.floor((W-#hText)/2)+1, Y_HDR, hText, string.rep(C.CYAN, 5)..string.rep(C.WHITE, 9)..string.rep(C.MAGENTA, 5), C.GRAY)

  -- Decks A et B
  local zones = { {k="A", x1=1, x2=MID-1}, {k="B", x1=MID+1, x2=W} }
  for _, z in ipairs(zones) do
    local d = decks[z.k]
    local dw = z.x2 - z.x1 + 1

    -- Header deck
    fill(z.x1, z.x2, Y_DNAME, d.col, C.BROWN)
    safeBlit(z.x1, Y_DNAME, " DECK "..z.k, d.col, C.BROWN)

    -- Titre/Artiste
    local tStr = ((d.state=="playing" and "> " or "  ")..d.title):sub(1, dw)
    safeBlit(z.x1, Y_TITLE, tStr, (d.state=="playing" and d.col or C.LGRAY), C.GRAY)
    safeBlit(z.x1, Y_ARTIST, ("  "..(d.artist~="" and d.artist or d.status)):sub(1, dw), C.LGRAY, C.GRAY)

    -- Boutons
    local bx = z.x1
    local function b(lbl, fg, bg, id)
      safeBlit(bx, Y_BTNS, lbl, fg, bg)
      btnPos[z.k][id.."_x1"], btnPos[z.k][id.."_x2"] = bx, bx + #lbl - 1
      bx = bx + #lbl + 1
    end
    b("PLAY", (d.state=="playing" and C.GRAY or C.BLACK), (d.state=="playing" and C.LGRAY or C.GREEN), "play")
    b("PAUS", C.BLACK, (d.state=="paused" and C.YELLOW or C.PURPLE), "paus")
    b("STOP", C.WHITE, C.RED, "stop")
    b("LOAD", C.WHITE, C.BLUE, "load")

    -- Volume
    safeBlit(z.x1, Y_VOL, "VOL", C.LGRAY, C.GRAY)
    local barW = dw - 5
    if barW > 0 then
      local lit = math.floor((d.vol/1.5)*barW)
      safeBlit(z.x1+4, Y_VOL, string.rep(" ", barW), C.LIME, string.rep(C.LIME, lit)..string.rep(C.LGRAY, barW-lit))
    end

    -- VU Meter (Simplifié pour stabilité)
    for r=0, (Y_VU_BOT-Y_VU_TOP) do
      local lvl = (d.state=="playing") and (math.random(10,100)/100 * d.vol) or 0
      local rowY = Y_VU_TOP + r
      local px = math.floor(lvl * (Y_VU_BOT-Y_VU_TOP+1) * 2)
      local char = (px > (Y_VU_BOT-rowY)*2 + 1) and " " or (px > (Y_VU_BOT-rowY)*2 and string.char(140) or " ")
      local bgVU = (px > (Y_VU_BOT-rowY)*2 + 1) and C.LIME or d.darkCol
      safeBlit(z.x1, rowY, string.rep(char, dw), C.LIME, bgVU)
    end
  end

  -- Crossfader
  fill(1, W, Y_CF_BAR, C.GRAY, C.GRAY)
  local knob = 10 + math.floor(cf * (W-20))
  safeBlit(1, Y_CF_BAR, "A 100% [", C.CYAN, C.GRAY)
  safeBlit(W-7, Y_CF_BAR, "] 100% B", C.MAGENTA, C.GRAY)
  safeBlit(10, Y_CF_BAR, string.rep("-", W-19), C.WHITE, C.GRAY)
  safeBlit(knob, Y_CF_BAR, "O", C.WHITE, C.YELLOW)

  safeBlit(1, Y_HELP, "Q/P:Play  L/O:Load  </>:Fader", C.LGRAY, C.GRAY)
  for y=2, Y_CF_BAR-1 do safeBlit(MID, y, "|", C.LGRAY, C.GRAY) end
end

-- ============================================================
--  AUDIO & CHARGEMENT
-- ============================================================
local function loadSong(dk)
  local d = decks[dk]
  fill(1, W, Y_STATUS, C.WHITE, C.BLUE)
  term.setCursorPos(1, Y_STATUS)
  term.setTextColor(colors.white)
  term.write(" RECHERCHE ["..dk.."]: ")
  local q = read()
  if not q or q == "" then return end
  d.status = "Chargement..."
  drawUI()
  local ok = pcall(function()
    local h = http.get(API.."?v="..VER.."&search="..textutils.urlEncode(q))
    if h then
      local res = textutils.unserialiseJSON(h.readAll()) h.close()
      if res and res[1] then
        d.title, d.artist = res[1].name, res[1].artist
        if d.handle then d.handle.close() end
        d.handle = http.get({url=API.."?v="..VER.."&id="..res[1].id, binary=true})
        d.dec = dfpwm.make_decoder()
        d.status = "PRET"
        return
      end
    end
    error()
  end)
  if not ok then d.title, d.status = "[ERREUR]", "Introuvable" end
end

local function audioLoop(spk, dk)
  while true do
    local d = decks[dk]
    if d.state == "playing" and d.handle then
      local chunk = d.handle.read(16384)
      if chunk then
        local vol = d.vol * masterVol * (dk=="A" and math.cos(cf*math.pi/2) or math.sin(cf*math.pi/2))
        while not spk.playAudio(d.dec(chunk), vol) do os.pullEvent("speaker_audio_empty") end
      else d.state = "stopped" end
    else sleep(0.1) end
  end
end

-- ============================================================
--  BOUCLE D'INPUT
-- ============================================================
local function inputLoop()
  while true do
    drawUI()
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "key" then
      if p1 == keys.q then decks.A.state = (decks.A.state=="playing" and "stopped" or "playing")
      elseif p1 == keys.p then decks.B.state = (decks.B.state=="playing" and "stopped" or "playing")
      elseif p1 == keys.l then loadSong("A")
      elseif p1 == keys.o then loadSong("B")
      elseif p1 == keys.left then cf = math.max(0, cf - 0.05)
      elseif p1 == keys.right then cf = math.min(1, cf + 0.05)
      end
    elseif ev == "mouse_click" then
      local mx, my = p2, p3
      for k, d in pairs(decks) do
        local b = btnPos[k]
        if my == Y_BTNS then
          if mx >= b.play_x1 and mx <= b.play_x2 then d.state = "playing"
          elseif mx >= b.paus_x1 and mx <= b.paus_x2 then d.state = "paused"
          elseif mx >= b.stop_x1 and mx <= b.stop_x2 then d.state = "stopped"
          elseif mx >= b.load_x1 and mx <= b.load_x2 then loadSong(k)
          end
        end
      end
    end
  end
end

-- ============================================================
--  LANCEMENT
-- ============================================================
pcall(function()
  parallel.waitForAny(
    function() audioLoop(spkL, "A") end,
    function() audioLoop(spkR, "B") end,
    inputLoop
  )
end)

restorePalette()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
print("DJ Mixer Pro ferme.")
