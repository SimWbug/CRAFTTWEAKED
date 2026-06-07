-- ============================================================
--  DJ MIXER PRO  v8.1 (CORRIGÉ) |  CC:Tweaked
-- ============================================================
local dfpwm = require "cc.audio.dfpwm"
local API   = "https://ipod-2to6magyna-uc.a.run.app/"
local VER   = "2.1"
local W, H  = term.getSize()

-- ============================================================
--  PALETTE NEON CUSTOM
-- ============================================================
local function applyPalette()
  term.setPaletteColor(colors.black,     0x000000)
  term.setPaletteColor(colors.gray,      0x0a0a1a)
  term.setPaletteColor(colors.lightGray, 0x1e1e3a)
  term.setPaletteColor(colors.brown,     0x12122a)
  term.setPaletteColor(colors.cyan,      0x00e5ff)
  term.setPaletteColor(colors.lightBlue, 0x006080)
  term.setPaletteColor(colors.magenta,   0xff0080)
  term.setPaletteColor(colors.pink,      0x600030)
  term.setPaletteColor(colors.lime,      0x00ff44)
  term.setPaletteColor(colors.yellow,    0xffee00)
  term.setPaletteColor(colors.orange,    0xff6600)
  term.setPaletteColor(colors.red,       0xff1111)
  term.setPaletteColor(colors.green,     0x00cc55)
  term.setPaletteColor(colors.blue,      0x2255ff)
  term.setPaletteColor(colors.purple,    0xcc8800)
  term.setPaletteColor(colors.white,     0xffffff)
end

local function restorePalette()
  for i = 0, 15 do
    local c = 2^i
    term.setPaletteColor(c, term.nativePaletteColor(c))
  end
end

-- ============================================================
--  CODES COULEURS BLIT (hex 0-f)
-- ============================================================
local C = {
  BLACK    = "0", ORANGE   = "1", MAGENTA  = "2", LBLUE    = "3",
  YELLOW   = "4", LIME      = "5", PINK      = "6", GRAY     = "7",
  LGRAY    = "8", CYAN     = "9", PURPLE   = "a", BLUE     = "b",
  BROWN    = "c", GREEN    = "d", RED       = "e", WHITE    = "f",
}

-- ============================================================
--  DETECTION SPEAKERS
-- ============================================================
applyPalette()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.cyan)
print("DJ MIXER PRO v8.1 - Initialisation...")

local foundSpk = {}
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name) == "speaker" then
    local obj = peripheral.wrap(name)
    if obj and obj.playAudio then
      table.insert(foundSpk, { obj = obj, name = name })
    end
  end
end

if #foundSpk == 0 then
  restorePalette()
  error("Aucun speaker trouve ! Connectez des speakers.")
end

local spkL   = foundSpk[1].obj
local nameL  = foundSpk[1].name
local spkR   = foundSpk[2] and foundSpk[2].obj  or spkL
local nameR  = foundSpk[2] and foundSpk[2].name or nameL
local STEREO = #foundSpk >= 2

-- ============================================================
--  LAYOUT & ÉTAT
-- ============================================================
local MID = math.floor(W / 2)
local DA_X1, DA_X2 = 1, MID - 1
local DB_X1, DB_X2 = MID + 1, W

local Y_HDR, Y_DNAME, Y_TITLE, Y_ARTIST, Y_BTNS, Y_VOL = 1, 2, 3, 4, 5, 6
local Y_VU_TOP, Y_VU_BOT = 7, H - 6
local Y_SEPCF, Y_CF_BAR, Y_CF_LBL, Y_HELP, Y_STATUS = H-5, H-4, H-2, H-1, H

local CF_X1, CF_X2 = 9, W - 9
local CF_LEN = math.max(1, CF_X2 - CF_X1 + 1)

local cf, masterVol, beat = 0.5, 1.0, 0
local btnPos = { A = {}, B = {} }

local function newDeck(mainCol, darkCol, sideChar)
  return {
    title = "[ VIDE ]", artist = "", state = "stopped", handle = nil,
    dec = dfpwm.make_decoder(), vol = 1.0, status = "PRET",
    col = mainCol, darkCol = darkCol, side = sideChar, load = false
  }
end

local decks = { A = newDeck(C.CYAN, C.LBLUE, "L"), B = newDeck(C.MAGENTA, C.PINK, "R") }

-- ============================================================
--  HELPERS BLIT
-- ============================================================
local function rep(code, n) return string.rep(code, math.max(0, n)) end

local function blitRaw(x, y, text, fgs, bgs)
  if #text ~= #fgs or #text ~= #bgs then return end -- Sécurité anti-crash
  term.setCursorPos(x, y)
  term.blit(text, fgs, bgs)
end

local function fillBlit(x1, x2, y, fg_code, bg_code)
  local n = math.max(0, x2 - x1 + 1)
  blitRaw(x1, y, string.rep(" ", n), rep(fg_code, n), rep(bg_code, n))
end

-- ============================================================
--  DESSIN UI
-- ============================================================
local function drawHeader()
  fillBlit(1, W, Y_HDR, C.GRAY, C.GRAY)
  local title = " DJ MIXER PRO v8.1 "
  local tstart = math.floor((W - #title) / 2) + 1
  blitRaw(tstart, Y_HDR, title, rep(C.CYAN, 5)..rep(C.WHITE, 9)..rep(C.MAGENTA, 5), rep(C.GRAY, #title))
end

local function drawDeck(dk, x1, x2)
  local d = decks[dk]
  local dw = x2 - x1 + 1
  
  -- Header Deck
  fillBlit(x1, x2, Y_DNAME, d.col, C.BROWN)
  blitRaw(x1, Y_DNAME, " DECK "..dk, rep(d.col, 7), rep(C.BROWN, 7))
  
  -- Infos
  local tit = string.format("%-"..dw.."s", (d.state == "playing" and "> " or "  ")..d.title):sub(1, dw)
  blitRaw(x1, Y_TITLE, tit, rep(d.state == "playing" and d.col or C.LGRAY, dw), rep(C.GRAY, dw))
  
  local art = string.format("%-"..dw.."s", "  "..(d.artist ~= "" and d.artist or d.status)):sub(1, dw)
  blitRaw(x1, Y_ARTIST, art, rep(C.LGRAY, dw), rep(C.GRAY, dw))

  -- Boutons
  local bx = x1
  local function drawBtn(lbl, fg, bg, key)
    blitRaw(bx, Y_BTNS, lbl, rep(fg, #lbl), rep(bg, #lbl))
    btnPos[dk][key.."_x1"] = bx
    btnPos[dk][key.."_x2"] = bx + #lbl - 1
    bx = bx + #lbl + 1
  end
  drawBtn("PLAY", d.state == "playing" and C.GRAY or C.BLACK, d.state == "playing" and C.LGRAY or C.GREEN, "play")
  drawBtn("PAUSE", C.BLACK, d.state == "paused" and C.YELLOW or C.PURPLE, "paus")
  drawBtn("STOP", C.WHITE, C.RED, "stop")
  drawBtn("LOAD", C.WHITE, C.BLUE, "load")

  -- Volume
  blitRaw(x1, Y_VOL, "VOL", rep(C.LGRAY, 3), rep(C.GRAY, 3))
  local barW = dw - 8
  if barW > 0 then
    local lit = math.floor((d.vol / 1.5) * barW)
    blitRaw(x1+4, Y_VOL, rep(" ", barW), rep(C.LIME, barW), rep(C.LIME, lit)..rep(C.LGRAY, barW-lit))
  end
end

local function drawVU(dk, x1, x2)
  local d = decks[dk]
  local dw = x2 - x1 + 1
  local rows = Y_VU_BOT - Y_VU_TOP + 1
  local maxPx = rows * 2
  
  for r = 0, rows - 1 do
    local ly = Y_VU_TOP + r
    local h_base = (rows - r - 1) * 2
    local txt, fg, bg = "", "", ""
    for col = 0, dw - 1 do
      local lvl = (d.state == "playing") and (math.random(10, 100)/100) or 0
      if d.state == "playing" then lvl = lvl * d.vol * masterVol end
      local px = math.floor(lvl * maxPx)
      if px > h_base + 1 then txt=txt.." "; fg=fg..C.LIME; bg=bg..C.LIME
      elseif px > h_base then txt=txt..string.char(140); fg=fg..C.LIME; bg=bg..d.darkCol
      else txt=txt.." "; fg=fg..d.darkCol; bg=bg..d.darkCol end
    end
    blitRaw(x1, ly, txt, fg, bg)
  end
end

local function drawCrossfader()
  local knob = CF_X1 + math.floor(cf * (CF_LEN - 1))
  fillBlit(1, W, Y_CF_BAR, C.GRAY, C.GRAY)
  blitRaw(1, Y_CF_BAR, "A 100% [", rep(C.CYAN, 8), rep(C.GRAY, 8))
  blitRaw(W-7, Y_CF_BAR, "] 100% B", rep(C.MAGENTA, 8), rep(C.GRAY, 8))
  
  local bar = ""
  for x = CF_X1, CF_X2 do bar = bar .. (x == knob and "O" or "-") end
  blitRaw(CF_X1, Y_CF_BAR, bar, rep(C.WHITE, #bar), rep(C.GRAY, #bar))
  
  local help = "Q/P:Play L/O:Load </>:CF W/S/I/K:Vol"
  blitRaw(math.floor((W-#help)/2), Y_HELP, help, rep(C.LGRAY, #help), rep(C.GRAY, #help))
end

local function drawUI()
  term.setBackgroundColor(colors.gray)
  drawHeader()
  drawDeck("A", DA_X1, DA_X2)
  drawDeck("B", DB_X1, DB_X2)
  drawVU("A", DA_X1, DA_X2)
  drawVU("B", DB_X1, DB_X2)
  drawCrossfader()
  for y=2, Y_SEPCF do blitRaw(MID, y, "|", C.LGRAY, C.GRAY) end
end

-- ============================================================
--  LOGIQUE AUDIO & CHARGEMENT
-- ============================================================
local function loadSong(dk)
  local d = decks[dk]
  fillBlit(1, W, Y_STATUS, C.WHITE, C.BLUE)
  
  -- REPARATION ICI : Longueur dynamique
  local prompt = " RECHERCHE [" .. dk .. "]: "
  local len = #prompt
  blitRaw(1, Y_STATUS, prompt, rep(C.WHITE, len), rep(C.BLUE, len))
  
  term.setCursorPos(len + 1, Y_STATUS)
  term.setTextColor(colors.white)
  term.setBackgroundColor(colors.blue)
  local q = read()
  if not q or q == "" then return end

  d.status = "Chargement..."
  drawUI()
  
  local ok, err = pcall(function()
    local h = http.get(API .. "?v=" .. VER .. "&search=" .. textutils.urlEncode(q))
    if h then
      local data = textutils.unserialiseJSON(h.readAll())
      h.close()
      if data and data[1] then
        d.title, d.artist = data[1].name, data[1].artist
        if d.handle then d.handle.close() end
        d.handle = http.get({ url = API .. "?v=" .. VER .. "&id=" .. data[1].id, binary = true })
        d.dec = dfpwm.make_decoder()
        d.status = "PRET"
        return
      end
    end
    error("Introuvable")
  end)
  if not ok then d.title = "[ERREUR]"; d.status = "Inconnu" end
end

local function speakerLoop(spk, spkName, dk)
  while true do
    local d = decks[dk]
    if d.state == "playing" and d.handle then
      local chunk = d.handle.read(16384)
      if chunk then
        local buffer = d.dec(chunk)
        local vol = d.vol * masterVol * (dk == "A" and math.cos(cf*math.pi/2) or math.sin(cf*math.pi/2))
        while not spk.playAudio(buffer, vol) do os.pullEvent("speaker_audio_empty") end
      else
        d.state = "stopped"
      end
    else
      sleep(0.1)
    end
  end
end

-- ============================================================
--  BOUCLE PRINCIPALE
-- ============================================================
local function inputLoop()
  while true do
    drawUI()
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "key" then
      if p1 == keys.q then decks.A.state = (decks.A.state == "playing" and "stopped" or "playing")
      elseif p1 == keys.p then decks.B.state = (decks.B.state == "playing" and "stopped" or "playing")
      elseif p1 == keys.l then loadSong("A")
      elseif p1 == keys.o then loadSong("B")
      elseif p1 == keys.left then cf = math.max(0, cf - 0.05)
      elseif p1 == keys.right then cf = math.min(1, cf + 0.05)
      end
    elseif ev == "mouse_click" then
      local mx, my = p2, p3
      for dk, btn in pairs(btnPos) do
        if my == Y_BTNS then
          if mx >= btn.play_x1 and mx <= btn.play_x2 then decks[dk].state = "playing"
          elseif mx >= btn.paus_x1 and mx <= btn.paus_x2 then decks[dk].state = "paused"
          elseif mx >= btn.stop_x1 and mx <= btn.stop_x2 then decks[dk].state = "stopped"
          elseif mx >= btn.load_x1 and mx <= btn.load_x2 then loadSong(dk)
          end
        end
      end
    end
  end
end

-- Lancement avec pcall pour restaurer la palette quoi qu'il arrive
pcall(function()
  parallel.waitForAny(
    function() speakerLoop(spkL, nameL, "A") end,
    function() speakerLoop(spkR, nameR, "B") end,
    inputLoop
  )
end)

restorePalette()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
print("DJ Mixer Pro ferme.")
