-- ============================================================
--  DJ MIXER PRO  v8  |  CC:Tweaked
--  Interface neon avec palette custom, blit, demi-blocs VU
--  Boutons PLAY / PAUSE / STOP corriges
--  Crossfader visuel couleur pleine
-- ============================================================
local dfpwm = require "cc.audio.dfpwm"
local API   = "https://ipod-2to6magyna-uc.a.run.app/"
local VER   = "2.1"
local W, H  = term.getSize()

-- ============================================================
--  PALETTE NEON CUSTOM
--  On remappes les 16 couleurs CC en RGB personnalise
-- ============================================================
local function applyPalette()
  -- Fond et panneaux
  term.setPaletteColor(colors.black,     0x000000)  -- noir pur
  term.setPaletteColor(colors.gray,      0x0a0a1a)  -- fond fonce bleu nuit
  term.setPaletteColor(colors.lightGray, 0x1e1e3a)  -- panneau deck
  term.setPaletteColor(colors.brown,     0x12122a)  -- separateur/header deck
  -- Neon Deck A
  term.setPaletteColor(colors.cyan,      0x00e5ff)  -- neon cyan vif
  term.setPaletteColor(colors.lightBlue, 0x006080)  -- cyan sombre (bg deck A)
  -- Neon Deck B
  term.setPaletteColor(colors.magenta,   0xff0080)  -- neon rose vif
  term.setPaletteColor(colors.pink,      0x600030)  -- magenta sombre (bg deck B)
  -- VU meter
  term.setPaletteColor(colors.lime,      0x00ff44)  -- vert neon
  term.setPaletteColor(colors.yellow,    0xffee00)  -- jaune vif
  term.setPaletteColor(colors.orange,    0xff6600)  -- orange
  term.setPaletteColor(colors.red,       0xff1111)  -- rouge
  -- Boutons
  term.setPaletteColor(colors.green,     0x00cc55)  -- bouton play
  term.setPaletteColor(colors.blue,      0x2255ff)  -- bouton load
  term.setPaletteColor(colors.purple,    0xcc8800)  -- bouton pause
  -- Texte
  term.setPaletteColor(colors.white,     0xffffff)  -- blanc
end

-- Restaurer la palette CC par defaut a la fermeture
local function restorePalette()
  term.setPaletteColor(colors.black,     0x191919)
  term.setPaletteColor(colors.gray,      0x4c4c4c)
  term.setPaletteColor(colors.lightGray, 0x999999)
  term.setPaletteColor(colors.brown,     0x664c33)
  term.setPaletteColor(colors.cyan,      0x4c99b2)
  term.setPaletteColor(colors.lightBlue, 0x74b2ff)
  term.setPaletteColor(colors.magenta,   0xb24cd8)
  term.setPaletteColor(colors.pink,      0xf2b2cc)
  term.setPaletteColor(colors.lime,      0x7fcc19)
  term.setPaletteColor(colors.yellow,    0xdede6c)
  term.setPaletteColor(colors.orange,    0xf2b233)
  term.setPaletteColor(colors.red,       0xcc4c4c)
  term.setPaletteColor(colors.green,     0x57a64e)
  term.setPaletteColor(colors.blue,      0x3366cc)
  term.setPaletteColor(colors.purple,    0x7f3fb2)
  term.setPaletteColor(colors.white,     0xf0f0f0)
end

-- ============================================================
--  DETECTION SPEAKERS
-- ============================================================
applyPalette()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.cyan)
term.write("DJ MIXER PRO v8 - Recherche speakers...\n")
term.setTextColor(colors.lightGray)

local foundSpk = {}
for _, name in ipairs(peripheral.getNames()) do
  local types = { peripheral.getType(name) }
  for _, t in ipairs(types) do
    if t == "speaker" then
      local obj = peripheral.wrap(name)
      if obj and obj.playAudio then
        foundSpk[#foundSpk + 1] = { obj = obj, name = name }
        term.write("  OK: " .. name .. "\n")
      end
      break
    end
  end
end

if #foundSpk == 0 then
  term.setTextColor(colors.red)
  term.write("\nAucun speaker trouve !\n")
  for _, name in ipairs(peripheral.getNames()) do
    local t = { peripheral.getType(name) }
    term.write("  " .. name .. " [" .. table.concat(t, ",") .. "]\n")
  end
  term.write("Touche pour quitter...")
  os.pullEvent("key")
  restorePalette()
  error("Pas de speaker.")
end

local spkL   = foundSpk[1].obj
local nameL  = foundSpk[1].name
local spkR   = foundSpk[2] and foundSpk[2].obj  or spkL
local nameR  = foundSpk[2] and foundSpk[2].name or nameL
local STEREO = #foundSpk >= 2
sleep(0.3)

-- ============================================================
--  LAYOUT
-- ============================================================
local MID    = math.floor(W / 2)
local DA_X1  = 1;       local DA_X2  = MID - 1
local DB_X1  = MID + 1; local DB_X2  = W

-- Lignes
local Y_HDR     = 1    -- header neon
local Y_DNAME   = 2    -- nom deck + statut
local Y_TITLE   = 3    -- titre chanson
local Y_ARTIST  = 4    -- artiste
local Y_BTNS    = 5    -- [PLAY][PAUSE][STOP]  [LOAD]
local Y_VOL     = 6    -- barre volume
local Y_VU_TOP  = 7    -- debut VU (demi-blocs)
local Y_VU_BOT  = H - 6  -- fin VU
local Y_SEPCF   = H - 5  -- ligne sep avant CF
local Y_CF_BAR  = H - 4  -- barre crossfader
local Y_CF_PCT  = H - 3  -- pourcentages A/B
local Y_CF_LBL  = H - 2  -- label CROSSFADER
local Y_HELP    = H - 1  -- aide
local Y_STATUS  = H      -- status

-- S'assurer que le VU a au moins 1 ligne
if Y_VU_BOT < Y_VU_TOP then Y_VU_BOT = Y_VU_TOP end

-- Zone crossfader
local CF_PAD_L = 8   -- "A 100% ["
local CF_PAD_R = 8   -- "] 100% B"
local CF_X1    = CF_PAD_L + 1
local CF_X2    = W - CF_PAD_R
local CF_LEN   = math.max(1, CF_X2 - CF_X1 + 1)

-- ============================================================
--  CODES COULEURS BLIT  (hex 0-f)
-- ============================================================
local C = {
  BLACK    = "0",  -- colors.black
  ORANGE   = "1",  -- colors.orange    -> neon orange
  MAGENTA  = "2",  -- colors.magenta   -> neon magenta
  LBLUE    = "3",  -- colors.lightBlue -> cyan sombre
  YELLOW   = "4",  -- colors.yellow    -> jaune vif
  LIME     = "5",  -- colors.lime      -> vert neon
  PINK     = "6",  -- colors.pink      -> magenta sombre
  GRAY     = "7",  -- colors.gray      -> fond nuit
  LGRAY    = "8",  -- colors.lightGray -> panneau
  CYAN     = "9",  -- colors.cyan      -> neon cyan
  PURPLE   = "a",  -- colors.purple    -> bouton pause/or
  BLUE     = "b",  -- colors.blue      -> bouton load
  BROWN    = "c",  -- colors.brown     -> header deck sombre
  GREEN    = "d",  -- colors.green     -> bouton play
  RED      = "e",  -- colors.red       -> bouton stop/peak
  WHITE    = "f",  -- colors.white     -> texte blanc
}

-- ============================================================
--  ETAT
-- ============================================================
local cf        = 0.5
local masterVol = 1.0
local beat      = 0

-- Etats d'un deck : "stopped" | "playing" | "paused"
local function newDeck(mainCol, darkCol, sideChar)
  return {
    title    = "[ VIDE ]",
    artist   = "",
    state    = "stopped",  -- "stopped" | "playing" | "paused"
    handle   = nil,
    dec      = dfpwm.make_decoder(),
    vol      = 1.0,
    status   = "PRET",
    col      = mainCol,    -- code blit ex "9" (cyan)
    darkCol  = darkCol,    -- code blit fond sombre ex "3"
    side     = sideChar,   -- "L" ou "R"
    load     = false,
    lastBuf  = nil,
    vuLevels = {},         -- niveaux VU par colonne (cache)
  }
end

local decks = {
  A = newDeck(C.CYAN,    C.LBLUE, "L"),
  B = newDeck(C.MAGENTA, C.PINK,  "R"),
}

-- ============================================================
--  HELPERS BLIT
-- ============================================================
-- Construit des strings blit de longueur n avec un seul code
local function rep(code, n)
  return string.rep(code, n)
end

-- Ecrire une ligne entiere via blit (texte + couleurs uniformes)
local function blitLine(x, y, text, fg_code, bg_code)
  local n = #text
  term.setCursorPos(x, y)
  term.blit(text, rep(fg_code, n), rep(bg_code, n))
end

-- Blit avec fg et bg variables par caractere
local function blitRaw(x, y, text, fgs, bgs)
  term.setCursorPos(x, y)
  term.blit(text, fgs, bgs)
end

-- Remplir une zone en blit (fond uni)
local function fillBlit(x1, x2, y, fg_code, bg_code)
  local n = math.max(0, x2 - x1 + 1)
  if n == 0 then return end
  term.setCursorPos(x1, y)
  term.blit(string.rep(" ", n), rep(fg_code, n), rep(bg_code, n))
end

-- ============================================================
--  HEADER  (ligne 1)
--  Gradient neon cyan -> blanc -> magenta via blit
-- ============================================================
local function drawHeader()
  -- Fond gris nuit
  fillBlit(1, W, Y_HDR, C.GRAY, C.GRAY)

  -- Titre avec gradient couleur
  local title = " DJ MIXER PRO v8 "
  local tlen  = #title
  local tstart = math.floor((W - tlen) / 2) + 1

  -- Construction du gradient fg
  local fg_str = ""
  for i = 1, tlen do
    local pct = (i - 1) / (tlen - 1)
    if     pct < 0.3  then fg_str = fg_str .. C.CYAN
    elseif pct < 0.5  then fg_str = fg_str .. C.WHITE
    elseif pct < 0.7  then fg_str = fg_str .. C.WHITE
    else                   fg_str = fg_str .. C.MAGENTA
    end
  end
  blitRaw(tstart, Y_HDR, title, fg_str, rep(C.GRAY, tlen))

  -- Info master vol a gauche
  local volstr = "VOL:" .. math.floor(masterVol * 100) .. "%"
  blitRaw(1, Y_HDR, volstr, rep(C.YELLOW, #volstr), rep(C.GRAY, #volstr))

  -- Mode stereo a droite
  local modestr = STEREO and "STEREO" or " MONO "
  local modecol = STEREO and C.LIME or C.ORANGE
  blitRaw(W - #modestr + 1, Y_HDR, modestr, rep(modecol, #modestr), rep(C.GRAY, #modestr))
end

-- ============================================================
--  NOM DU DECK  (ligne 2)
--  Header colore avec statut a droite
-- ============================================================
local function drawDeckName(dk, x1, x2)
  local d  = decks[dk]
  local dw = x2 - x1 + 1

  -- Fond de la couleur du deck (sombre)
  fillBlit(x1, x2, Y_DNAME, d.col, C.BROWN)

  -- "DECK A [L]" a gauche
  local namestr = " DECK " .. dk
  if STEREO then namestr = namestr .. " [" .. d.side .. "]" end
  blitRaw(x1, Y_DNAME, namestr, rep(d.col, #namestr), rep(C.BROWN, #namestr))

  -- Statut a droite
  local stlbl, stfg, stbg
  if d.load then
    stlbl = " LOAD... "; stfg = C.BLACK; stbg = C.YELLOW
  elseif d.state == "playing" then
    stlbl = " LIVE "; stfg = C.BLACK; stbg = C.LIME
  elseif d.state == "paused" then
    stlbl = " PAUSE"; stfg = C.BLACK; stbg = C.PURPLE
  else
    stlbl = " STOP "; stfg = C.WHITE; stbg = C.RED
  end
  local slen = math.min(#stlbl, dw - #namestr)
  if slen > 0 then
    blitRaw(x2 - slen + 1, Y_DNAME, stlbl:sub(1, slen),
            rep(stfg, slen), rep(stbg, slen))
  end
end

-- ============================================================
--  TITRE ET ARTISTE  (lignes 3-4)
-- ============================================================
local function drawDeckInfo(dk, x1, x2)
  local d  = decks[dk]
  local dw = x2 - x1 + 1

  -- Titre avec indicateur animation
  local pfx = ""
  if d.state == "playing" then
    local spin = {">  ", ">> ", ">>>", " >>", "  >", "   "}
    pfx = spin[(beat % 6) + 1] .. " "
  elseif d.state == "paused" then
    pfx = "|| "
  else
    pfx = "   "
  end
  local titraw = pfx .. d.title
  local titdisp = string.format("%-" .. dw .. "s", titraw:sub(1, dw))
  -- Titre : couleur du deck si playing, gris si stopped
  local titcol = d.state == "playing" and d.col or C.LGRAY
  blitRaw(x1, Y_TITLE, titdisp, rep(titcol, dw), rep(C.GRAY, dw))

  -- Artiste
  local artraw  = "  " .. (d.artist ~= "" and d.artist or d.status)
  local artdisp = string.format("%-" .. dw .. "s", artraw:sub(1, dw))
  blitRaw(x1, Y_ARTIST, artdisp, rep(C.LGRAY, dw), rep(C.GRAY, dw))
end

-- ============================================================
--  BOUTONS  (ligne 5)
--  [PLAY] [PAUS] [STOP]  [LOAD]  (cliquables, clic detectable)
-- ============================================================
-- Retourne les positions X des boutons pour la detection clic
local btnPos = { A = {}, B = {} }

local function drawDeckButtons(dk, x1, x2)
  local d  = decks[dk]
  local dw = x2 - x1 + 1

  -- Fond de la ligne
  fillBlit(x1, x2, Y_BTNS, C.GRAY, C.GRAY)

  local cx = x1

  -- [PLAY]
  local play_fg = d.state == "playing" and C.GRAY or C.BLACK
  local play_bg = d.state == "playing" and C.LGRAY or C.GREEN
  blitRaw(cx, Y_BTNS, "PLAY", rep(play_fg, 4), rep(play_bg, 4))
  btnPos[dk].play_x1 = cx; btnPos[dk].play_x2 = cx + 3
  cx = cx + 5

  -- [PAUS]
  local pau_fg = d.state == "paused" and C.BLACK or C.BLACK
  local pau_bg = d.state == "paused" and C.YELLOW or C.PURPLE
  blitRaw(cx, Y_BTNS, "PAUS", rep(pau_fg, 4), rep(pau_bg, 4))
  btnPos[dk].paus_x1 = cx; btnPos[dk].paus_x2 = cx + 3
  cx = cx + 5

  -- [STOP]
  local stp_fg = d.state == "stopped" and C.GRAY or C.WHITE
  local stp_bg = d.state == "stopped" and C.LGRAY or C.RED
  blitRaw(cx, Y_BTNS, "STOP", rep(stp_fg, 4), rep(stp_bg, 4))
  btnPos[dk].stop_x1 = cx; btnPos[dk].stop_x2 = cx + 3
  cx = cx + 6

  -- [LOAD]
  blitRaw(cx, Y_BTNS, "LOAD", rep(C.WHITE, 4), rep(C.BLUE, 4))
  btnPos[dk].load_x1 = cx; btnPos[dk].load_x2 = cx + 3
end

-- ============================================================
--  VOLUME  (ligne 6)
-- ============================================================
local function drawDeckVol(dk, x1, x2)
  local d  = decks[dk]
  local dw = x2 - x1 + 1

  fillBlit(x1, x2, Y_VOL, C.GRAY, C.GRAY)

  -- Label "VOL"
  blitRaw(x1, Y_VOL, "VOL", rep(C.LGRAY, 3), rep(C.GRAY, 3))

  -- Barre
  local barW = dw - 8
  if barW > 0 then
    local lit = math.floor(d.vol / 1.5 * barW)
    local bar_t = ""
    local bar_f = ""
    local bar_b = ""
    for i = 1, barW do
      if i <= lit then
        local pct = i / barW
        -- Degrade vert -> jaune -> orange
        local c = pct > 0.85 and C.ORANGE or (pct > 0.65 and C.YELLOW or C.LIME)
        bar_t = bar_t .. " "
        bar_f = bar_f .. c
        bar_b = bar_b .. c
      else
        bar_t = bar_t .. " "
        bar_f = bar_f .. C.LGRAY
        bar_b = bar_b .. C.LGRAY
      end
    end
    blitRaw(x1 + 4, Y_VOL, bar_t, bar_f, bar_b)
  end

  -- Pourcentage
  local pct_str = string.format("%3d%%", math.floor(d.vol * 100))
  blitRaw(x2 - 3, Y_VOL, pct_str, rep(C.WHITE, 4), rep(C.GRAY, 4))
end

-- ============================================================
--  VU-METRE DEMI-BLOCS  (lignes Y_VU_TOP .. Y_VU_BOT)
--  Resolution double par demi-blocs \140 (haut) et \131 (bas)
-- ============================================================
-- Caracteres demi-blocs CC (codes decimal)
local HALF_TOP = string.char(140)  -- pixels haut remplis
local HALF_BOT = string.char(131)  -- pixels bas remplis
local FULL_BLK = " "               -- espace avec bg = bloc plein

local function vuColor(pct)
  -- pct = position 0..1 dans la barre (normalisee)
  if     pct > 0.88 then return C.RED
  elseif pct > 0.72 then return C.ORANGE
  elseif pct > 0.50 then return C.YELLOW
  else                    return C.LIME
  end
end

local function drawVU(dk, x1, x2)
  local d    = decks[dk]
  local dw   = x2 - x1 + 1
  local rows = Y_VU_BOT - Y_VU_TOP + 1
  if rows < 1 then return end
  local maxPx = rows * 2  -- hauteur totale en demi-pixels

  for row = 1, rows do
    local line_y    = Y_VU_TOP + row - 1
    local px_top    = (rows - row) * 2      -- pixel "haut" de ce row (de bas en haut)
    local px_bot    = px_top + 1

    local text_t = ""
    local fg_t   = ""
    local bg_t   = ""

    for xi = 0, dw - 1 do
      local pct_x = xi / math.max(1, dw - 1)  -- position 0..1 dans la largeur

      -- Niveau pour cette colonne
      local lvl
      if d.state == "playing" then
        local s1 = (xi * 17 + beat * 11) % 31
        local s2 = (xi * 7  + beat * 5 + row * 3) % 19
        lvl = (s1 / 30) * 0.55 + (s2 / 18) * 0.45
        -- Attenuation crossfader
        local angle   = cf * math.pi / 2
        local cfgain  = dk == "A" and math.cos(angle) or math.sin(angle)
        lvl = lvl * d.vol * cfgain * masterVol
      elseif d.state == "paused" then
        -- Niveau tres bas fige (ondulation lente)
        local s = (xi * 3 + math.floor(beat / 8)) % 7
        lvl = 0.05 + (s / 6) * 0.08
      else
        lvl = 0
      end

      -- Hauteur en demi-pixels (0..maxPx)
      local height = math.floor(lvl * maxPx)

      -- Rendu du demi-pixel haut et bas de ce row
      local top_lit = height > px_top
      local bot_lit = height > px_bot

      local c = vuColor(pct_x)
      local dark = d.darkCol  -- fond sombre du deck

      if top_lit and bot_lit then
        -- Les deux pixels allumes : fond colore = bloc plein
        text_t = text_t .. FULL_BLK
        fg_t   = fg_t   .. c
        bg_t   = bg_t   .. c
      elseif top_lit then
        -- Seulement le pixel haut : demi-bloc haut
        text_t = text_t .. HALF_TOP
        fg_t   = fg_t   .. c
        bg_t   = bg_t   .. dark
      elseif bot_lit then
        -- Seulement le pixel bas : demi-bloc bas
        text_t = text_t .. HALF_BOT
        fg_t   = fg_t   .. c
        bg_t   = bg_t   .. dark
      else
        -- Rien : fond sombre
        text_t = text_t .. FULL_BLK
        fg_t   = fg_t   .. dark
        bg_t   = bg_t   .. dark
      end
    end

    term.setCursorPos(x1, line_y)
    term.blit(text_t, fg_t, bg_t)
  end
end

-- ============================================================
--  CROSSFADER  (lignes Y_SEPCF .. Y_CF_LBL)
-- ============================================================
local function drawCrossfader()
  -- Separateur
  local sep = string.rep("-", W)
  blitRaw(1, Y_SEPCF, sep, rep(C.LGRAY, W), rep(C.GRAY, W))

  -- Gains equal-power
  local angle = cf * math.pi / 2
  local pctA  = math.floor(math.cos(angle) * 100 + 0.5)
  local pctB  = math.floor(math.sin(angle) * 100 + 0.5)

  -- Labels gauche/droite de la barre
  local lblL = string.format("A%3d%%[", pctA)  -- 7 chars
  local lblR = string.format("]%3d%%B", pctB)  -- 7 chars
  blitRaw(1, Y_CF_BAR, lblL, rep(C.CYAN, #lblL), rep(C.GRAY, #lblL))
  blitRaw(W - #lblR + 1, Y_CF_BAR, lblR, rep(C.MAGENTA, #lblR), rep(C.GRAY, #lblR))

  -- Barre coloree
  local knob = CF_X1 + math.floor(cf * (CF_LEN - 1))

  local bar_t = ""
  local bar_f = ""
  local bar_b = ""

  for x = CF_X1, CF_X2 do
    if x == knob then
      -- Curseur en blanc sur fond jaune
      bar_t = bar_t .. "O"
      bar_f = bar_f .. C.BROWN
      bar_b = bar_b .. C.YELLOW
    elseif x < knob then
      -- Zone A : gradient cyan fonce -> cyan vif vers le centre
      local t   = (x - CF_X1) / math.max(1, knob - CF_X1)
      local col = t > 0.7 and C.CYAN or (t > 0.3 and C.LBLUE or C.LGRAY)
      bar_t = bar_t .. " "
      bar_f = bar_f .. col
      bar_b = bar_b .. col
    else
      -- Zone B : gradient magenta vif -> sombre
      local t   = (x - knob) / math.max(1, CF_X2 - knob)
      local col = t < 0.3 and C.MAGENTA or (t < 0.7 and C.PINK or C.LGRAY)
      bar_t = bar_t .. " "
      bar_f = bar_f .. col
      bar_b = bar_b .. col
    end
  end

  term.setCursorPos(CF_X1, Y_CF_BAR)
  term.blit(bar_t, bar_f, bar_b)

  -- Label CROSSFADER + indicateur position
  fillBlit(1, W, Y_CF_LBL, C.LGRAY, C.GRAY)
  local cflbl = "CROSSFADER"
  blitRaw(MID - 4, Y_CF_LBL, cflbl, rep(C.LGRAY, #cflbl), rep(C.GRAY, #cflbl))

  -- Indicateur textuel de position
  local pos
  if     cf < 0.05 then pos = "<<< FULL A"
  elseif cf < 0.35 then pos = "<<<  A>>"
  elseif cf < 0.55 then pos = "    MIX    "
  elseif cf < 0.85 then pos = "  <<B  >>>"
  else                   pos = "FULL B >>>"
  end
  local pocol = cf < 0.5 and C.CYAN or (cf > 0.5 and C.MAGENTA or C.WHITE)
  blitRaw(W - #pos, Y_CF_LBL, pos, rep(pocol, #pos), rep(C.GRAY, #pos))

  -- Aide clavier
  fillBlit(1, W, Y_HELP, C.LGRAY, C.GRAY)
  local help = "Q:play P:play L:load O:load </> CF  W/S I/K vol  C=center Z=A X=B"
  blitRaw(1, Y_HELP, help:sub(1, W), rep(C.LGRAY, math.min(W, #help)), rep(C.GRAY, math.min(W, #help)))
end

-- ============================================================
--  SEPARATEUR CENTRAL  (toute la hauteur)
-- ============================================================
local function drawSeparator()
  for y = Y_DNAME, Y_SEPCF - 1 do
    term.setCursorPos(MID, y)
    term.blit("|", C.LGRAY, C.GRAY)
  end
end

-- ============================================================
--  UI COMPLETE
-- ============================================================
local function drawUI()
  -- Fond global
  term.setBackgroundColor(colors.gray)
  term.clear()

  drawHeader()
  drawSeparator()

  drawDeckName("A", DA_X1, DA_X2)
  drawDeckName("B", DB_X1, DB_X2)
  drawDeckInfo("A", DA_X1, DA_X2)
  drawDeckInfo("B", DB_X1, DB_X2)
  drawDeckButtons("A", DA_X1, DA_X2)
  drawDeckButtons("B", DB_X1, DB_X2)
  drawDeckVol("A", DA_X1, DA_X2)
  drawDeckVol("B", DB_X1, DB_X2)
  drawVU("A", DA_X1, DA_X2)
  drawVU("B", DB_X1, DB_X2)
  drawCrossfader()

  -- Status bas
  fillBlit(1, W, Y_STATUS, C.LGRAY, C.GRAY)
end

-- ============================================================
--  AUDIO : crossfader equal-power
-- ============================================================
local function cfGain(dk)
  local angle = cf * math.pi / 2
  return dk == "A" and math.cos(angle) or math.sin(angle)
end

-- ============================================================
--  BOUCLE AUDIO STEREO
-- ============================================================
local function speakerLoop(spk, spkName, deckKey)
  while true do
    local d = decks[deckKey]

    -- Jouer seulement si "playing" (pas "paused" ni "stopped")
    if d.state ~= "playing" then
      sleep(0.05)
    else
      local rawBuf = nil

      if d.handle then
        local chunk = d.handle.read(16 * 1024)
        if chunk then
          rawBuf    = d.dec(chunk)
          d.lastBuf = rawBuf
        else
          d.state  = "stopped"
          d.status = "FIN"
        end
      end

      if rawBuf then
        beat = beat + 1

        local vol    = cfGain(deckKey) * d.vol * masterVol
        local panVol
        if deckKey == "A" then
          panVol = (spk == spkL) and vol or vol * 0.07
        else
          panVol = (spk == spkR) and vol or vol * 0.07
        end
        panVol = math.min(3.0, panVol * 3.0)

        local ok = spk.playAudio(rawBuf, panVol)
        if not ok then
          repeat
            local _, evName = os.pullEvent("speaker_audio_empty")
          until evName == spkName
          spk.playAudio(rawBuf, panVol)
        end
      else
        sleep(0.05)
      end
    end
  end
end

-- ============================================================
--  BOUCLE AUDIO MONO
-- ============================================================
local function monoLoop()
  while true do
    local dA    = decks.A
    local dB    = decks.B
    local playA = dA.state == "playing"
    local playB = dB.state == "playing"

    if not playA and not playB then
      sleep(0.05)
    else
      local gA = cfGain("A") * dA.vol * masterVol
      local gB = cfGain("B") * dB.vol * masterVol

      local bufA = nil
      if playA and dA.handle then
        local c = dA.handle.read(16 * 1024)
        if c then bufA = dA.dec(c); dA.lastBuf = bufA
        else dA.state = "stopped"; dA.status = "FIN" end
      end

      local bufB = nil
      if playB and dB.handle then
        local c = dB.handle.read(16 * 1024)
        if c then bufB = dB.dec(c); dB.lastBuf = bufB
        else dB.state = "stopped"; dB.status = "FIN" end
      end

      local mix = nil
      if bufA and bufB then
        local n = math.min(#bufA, #bufB)
        mix = {}
        for i = 1, n do
          local v = bufA[i] * gA + bufB[i] * gB
          if v >  1 then v =  1 end
          if v < -1 then v = -1 end
          mix[i] = v
        end
        beat = beat + 1
      elseif bufA then
        mix = bufA; for i=1,#mix do mix[i]=mix[i]*gA end; beat=beat+1
      elseif bufB then
        mix = bufB; for i=1,#mix do mix[i]=mix[i]*gB end; beat=beat+1
      end

      if mix then
        local ok = spkL.playAudio(mix, 3.0)
        if not ok then
          repeat local _,n2=os.pullEvent("speaker_audio_empty") until n2==nameL
          spkL.playAudio(mix, 3.0)
        end
      else
        sleep(0.05)
      end
    end
  end
end

-- ============================================================
--  CHARGEMENT
-- ============================================================
local function loadSong(dk)
  local d = decks[dk]

  -- Prompt en bas
  fillBlit(1, W, Y_STATUS, C.WHITE, C.GRAY)
  blitRaw(1, Y_STATUS, " Recherche [" .. dk .. "]: ",
    rep(C.WHITE, 15), rep(C.BLUE, 15))
  term.setCursorPos(16, Y_STATUS)
  term.setTextColor(colors.white)
  term.setBackgroundColor(colors.gray)
  local q = read()
  if not q or q == "" then return end

  d.load   = true
  d.status = "Chargement..."
  drawUI()

  local ok, err = pcall(function()
    local h = http.get(API .. "?v=" .. VER .. "&search=" .. textutils.urlEncode(q))
    if not h then error("HTTP fail") end
    local data = textutils.unserialiseJSON(h.readAll()); h.close()
    if not (data and data[1]) then error("Aucun resultat") end
    local s = data[1]
    d.title  = s.name   or "Inconnu"
    d.artist = s.artist or ""
    if d.handle then pcall(function() d.handle.close() end) end
    d.handle  = http.get({ url = API .. "?v=" .. VER .. "&id=" .. s.id, binary = true })
    if not d.handle then error("Stream fail") end
    d.dec     = dfpwm.make_decoder()
    d.lastBuf = nil
    d.status  = "PRET"
  end)

  if not ok then
    d.title  = "[ ERREUR ]"
    d.status = "Err: " .. tostring(err):sub(1, 18)
  end
  d.load = false
end

-- ============================================================
--  CROSSFADER helper
-- ============================================================
local function setCF(x)
  cf = math.max(0, math.min(1, (x - CF_X1) / math.max(1, CF_LEN - 1)))
end

-- ============================================================
--  INPUT LOOP
-- ============================================================
local function inputLoop()
  while true do
    drawUI()
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "key" then
      local k = p1

      -- Play (toggle playing/stopped, depuis paused aussi)
      if     k == keys.q then
        local d = decks.A
        if     d.state == "stopped" then d.state = "playing"
        elseif d.state == "playing" then d.state = "stopped"
        elseif d.state == "paused"  then d.state = "playing"
        end
      elseif k == keys.p then
        local d = decks.B
        if     d.state == "stopped" then d.state = "playing"
        elseif d.state == "playing" then d.state = "stopped"
        elseif d.state == "paused"  then d.state = "playing"
        end

      -- Pause
      elseif k == keys.e then
        if decks.A.state == "playing" then decks.A.state = "paused"
        elseif decks.A.state == "paused" then decks.A.state = "playing" end
      elseif k == keys.u then
        if decks.B.state == "playing" then decks.B.state = "paused"
        elseif decks.B.state == "paused" then decks.B.state = "playing" end

      -- Stop hard
      elseif k == keys.r then decks.A.state = "stopped"
      elseif k == keys.y then decks.B.state = "stopped"

      -- Load
      elseif k == keys.l then loadSong("A")
      elseif k == keys.o then loadSong("B")

      -- Crossfader
      elseif k == keys.left  or k == keys.comma  then cf = math.max(0, cf - 0.05)
      elseif k == keys.right or k == keys.period then cf = math.min(1, cf + 0.05)
      elseif k == keys.c then cf = 0.5
      elseif k == keys.z then cf = 0.0
      elseif k == keys.x then cf = 1.0

      -- Volume master
      elseif k == keys.up   then masterVol = math.min(2.0, masterVol + 0.1)
      elseif k == keys.down then masterVol = math.max(0.0, masterVol - 0.1)

      -- Volume deck A
      elseif k == keys.w then decks.A.vol = math.min(1.5, decks.A.vol + 0.1)
      elseif k == keys.s then decks.A.vol = math.max(0.0, decks.A.vol - 0.1)

      -- Volume deck B
      elseif k == keys.i then decks.B.vol = math.min(1.5, decks.B.vol + 0.1)
      elseif k == keys.k then decks.B.vol = math.max(0.0, decks.B.vol - 0.1)
      end

    -- ---- Souris clic ---
    elseif ev == "mouse_click" then
      local mx, my = p2, p3

      -- Crossfader
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)

      -- Deck A
      elseif mx >= DA_X1 and mx < MID then
        local d = decks.A
        if my == Y_DNAME then
          -- Clic header = toggle play/stop
          if d.state == "playing" or d.state == "paused" then d.state = "stopped"
          else d.state = "playing" end
        elseif my == Y_BTNS then
          local b = btnPos.A
          if mx >= b.play_x1 and mx <= b.play_x2 then
            if d.state ~= "playing" then d.state = "playing"
            else d.state = "stopped" end
          elseif mx >= b.paus_x1 and mx <= b.paus_x2 then
            if d.state == "playing" then d.state = "paused"
            elseif d.state == "paused" then d.state = "playing" end
          elseif mx >= b.stop_x1 and mx <= b.stop_x2 then
            d.state = "stopped"
          elseif mx >= b.load_x1 and mx <= b.load_x2 then
            loadSong("A")
          end
        elseif my == Y_VOL then
          local barX1 = DA_X1 + 4
          local barW  = (DA_X2 - DA_X1 + 1) - 8
          if mx >= barX1 and barW > 0 then
            d.vol = math.min(1.5, ((mx - barX1) / barW) * 1.5)
          end
        end

      -- Deck B
      elseif mx > MID and mx <= DB_X2 then
        local d = decks.B
        if my == Y_DNAME then
          if d.state == "playing" or d.state == "paused" then d.state = "stopped"
          else d.state = "playing" end
        elseif my == Y_BTNS then
          local b = btnPos.B
          if mx >= b.play_x1 and mx <= b.play_x2 then
            if d.state ~= "playing" then d.state = "playing"
            else d.state = "stopped" end
          elseif mx >= b.paus_x1 and mx <= b.paus_x2 then
            if d.state == "playing" then d.state = "paused"
            elseif d.state == "paused" then d.state = "playing" end
          elseif mx >= b.stop_x1 and mx <= b.stop_x2 then
            d.state = "stopped"
          elseif mx >= b.load_x1 and mx <= b.load_x2 then
            loadSong("B")
          end
        elseif my == Y_VOL then
          local barX1 = DB_X1 + 4
          local barW  = (DB_X2 - DB_X1 + 1) - 8
          if mx >= barX1 and barW > 0 then
            d.vol = math.min(1.5, ((mx - barX1) / barW) * 1.5)
          end
        end
      end

    -- ---- Souris drag CF ---
    elseif ev == "mouse_drag" then
      local mx, my = p2, p3
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)
      end
    end
  end
end

-- ============================================================
--  SPLASH NEON
-- ============================================================
term.setBackgroundColor(colors.black)
term.clear()
local sy = math.max(1, math.floor(H / 2) - 4)
local function sp(y, text, fg_code, bg_code)
  local fc = bg_code or C.BLACK
  local x  = math.max(1, math.floor((W - #text) / 2) + 1)
  term.setCursorPos(x, y)
  term.blit(text, rep(fg_code, #text), rep(fc, #text))
end

-- Logo ASCII art DJ
sp(sy,   "+================================+", C.CYAN,    C.BLACK)
sp(sy+1, "|      DJ  MIXER  PRO  v8        |", C.WHITE,   C.BLACK)
sp(sy+2, "|   Palette neon | blit VU-metre |", C.LGRAY,  C.BLACK)
sp(sy+3, "+================================+", C.MAGENTA, C.BLACK)
sp(sy+4, "", C.WHITE, C.BLACK)
sp(sy+5, STEREO and ("STEREO  -  " .. #foundSpk .. " speakers")
               or    "MONO  -  1 speaker",
   STEREO and C.LIME or C.ORANGE, C.BLACK)
for i, s in ipairs(foundSpk) do
  local role = i == 1 and "[L] " or i == 2 and "[R] " or "    "
  local ln   = role .. s.name
  sp(sy + 6 + i, ln, i == 1 and C.CYAN or C.MAGENTA, C.BLACK)
end
sp(sy+9, "Demarrage...", C.LGRAY, C.BLACK)
sleep(1.2)

-- ============================================================
--  LANCEMENT
-- ============================================================
if STEREO then
  parallel.waitForAny(
    function() speakerLoop(spkL, nameL, "A") end,
    function() speakerLoop(spkR, nameR, "B") end,
    inputLoop
  )
else
  parallel.waitForAny(monoLoop, inputLoop)
end

restorePalette()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.white)
term.write("DJ Mixer Pro v8 ferme.")
