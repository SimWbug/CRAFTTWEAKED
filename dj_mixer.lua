-- ============================================================
--  DJ MIXER PRO  v7  |  CC:Tweaked
--  Interface ASCII pure - pas de FX - crossfader visuel
-- ============================================================
local dfpwm = require "cc.audio.dfpwm"
local API   = "https://ipod-2to6magyna-uc.a.run.app/"
local VER   = "2.1"
local W, H  = term.getSize()

-- ============================================================
--  DETECTION SPEAKERS
-- ============================================================
local foundSpk = {}
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.yellow)
term.write("Recherche speakers...\n")
term.setTextColor(colors.gray)

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
  term.write("Peripheriques detectes:\n")
  for _, name in ipairs(peripheral.getNames()) do
    local t = { peripheral.getType(name) }
    term.write("  " .. name .. " [" .. table.concat(t, ",") .. "]\n")
  end
  term.write("Appuie sur une touche...")
  os.pullEvent("key")
  error("Pas de speaker.")
end

local spkL   = foundSpk[1].obj
local nameL  = foundSpk[1].name
local spkR   = foundSpk[2] and foundSpk[2].obj  or spkL
local nameR  = foundSpk[2] and foundSpk[2].name or nameL
local STEREO = #foundSpk >= 2
sleep(0.4)

-- ============================================================
--  LAYOUT  (zones calculees depuis W et H)
-- ============================================================
-- Colonne separatrice centrale
local MID    = math.floor(W / 2)

-- Zones X des decks
local DA_X1  = 1
local DA_X2  = MID - 1        -- deck A
local DB_X1  = MID + 1
local DB_X2  = W              -- deck B

-- Lignes fixes
local Y_TOP     = 1           -- header
local Y_BOX1    = 2           -- bord haut boite decks
local Y_DNAME   = 3           -- nom du deck + statut
local Y_TITLE   = 4           -- titre chanson
local Y_ARTIST  = 5           -- artiste
local Y_BOX2    = 6           -- separation
local Y_BUTTONS = 7           -- play/stop + load
local Y_VOL     = 8           -- barre volume
local Y_BOX3    = 9           -- separation
local Y_VU_TOP  = 10          -- debut VU-metre
local Y_VU_BOT  = H - 5       -- fin VU-metre
local Y_BOX4    = H - 4       -- bord bas
local Y_CF_BAR  = H - 3       -- barre crossfader
local Y_CF_LBL  = H - 2       -- label crossfader
local Y_HELP    = H - 1       -- aide clavier
local Y_STATUS  = H           -- messages d'etat

-- Crossfader: la barre commence apres "A 100% [" et finit avant "] 0% B"
-- On reserve 9 chars a gauche et 8 a droite
local CF_MARGIN_L = 9         -- " A 100% ["
local CF_MARGIN_R = 8         -- "] 100% B "
local CF_X1  = CF_MARGIN_L + 1
local CF_X2  = W - CF_MARGIN_R
local CF_LEN = CF_X2 - CF_X1 + 1

-- ============================================================
--  ETAT
-- ============================================================
local cf        = 0.5   -- 0.0 = full A, 1.0 = full B
local masterVol = 1.0
local beat      = 0

local function newDeck(col, side)
  return {
    title   = "[ VIDE ]",
    artist  = "",
    playing = false,
    handle  = nil,
    dec     = dfpwm.make_decoder(),
    vol     = 1.0,
    status  = "PRET",
    col     = col,
    side    = side,    -- "L" ou "R"
    load    = false,
    lastBuf = nil,
    vuLevel = 0,       -- niveau VU courant (0..1)
  }
end

local decks = {
  A = newDeck(colors.cyan,    "L"),
  B = newDeck(colors.magenta, "R"),
}

-- ============================================================
--  HELPERS DESSIN  (100% ASCII-safe)
-- ============================================================
local function at(x, y)   term.setCursorPos(x, y) end
local function fg(c)      term.setTextColor(c) end
local function bg(c)      term.setBackgroundColor(c) end
local function cls()      bg(colors.black); term.clear() end

-- Remplir une zone de x1 a x2 sur la ligne y avec le caractere ch
local function fill(x1, x2, y, ch, fcol, bcol)
  if x2 < x1 then return end
  bg(bcol or colors.black)
  fg(fcol or colors.white)
  at(x1, y)
  term.write(string.rep(ch, x2 - x1 + 1))
  bg(colors.black)
end

-- Ecrire du texte tronque a w caracteres, padding espace
local function txtp(x, y, s, w, fcol, bcol)
  if bcol then bg(bcol) else bg(colors.black) end
  fg(fcol or colors.white)
  at(x, y)
  local fmt = string.format("%-" .. w .. "s", s:sub(1, w))
  term.write(fmt)
  bg(colors.black)
end

-- Ligne de separation type boite ASCII
local function hline(x1, x2, y, left, mid, right)
  -- left/mid/right = "+", "-" etc.
  bg(colors.black); fg(colors.gray)
  at(x1, y); term.write(left)
  at(x2, y); term.write(right)
  for x = x1 + 1, x2 - 1 do
    at(x, y)
    if x == MID then term.write(mid)
    else             term.write("-") end
  end
end

-- ============================================================
--  DESSIN D'UN DECK
-- ============================================================
local function drawDeck(dk, x1, x2)
  local d  = decks[dk]
  local dw = x2 - x1 + 1

  -- ---- Nom deck + statut (ligne Y_DNAME) -------------------
  -- Header colore du deck
  fill(x1, x2, Y_DNAME, " ", colors.black, d.col)
  bg(d.col); fg(colors.black)
  at(x1, Y_DNAME)
  local hdr = " DECK " .. dk
  if STEREO then hdr = hdr .. " [" .. d.side .. "]" end
  term.write(hdr)

  -- Statut a droite dans le header
  local stlbl, stfg, stbg
  if d.load then
    stlbl = " CHARGEMENT "; stfg = colors.black; stbg = colors.yellow
  elseif d.playing then
    stlbl = " EN LECTURE "; stfg = colors.black; stbg = colors.lime
  else
    stlbl = "    ARRETE  "; stfg = colors.white; stbg = colors.red
  end
  -- Coller le statut a droite du header
  local slen = math.min(#stlbl, dw - #hdr)
  if slen > 0 then
    bg(stbg); fg(stfg)
    at(x2 - slen + 1, Y_DNAME)
    term.write(stlbl:sub(1, slen))
  end

  -- ---- Titre (ligne Y_TITLE) --------------------------------
  local titdisp = d.title
  if d.playing then
    -- Petit indicateur visuel selon le beat
    local spin = { ">", ">>", ">>>", ">>" }
    titdisp = spin[(beat % 4) + 1] .. " " .. d.title
  end
  txtp(x1, Y_TITLE, " " .. titdisp, dw, colors.white, colors.black)

  -- ---- Artiste (ligne Y_ARTIST) ----------------------------
  local art = d.artist ~= "" and d.artist or ("  [" .. d.status .. "]")
  txtp(x1, Y_ARTIST, " " .. art, dw, colors.lightGray, colors.black)

  -- ---- Boutons PLAY/STOP et LOAD (ligne Y_BUTTONS) ---------
  fill(x1, x2, Y_BUTTONS, " ", colors.black, colors.black)

  -- Bouton PLAY / STOP
  if d.playing then
    bg(colors.red); fg(colors.white)
    at(x1, Y_BUTTONS); term.write(" STOP ")
  else
    bg(colors.green); fg(colors.black)
    at(x1, Y_BUTTONS); term.write(" PLAY ")
  end

  -- Bouton LOAD
  bg(colors.blue); fg(colors.white)
  at(x1 + 7, Y_BUTTONS); term.write(" LOAD ")
  bg(colors.black)

  -- ---- Volume (ligne Y_VOL) --------------------------------
  fill(x1, x2, Y_VOL, " ", colors.lightGray, colors.black)
  fg(colors.lightGray); at(x1, Y_VOL); term.write(" VOL:")

  local pctlbl = string.format("%3d%%", math.floor(d.vol * 100))
  local barW   = dw - 11   -- " VOL:" (5) + " " + pctlbl (4) + " " = 11
  if barW > 2 then
    -- Barre volume
    local lit = math.floor(d.vol / 1.5 * barW)
    bg(colors.black); fg(colors.lime)
    at(x1 + 6, Y_VOL)
    for i = 1, barW do
      if i <= lit then
        bg(colors.lime); term.write(" ")
      else
        bg(colors.gray); term.write(" ")
      end
    end
    bg(colors.black)
  end
  -- Pourcentage
  fg(colors.white); at(x2 - 3, Y_VOL)
  term.write(pctlbl)

  -- ---- VU-metre (lignes Y_VU_TOP a Y_VU_BOT) ---------------
  local vuH = Y_VU_BOT - Y_VU_TOP + 1
  if vuH < 1 then return end

  for vy = Y_VU_TOP, Y_VU_BOT do
    if d.playing then
      -- Animation : chaque ligne = bande frequentielle differente
      -- Seed pseudo-aleatoire stable par ligne + beat
      local band = vy - Y_VU_TOP + 1
      local s1   = (band * 13 + beat * 7) % 29
      local s2   = (band * 7  + beat * 3) % 17
      -- Niveau 0..1 avec un peu de mouvement
      local lvl  = (s1 / 28) * 0.6 + (s2 / 16) * 0.4
      -- Applique l'attenuation du crossfader et du volume
      local gain = math.sqrt(dk == "A" and (1 - cf) or cf)
      lvl = lvl * d.vol * gain * masterVol

      local lit = math.floor(dw * math.min(1, lvl))

      for xi = 0, dw - 1 do
        local pct = dw > 1 and (xi / (dw - 1)) or 0
        local on  = xi < lit
        at(x1 + xi, vy)
        if on then
          -- Degrade de couleur en fonction du niveau (position dans la barre)
          local c
          if     pct > 0.88 then c = colors.red
          elseif pct > 0.72 then c = colors.orange
          elseif pct > 0.50 then c = colors.yellow
          else                    c = colors.lime
          end
          bg(c); term.write(" ")
        else
          bg(colors.black); fg(colors.gray)
          term.write(".")
        end
      end
    else
      -- Arrete : ligne grise de points
      fill(x1, x2, vy, ".", colors.gray, colors.black)
    end
  end

  bg(colors.black)
end

-- ============================================================
--  DESSIN DU CROSSFADER
-- ============================================================
local function drawCrossfader()
  -- Gains equal-power
  local angle = cf * math.pi / 2
  local pctA  = math.floor(math.cos(angle) * 100 + 0.5)
  local pctB  = math.floor(math.sin(angle) * 100 + 0.5)

  -- ---- Barre crossfader (ligne Y_CF_BAR) -------------------
  -- Structure: "A 100% [<<<<<<<O--------->] 0% B"
  -- On utilise des espaces avec bg couleur pour les zones colorees

  -- Partie gauche label: " A xxx% ["
  fg(colors.cyan);  bg(colors.black)
  at(1, Y_CF_BAR)
  term.write(string.format("A%3d%% [", pctA))

  -- Barre interieure
  local knob = CF_X1 + math.floor(cf * (CF_LEN - 1))

  for x = CF_X1, CF_X2 do
    at(x, Y_CF_BAR)
    if x == knob then
      -- Curseur (knob)
      bg(colors.yellow); fg(colors.black)
      term.write("O")
    elseif x < knob then
      -- Zone A (gauche du knob) - fond cyan
      bg(colors.cyan); fg(colors.black)
      term.write(" ")
    else
      -- Zone B (droite du knob) - fond magenta
      bg(colors.magenta); fg(colors.black)
      term.write(" ")
    end
  end

  -- Partie droite label: "] xxx% B"
  bg(colors.black); fg(colors.magenta)
  at(CF_X2 + 1, Y_CF_BAR)
  term.write(string.format("]%3d%%B", pctB))

  -- ---- Label crossfader (ligne Y_CF_LBL) -------------------
  fill(1, W, Y_CF_LBL, " ", colors.white, colors.black)
  fg(colors.gray);   at(1, Y_CF_LBL); term.write(" CROSSFADER")
  fg(colors.white);  at(MID - 4, Y_CF_LBL); term.write("-[  MIX  ]-")
  -- Indicateur textuel de position
  local pos
  if cf < 0.1 then      pos = "  << FULL A"
  elseif cf < 0.4 then  pos = "  << GAUCHE"
  elseif cf < 0.6 then  pos = "   CENTRE  "
  elseif cf < 0.9 then  pos = "  DROITE >>"
  else                   pos = "  FULL B >>"
  end
  fg(colors.yellow); at(W - 11, Y_CF_LBL); term.write(pos)

  -- ---- Aide clavier (ligne Y_HELP) -------------------------
  fill(1, W, Y_HELP, " ", colors.gray, colors.black)
  fg(colors.gray); at(1, Y_HELP)
  term.write(" Q/P:play  L/O:load  </> ou <-/->:crossfade  W/S I/K:vol  UP/DOWN:master")
end

-- ============================================================
--  UI COMPLETE
-- ============================================================
local function drawUI()
  cls()

  -- ---- Header (ligne Y_TOP) --------------------------------
  fill(1, W, Y_TOP, " ", colors.black, colors.gray)
  bg(colors.gray); fg(colors.yellow)
  at(1, Y_TOP); term.write(" === DJ MIXER PRO v7 === ")
  fg(colors.white)
  term.write("VOL:" .. math.floor(masterVol * 100) .. "%  ")
  fg(STEREO and colors.lime or colors.orange)
  term.write(STEREO and "STEREO " or "MONO ")
  fg(colors.lightGray); term.write("| Q/P play  L/O load  arrows CF")

  -- ---- Ligne de boite haute --------------------------------
  hline(1, W, Y_BOX1, "+", "+", "+")

  -- ---- Separateur vertical (toutes les lignes milieu) ------
  for y = Y_BOX1, Y_BOX4 do
    bg(colors.black); fg(colors.gray)
    at(MID, y)
    if y == Y_BOX1 or y == Y_BOX2 or y == Y_BOX3 or y == Y_BOX4 then
      term.write("+")
    else
      term.write("|")
    end
  end

  -- ---- Decks -----------------------------------------------
  drawDeck("A", DA_X1, DA_X2)
  drawDeck("B", DB_X1, DB_X2)

  -- ---- Lignes de separation internes de la boite -----------
  hline(1, W, Y_BOX2, "+", "+", "+")
  hline(1, W, Y_BOX3, "+", "+", "+")
  hline(1, W, Y_BOX4, "+", "+", "+")

  -- ---- Crossfader ------------------------------------------
  drawCrossfader()

  -- ---- Status bas (ligne Y_STATUS) -------------------------
  fill(1, W, Y_STATUS, " ", colors.gray, colors.black)

  bg(colors.black); fg(colors.white)
end

-- ============================================================
--  BOUCLE AUDIO STEREO
-- ============================================================
local function speakerLoop(spk, spkName, deckKey)
  while true do
    local d = decks[deckKey]

    if not d.playing then
      sleep(0.05)
    else
      local rawBuf = nil

      if d.handle then
        local chunk = d.handle.read(16 * 1024)
        if chunk then
          rawBuf    = d.dec(chunk)
          d.lastBuf = rawBuf
        else
          d.playing = false
          d.status  = "FIN"
        end
      end

      if rawBuf then
        beat = beat + 1

        -- Volume avec crossfader equal-power
        local angle  = cf * math.pi / 2
        local cfGain = deckKey == "A" and math.cos(angle) or math.sin(angle)
        local vol    = cfGain * d.vol * masterVol

        -- Pan stereo : deck A -> speaker gauche, deck B -> speaker droit
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
--  BOUCLE AUDIO MONO  (mix des deux decks)
-- ============================================================
local function monoLoop()
  while true do
    local dA = decks.A
    local dB = decks.B

    if not dA.playing and not dB.playing then
      sleep(0.05)
    else
      local angle = cf * math.pi / 2
      local gA    = math.cos(angle) * dA.vol * masterVol
      local gB    = math.sin(angle) * dB.vol * masterVol

      -- Lire chunk A
      local bufA = nil
      if dA.playing and dA.handle then
        local c = dA.handle.read(16 * 1024)
        if c then
          bufA = dA.dec(c); dA.lastBuf = bufA
        else
          dA.playing = false; dA.status = "FIN"
        end
      end

      -- Lire chunk B
      local bufB = nil
      if dB.playing and dB.handle then
        local c = dB.handle.read(16 * 1024)
        if c then
          bufB = dB.dec(c); dB.lastBuf = bufB
        else
          dB.playing = false; dB.status = "FIN"
        end
      end

      -- Mix
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
        mix = bufA
        for i = 1, #mix do mix[i] = mix[i] * gA end
        beat = beat + 1
      elseif bufB then
        mix = bufB
        for i = 1, #mix do mix[i] = mix[i] * gB end
        beat = beat + 1
      end

      if mix then
        local ok = spkL.playAudio(mix, 3.0)
        if not ok then
          repeat
            local _, n2 = os.pullEvent("speaker_audio_empty")
          until n2 == nameL
          spkL.playAudio(mix, 3.0)
        end
      else
        sleep(0.05)
      end
    end
  end
end

-- ============================================================
--  CHARGEMENT CHANSON
-- ============================================================
local function loadSong(dk)
  local d = decks[dk]

  -- Prompt en bas
  fill(1, W, Y_STATUS, " ", colors.white, colors.black)
  bg(colors.blue); fg(colors.white)
  at(1, Y_STATUS)
  term.write(" Recherche [" .. dk .. "]: ")
  bg(colors.black); fg(colors.white)
  local q = read()
  if not q or q == "" then
    d.status = "PRET"
    return
  end

  d.load   = true
  d.status = "Chargement..."
  drawUI()

  local ok, err = pcall(function()
    local h = http.get(API .. "?v=" .. VER .. "&search=" .. textutils.urlEncode(q))
    if not h then error("Connexion impossible") end
    local data = textutils.unserialiseJSON(h.readAll())
    h.close()
    if not (data and data[1]) then error("Aucun resultat") end
    local s     = data[1]
    d.title     = s.name   or "Inconnu"
    d.artist    = s.artist or ""
    if d.handle then pcall(function() d.handle.close() end) end
    d.handle    = http.get({ url = API .. "?v=" .. VER .. "&id=" .. s.id, binary = true })
    if not d.handle then error("Impossible de charger le stream") end
    d.dec       = dfpwm.make_decoder()
    d.lastBuf   = nil
    d.status    = "PRET"
  end)

  if not ok then
    d.title  = "[ ERREUR ]"
    d.status = "ERREUR: " .. tostring(err):sub(1, 20)
  end
  d.load = false
end

-- ============================================================
--  INPUT LOOP
-- ============================================================
local function setCF(x)
  cf = math.max(0, math.min(1, (x - CF_X1) / math.max(1, CF_LEN - 1)))
end

local function inputLoop()
  while true do
    drawUI()
    local ev, p1, p2, p3 = os.pullEvent()

    -- ---- Clavier -------------------------------------------
    if ev == "key" then
      local k = p1

      -- Play / Stop
      if     k == keys.q     then decks.A.playing = not decks.A.playing
      elseif k == keys.p     then decks.B.playing = not decks.B.playing

      -- Load
      elseif k == keys.l     then loadSong("A")
      elseif k == keys.o     then loadSong("B")

      -- Crossfader (fleches + lettres alternatives)
      elseif k == keys.left  or k == keys.comma  then cf = math.max(0, cf - 0.05)
      elseif k == keys.right or k == keys.period then cf = math.min(1, cf + 0.05)
      elseif k == keys.c     then cf = 0.5   -- centre
      elseif k == keys.z     then cf = 0.0   -- full A
      elseif k == keys.x     then cf = 1.0   -- full B

      -- Volume master
      elseif k == keys.up    then masterVol = math.min(2.0, masterVol + 0.1)
      elseif k == keys.down  then masterVol = math.max(0.0, masterVol - 0.1)

      -- Volume deck A
      elseif k == keys.w     then decks.A.vol = math.min(1.5, decks.A.vol + 0.1)
      elseif k == keys.s     then decks.A.vol = math.max(0.0, decks.A.vol - 0.1)

      -- Volume deck B
      elseif k == keys.i     then decks.B.vol = math.min(1.5, decks.B.vol + 0.1)
      elseif k == keys.k     then decks.B.vol = math.max(0.0, decks.B.vol - 0.1)
      end

    -- ---- Souris : clic --------------------------------------
    elseif ev == "mouse_click" then
      local mx, my = p2, p3

      -- Crossfader barre
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)

      -- Deck A
      elseif mx >= DA_X1 and mx < MID then
        local d  = decks.A
        local dw = DA_X2 - DA_X1 + 1

        if my == Y_DNAME then
          -- Clic sur le header du deck = play/stop
          d.playing = not d.playing
        elseif my == Y_BUTTONS then
          if mx <= DA_X1 + 5 then
            d.playing = not d.playing
          elseif mx <= DA_X1 + 12 then
            loadSong("A")
          end
        elseif my == Y_VOL then
          -- Clic sur la barre de volume
          local barX1 = DA_X1 + 6
          local barW  = dw - 11
          if mx >= barX1 and mx < barX1 + barW and barW > 0 then
            d.vol = math.min(1.5, ((mx - barX1) / barW) * 1.5)
          end
        end

      -- Deck B
      elseif mx > MID and mx <= DB_X2 then
        local d  = decks.B
        local dw = DB_X2 - DB_X1 + 1

        if my == Y_DNAME then
          d.playing = not d.playing
        elseif my == Y_BUTTONS then
          if mx <= DB_X1 + 5 then
            d.playing = not d.playing
          elseif mx <= DB_X1 + 12 then
            loadSong("B")
          end
        elseif my == Y_VOL then
          local barX1 = DB_X1 + 6
          local barW  = dw - 11
          if mx >= barX1 and mx < barX1 + barW and barW > 0 then
            d.vol = math.min(1.5, ((mx - barX1) / barW) * 1.5)
          end
        end
      end

    -- ---- Souris : glisser le crossfader ---------------------
    elseif ev == "mouse_drag" then
      local mx, my = p2, p3
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)
      end
    end
  end
end

-- ============================================================
--  SPLASH
-- ============================================================
cls()
local sy = math.max(1, math.floor(H / 2) - 3)
local function sp(y, s, c)
  fg(c); at(math.max(1, math.floor((W - #s) / 2) + 1), y)
  term.write(s)
end
sp(sy,     "+============================+", colors.yellow)
sp(sy + 1, "|   DJ  MIXER  PRO   v7      |", colors.yellow)
sp(sy + 2, "+============================+", colors.yellow)
sp(sy + 3, "", colors.white)
sp(sy + 4, STEREO and "STEREO  -  " .. #foundSpk .. " speakers"
                   or  "MONO  -  1 speaker",
   STEREO and colors.lime or colors.orange)
for i, s in ipairs(foundSpk) do
  local role = i == 1 and "[L] " or i == 2 and "[R] " or "    "
  local ln   = role .. s.name
  sp(sy + 5 + i, ln, i == 1 and colors.cyan or colors.magenta)
end
sp(sy + 8, "Demarrage...", colors.gray)
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

cls()
at(1, 1); fg(colors.white)
term.write("DJ Mixer Pro v7 ferme. A bientot !")
