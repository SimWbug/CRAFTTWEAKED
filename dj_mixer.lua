-- ╔══════════════════════════════════════════════════════════════════╗
--  DJ MIXER PRO  v6  |  CC:Tweaked
--  - Interface visuelle redessinée (dégradés, VU LED, waveform)
--  - Crossfader amélioré avec courbe equal-power et mix en temps réel
--  - FX audio débogués et fonctionnels
--  - Panneau de contrôle compact et lisible
-- ╚══════════════════════════════════════════════════════════════════╝
local dfpwm = require "cc.audio.dfpwm"
local API   = "https://ipod-2to6magyna-uc.a.run.app/"
local VER   = "2.1"
local W, H  = term.getSize()

-- ══════════════════════════════════════════════════════════════════
--  DÉTECTION SPEAKERS
-- ══════════════════════════════════════════════════════════════════
local foundSpk = {}
term.setBackgroundColor(colors.black); term.clear()
term.setCursorPos(1,1); term.setTextColor(colors.yellow)
term.write("Recherche speakers...\n")
term.setTextColor(colors.gray)

for _, name in ipairs(peripheral.getNames()) do
  local types = { peripheral.getType(name) }
  for _, t in ipairs(types) do
    if t == "speaker" then
      local obj = peripheral.wrap(name)
      if obj and obj.playAudio then
        foundSpk[#foundSpk+1] = { obj=obj, name=name }
        term.write("  OK: " .. name .. "\n")
      end
      break
    end
  end
end

if #foundSpk == 0 then
  term.setTextColor(colors.red)
  term.write("\nAucun speaker !\nPeriph detectes:\n")
  for _, name in ipairs(peripheral.getNames()) do
    local t = { peripheral.getType(name) }
    term.write("  "..name.." ["..table.concat(t,",").."]\n")
  end
  term.write("Touche pour quitter..."); os.pullEvent("key")
  error("Pas de speaker.")
end

local spkL   = foundSpk[1].obj
local nameL  = foundSpk[1].name
local spkR   = foundSpk[2] and foundSpk[2].obj  or spkL
local nameR  = foundSpk[2] and foundSpk[2].name or nameL
local STEREO = #foundSpk >= 2
sleep(0.5)

-- ══════════════════════════════════════════════════════════════════
--  LAYOUT
-- ══════════════════════════════════════════════════════════════════
local MID    = math.floor(W / 2)
local DA_X1  = 1
local DA_X2  = MID - 1
local DB_X1  = MID + 1
local DB_X2  = W

-- Zones verticales
local Y_HEADER   = 1
local Y_DECK_TOP = 2    -- début zone deck (titre/artiste/état)
local Y_STATUS   = 4
local Y_SEP1     = 5
local Y_FX_TOP   = 6    -- boutons FX (lignes 6-8, 3 lignes, 2 col)
local Y_SEP2     = 9
local Y_CTRL     = 10   -- play/stop/load + vol
local Y_VU_TOP   = 11
local Y_VU_BOT   = H - 5
local Y_SEP3     = H - 4
local Y_CF_LABEL = H - 3
local Y_CF_BAR   = H - 2
local Y_HELP     = H - 1
local Y_STATUS2  = H

-- Crossfader bar
local CF_X1  = 6
local CF_X2  = W - 5
local CF_LEN = CF_X2 - CF_X1 + 1

-- ══════════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════════
local cf        = 0.5
local masterVol = 1.0
local bpm       = 128
local beat      = 0

-- Table des FX avec leur état on/off
local function newDeck(col)
  return {
    title   = "[ VIDE ]",
    artist  = "",
    playing = false,
    handle  = nil,
    dec     = dfpwm.make_decoder(),
    vol     = 1.0,
    -- FX actifs
    fx = {
      gate    = false,
      crush   = false,
      stutter = false,
      reverb  = false,
      echo    = false,
      flanger = false,
    },
    -- Buffers FX
    lastBuf   = nil,   -- stutter + reverb (chunk précédent)
    echoBuf   = nil,   -- buffer de délai echo
    flangePos = 0,     -- phase flanger (0.0 .. 1.0)
    -- VU peak
    vuPeak    = 0,
    -- UI
    status    = "PRÊT",
    col       = col,
    load      = false,
    -- Gate : compteur tick interne
    gateTick  = 0,
    gateOpen  = true,
  }
end

local decks = {
  A = newDeck(colors.cyan),
  B = newDeck(colors.magenta),
}

-- ══════════════════════════════════════════════════════════════════
--  HELPERS DESSIN
-- ══════════════════════════════════════════════════════════════════
local function at(x,y)  term.setCursorPos(x,y) end
local function fg(c)    term.setTextColor(c) end
local function bg(c)    term.setBackgroundColor(c) end
local function cls()    bg(colors.black); term.clear() end

local function fill(x1,x2,y,ch,f,b)
  if x2 < x1 then return end
  bg(b or colors.black); fg(f or colors.white)
  at(x1,y); term.write(string.rep(ch, x2-x1+1))
  bg(colors.black)
end

local function txt(x,y,s,f,b)
  if b then bg(b) else bg(colors.black) end
  fg(f or colors.white); at(x,y); term.write(s)
  bg(colors.black)
end

-- Centrer une chaîne dans une zone x1..x2 à la ligne y
local function center(x1,x2,y,s,f,b)
  local dw  = x2-x1+1
  local off = math.max(0, math.floor((dw - #s)/2))
  if b then fill(x1,x2,y," ",f,b) end
  fg(f or colors.white); at(x1+off,y); term.write(s:sub(1,dw))
  bg(colors.black)
end

-- Barre horizontale avec dégradé couleur
local function hbar(x,y,len,val,maxv,col_on,col_off)
  local n = math.min(len, math.floor(val/maxv*len+0.5))
  bg(col_on);  fg(col_on);  at(x,y); term.write(string.rep("█",n))
  bg(col_off); fg(col_off); term.write(string.rep("▒",len-n))
  bg(colors.black)
end

-- Bouton FX avec styling amélioré
local function fxBtn(x,y,key,lbl,on,dk_col)
  local bw = 9
  if on then
    bg(dk_col); fg(colors.black)
    at(x,y); term.write(string.format("%-"..bw.."s","[" .. key .. "]" .. lbl))
  else
    bg(colors.gray); fg(colors.lightGray)
    at(x,y); term.write(string.format("%-"..bw.."s","[" .. key .. "]" .. lbl))
  end
  bg(colors.black)
end

-- ══════════════════════════════════════════════════════════════════
--  DESSIN D'UN DECK  (redessiné)
-- ══════════════════════════════════════════════════════════════════
local FX_DEF = {
  { id="gate",    lbl="GATE"  },
  { id="crush",   lbl="CRUSH" },
  { id="stutter", lbl="STUT"  },
  { id="reverb",  lbl="REVB"  },
  { id="echo",    lbl="ECHO"  },
  { id="flanger", lbl="FLNG"  },
}
local FX_KEYS_A = {"1","2","3","4","5","6"}
local FX_KEYS_B = {"7","8","9","0","-","="}

local function drawDeck(dk, x1, x2)
  local d   = decks[dk]
  local dw  = x2 - x1 + 1
  local fxk = dk=="A" and FX_KEYS_A or FX_KEYS_B

  -- ── Ligne 2 : bande de titre deck ──────────────────────────
  fill(x1,x2, Y_DECK_TOP, " ", colors.black, d.col)
  bg(d.col); fg(colors.black)
  at(x1, Y_DECK_TOP)
  local hdr = " DECK "..dk
  if STEREO then hdr = hdr..(dk=="A" and " ◄L" or " R►") end
  term.write(hdr)
  -- Indicateur play/stop à droite
  local stlbl = d.playing and "▶ LIVE" or "■ STOP"
  local stcol = d.playing and colors.lime or colors.red
  bg(stcol); fg(colors.black)
  at(x2-6, Y_DECK_TOP); term.write(" "..stlbl.." ")

  -- ── Ligne 3 : titre chanson ────────────────────────────────
  fill(x1,x2, Y_DECK_TOP+1, " ", colors.white, colors.black)
  fg(d.playing and colors.white or colors.gray)
  at(x1, Y_DECK_TOP+1)
  local titlbl = " ♪ " .. d.title
  term.write(titlbl:sub(1,dw))

  -- ── Ligne 4 : artiste + status ─────────────────────────────
  fill(x1,x2, Y_STATUS, " ", colors.gray, colors.black)
  fg(colors.gray); at(x1, Y_STATUS)
  local art = "   " .. (d.artist ~= "" and d.artist or d.status)
  term.write(art:sub(1,dw))

  -- ── Ligne 5 : séparateur section FX ───────────────────────
  fill(x1,x2, Y_SEP1, "─", colors.gray, colors.black)
  bg(colors.black); fg(d.col)
  local flbl = "[ FX ]"
  at(x1 + math.floor((dw-#flbl)/2), Y_SEP1)
  term.write(flbl)

  -- ── Lignes 6-8 : boutons FX (2 colonnes) ──────────────────
  local col2 = x1 + math.floor(dw/2)
  for i, fx in ipairs(FX_DEF) do
    local bx = (i%2==1) and x1 or col2
    local by = Y_FX_TOP + math.floor((i-1)/2)
    fxBtn(bx, by, fxk[i], fx.lbl, d.fx[fx.id], d.col)
    -- remplir le reste de la cellule
    local ex = (i%2==1) and (col2-1) or x2
    local bw2 = ex - (bx+9) + 1
    if bw2 > 0 then
      bg(d.fx[fx.id] and d.col or colors.gray)
      at(bx+9, by); term.write(string.rep(" ", bw2))
      bg(colors.black)
    end
  end

  -- ── Ligne 9 : séparateur contrôles ───────────────────────
  fill(x1,x2, Y_SEP2, "─", colors.gray, colors.black)

  -- ── Ligne 10 : Play/Stop + Load + Volume deck ─────────────
  fill(x1,x2, Y_CTRL, " ", colors.white, colors.black)
  -- Bouton PLAY/STOP
  if d.playing then bg(colors.red) else bg(colors.green) end
  fg(colors.black); at(x1, Y_CTRL)
  term.write(d.playing and " ■STOP " or " ▶PLAY ")
  -- Bouton LOAD
  bg(colors.blue); fg(colors.white)
  at(x1+7, Y_CTRL); term.write(" ⊕LOAD ")
  -- Barre volume compacte
  fg(colors.lightGray); at(x1+15, Y_CTRL); term.write("V")
  bg(colors.black)
  local vbarW = dw - 20
  if vbarW > 2 then
    hbar(x1+16, Y_CTRL, vbarW, d.vol, 1.5, colors.lime, colors.gray)
  end
  bg(colors.black); fg(colors.white)
  at(x2-3, Y_CTRL); term.write(string.format("%3d%%", math.floor(d.vol*100)))

  -- ── VU-mètre LED amélioré (Y_VU_TOP .. Y_VU_BOT) ─────────
  -- Affiche des colonnes LED verticales façon hardware
  local vuH = Y_VU_BOT - Y_VU_TOP + 1
  -- On calcule un "niveau" animé basé sur le beat et un seed
  for vy = Y_VU_TOP, Y_VU_BOT do
    fill(x1, x2, vy, " ", colors.black, colors.black)
    if d.playing then
      -- Chaque ligne du VU représente une bande fréquentielle simulée
      local band = vy - Y_VU_TOP + 1
      local seed = (beat * 3 + band * 7) % 31
      -- Hauteur de la barre (0..1) avec un peu de mouvement
      local lvl  = 0.2 + 0.8 * (seed / 30)
      -- Applique le volume du deck pour que ça soit cohérent
      lvl = lvl * d.vol * math.sqrt(dk=="A" and (1-cf) or cf)
      -- Calcule la largeur allumée
      local lit = math.floor(dw * math.min(1, lvl))
      for xi = 0, dw-1 do
        local pct = xi / (dw-1)
        local on  = xi < lit
        local c
        if on then
          -- dégradé vert → jaune → orange → rouge
          if     pct > 0.88 then c = colors.red
          elseif pct > 0.72 then c = colors.orange
          elseif pct > 0.55 then c = colors.yellow
          else                    c = colors.lime
          end
        else
          c = colors.gray
        end
        fg(c); bg(colors.black)
        at(x1+xi, vy)
        if on then
          -- Segments LED : █ sur le premier tiers de la rangée, ▌ sinon
          term.write(band % 2 == 0 and "█" or "▐")
        else
          term.write("·")
        end
      end
      -- Peak indicator (au niveau du max actuel)
      if d.vuPeak > 0 then
        local pk = math.floor(dw * math.min(1, d.vuPeak))
        if pk > 0 and pk <= dw then
          fg(colors.white); bg(colors.black)
          at(x1 + pk - 1, vy); term.write("▐")
        end
      end
    else
      -- Deck arrêté : afficher une ligne statique basse
      fg(colors.gray)
      for xi = 0, dw-1 do
        at(x1+xi, vy)
        term.write("·")
      end
    end
  end

  -- ── Séparateur bas ────────────────────────────────────────
  fill(x1, x2, Y_SEP3, "─", colors.gray, colors.black)

  bg(colors.black)
end

-- ══════════════════════════════════════════════════════════════════
--  CROSSFADER REDESSINÉ
--  Affichage visuel amélioré : courbe de mix visible, zones colorées
-- ══════════════════════════════════════════════════════════════════
local function drawCrossfader()
  -- Ligne label CF
  fill(1, W, Y_CF_LABEL, " ", colors.white, colors.black)
  -- Gains actuels (equal-power)
  local gainA = math.sqrt(1 - cf)
  local gainB = math.sqrt(cf)
  local pctA  = math.floor(gainA * 100 + 0.5)
  local pctB  = math.floor(gainB * 100 + 0.5)

  -- Label gauche deck A
  fg(colors.cyan); at(1, Y_CF_LABEL)
  term.write(string.format("A%-3d%%", pctA))
  -- Label "CROSSFADER" centré
  fg(colors.white); at(MID-5, Y_CF_LABEL); term.write("CROSSFADER")
  -- Label droite deck B
  fg(colors.magenta); at(W-4, Y_CF_LABEL)
  term.write(string.format("%3d%%B", pctB))

  -- Barre interactive pleine largeur
  fill(1, W, Y_CF_BAR, " ", colors.black, colors.black)
  fg(colors.cyan);    at(1, Y_CF_BAR);  term.write("◄A")
  fg(colors.magenta); at(W-1, Y_CF_BAR); term.write("B►")

  local knob = CF_X1 + math.floor(cf * (CF_LEN - 1))

  for x = CF_X1, CF_X2 do
    local pct = (x - CF_X1) / (CF_LEN - 1)
    if x == knob then
      -- Curseur
      bg(colors.yellow); fg(colors.black)
      term.write("◆")
    elseif x < knob then
      -- Zone A (gauche) : dégradé cyan selon distance au centre
      local t = pct * 2  -- 0..1 vers le centre
      local c = t < 0.5 and colors.cyan
             or t < 0.8 and colors.lightBlue
             or              colors.blue
      bg(c); fg(colors.black); term.write("━")
    else
      -- Zone B (droite) : dégradé magenta
      local t = (1 - pct) * 2
      local c = t < 0.5 and colors.magenta
             or t < 0.8 and colors.purple
             or              colors.blue
      bg(c); fg(colors.black); term.write("━")
    end
    bg(colors.black)
  end

  -- Aide clavier
  fill(1, W, Y_HELP, " ", colors.gray, colors.black)
  fg(colors.gray); at(1, Y_HELP)
  term.write(" ←→/Souris:CF  Q/P:play  L/O:load  W/S:volA  I/K:volB  ↑↓:master  [1-6]FX-A  [7=]FX-B  C:reset CF")
end

-- ══════════════════════════════════════════════════════════════════
--  UI PRINCIPALE
-- ══════════════════════════════════════════════════════════════════
local function drawUI()
  cls()

  -- ── Header ────────────────────────────────────────────────
  fill(1, W, Y_HEADER, " ", colors.black, colors.gray)
  bg(colors.gray)
  fg(colors.yellow); at(1,1); term.write(" ♫ DJ MIXER PRO v6 ")
  fg(colors.white); term.write("│ ")
  -- Master vol
  fg(d_playing and colors.lime or colors.white)
  term.write("VOL:"..math.floor(masterVol*100).."% │ BPM:"..bpm.." │ ")
  -- Stereo
  fg(STEREO and colors.lime or colors.lightGray)
  term.write(STEREO and "◈STEREO " or "◎MONO ")
  -- Mini crossfader dans le header
  fg(colors.cyan); term.write("A[")
  local mpos = math.floor(cf * 8)
  for i = 0, 8 do
    if i == mpos then
      fg(colors.yellow); term.write("◆")
    elseif i < mpos then
      fg(colors.magenta); term.write("─")
    else
      fg(colors.cyan); term.write("─")
    end
  end
  fg(colors.magenta); term.write("]B")

  -- ── Séparateur vertical central ───────────────────────────
  for y = 2, Y_SEP3 do
    bg(colors.black); fg(colors.gray); at(MID, y); term.write("│")
  end

  -- ── Decks ─────────────────────────────────────────────────
  drawDeck("A", DA_X1, DA_X2)
  drawDeck("B", DB_X1, DB_X2)

  -- ── Crossfader ────────────────────────────────────────────
  drawCrossfader()

  bg(colors.black); fg(colors.white)
end

-- ══════════════════════════════════════════════════════════════════
--  EFFETS AUDIO  (DEBUGGÉS)
--
--  Conventions :
--    - buf  : table Lua de floats [-1,1] (modifiée sur place)
--    - vol  : float retourné (peut être modifié par GATE)
--    - Les FX qui nécessitent de la mémoire utilisent d.xxxBuf
-- ══════════════════════════════════════════════════════════════════
local function applyFX(d, buf)
  local n = #buf

  -- ── GATE ──────────────────────────────────────────────────
  -- Coupe/ouvre le signal en sync avec le BPM.
  -- On compte les ticks audio (chunks de 16K samples @ 48kHz)
  -- Un tick = 16384/48000 ≈ 0.341 s. On alterne en quarts de temps.
  if d.fx.gate then
    -- Durée d'un quart de temps en ticks
    local ticksPerQuarter = math.max(1, math.floor((60 / bpm) / (16384/48000) / 4))
    d.gateTick = (d.gateTick or 0) + 1
    local phase = math.floor(d.gateTick / ticksPerQuarter) % 2
    if phase == 1 then
      -- Porte fermée : mettre le buffer à zéro
      for i = 1, n do buf[i] = 0 end
    end
    -- (si phase==0 : porte ouverte, on ne touche pas buf)
  else
    d.gateTick = 0
  end

  -- ── BITCRUSHER ────────────────────────────────────────────
  -- Réduit la résolution du signal (effet lo-fi/8bit).
  -- levels=16 donne un effet audible sans être destructif.
  if d.fx.crush then
    local levels = 16
    local inv = 1 / levels
    for i = 1, n do
      buf[i] = math.floor(buf[i] * levels + 0.5) * inv
    end
  end

  -- ── FLANGER ───────────────────────────────────────────────
  -- Mélange le signal avec une copie délayée d'un nombre de
  -- samples qui varie sinusoïdalement (LFO).
  -- Délai max = 96 samples (2 ms @ 48kHz), clairement audible.
  if d.fx.flanger then
    d.flangePos = (d.flangePos or 0) + 0.008
    if d.flangePos > 1 then d.flangePos = d.flangePos - 1 end
    local maxDelay = 96
    local delay = math.floor((math.sin(d.flangePos * 2 * math.pi) + 1) * 0.5 * maxDelay) + 1
    local tmp = {}
    for i = 1, n do tmp[i] = buf[i] end
    for i = 1, n do
      local j = i - delay
      if j >= 1 then
        buf[i] = (tmp[i] + tmp[j] * 0.7) * 0.6
      end
    end
  end

  -- ── ECHO (délai avec feedback) ────────────────────────────
  -- echoBuf contient les samples du chunk précédent avec decay.
  -- Chaque sample "entend" son écho un chunk plus tard.
  if d.fx.echo then
    local DECAY = 0.50  -- feedback 50%
    if not d.echoBuf or #d.echoBuf ~= n then
      d.echoBuf = {}
      for i = 1, n do d.echoBuf[i] = 0 end
    end
    for i = 1, n do
      local echo = d.echoBuf[i]
      local out  = buf[i] + echo
      -- Clamp
      if out >  1 then out =  1 end
      if out < -1 then out = -1 end
      -- Mettre le mix dans l'écho pour le prochain chunk
      d.echoBuf[i] = out * DECAY
      buf[i]       = out
    end
  else
    d.echoBuf = nil
  end

  -- ── REVERB ────────────────────────────────────────────────
  -- Mix le chunk courant avec le dernier chunk atténué.
  -- lastBuf est mis à jour APRÈS le stutter, donc pas de conflit.
  if d.fx.reverb then
    if d.lastBuf and #d.lastBuf == n then
      for i = 1, n do
        buf[i] = buf[i] + d.lastBuf[i] * 0.35
        if buf[i] >  1 then buf[i] =  1 end
        if buf[i] < -1 then buf[i] = -1 end
      end
    end
  end

  -- ── STUTTER ───────────────────────────────────────────────
  -- Renvoie le buffer précédent au lieu du courant.
  -- Note : on retourne un booléen pour indiquer au speakerLoop
  --        d'utiliser d.lastBuf à la place du nouveau chunk.
  -- (Géré directement dans speakerLoop pour éviter la copie ici)

  return buf
end

-- ══════════════════════════════════════════════════════════════════
--  CALCUL DU VOLUME AVEC CROSSFADER EQUAL-POWER
--  gainA² + gainB² ≈ 1 à toutes les positions
-- ══════════════════════════════════════════════════════════════════
local function cfGain(dk)
  -- Courbe equal-power (cosinus/sinus)
  -- cf=0 → A full, B silent ; cf=1 → A silent, B full
  local angle = cf * math.pi / 2  -- 0 .. π/2
  if dk == "A" then
    return math.cos(angle)  -- 1→0
  else
    return math.sin(angle)  -- 0→1
  end
end

-- ══════════════════════════════════════════════════════════════════
--  BOUCLE AUDIO STÉRÉO (un speakerLoop par speaker/deck)
-- ══════════════════════════════════════════════════════════════════
local function speakerLoop(spk, spkName, deckKey)
  while true do
    local d = decks[deckKey]

    if not d.playing then
      sleep(0.05)
    else
      -- Lecture chunk
      local rawBuf

      if d.fx.stutter and d.lastBuf then
        -- STUTTER : rejouer exactement le dernier chunk
        rawBuf = d.lastBuf
      elseif d.handle then
        local chunk = d.handle.read(16 * 1024)
        if chunk then
          rawBuf = d.dec(chunk)
        else
          d.playing = false
          d.status  = "FIN"
          rawBuf    = nil
        end
      end

      if rawBuf then
        beat = beat + 1

        -- Sauver le buffer AVANT les FX pour reverb/stutter
        -- (copie légère : table Lua)
        local prevBuf = d.lastBuf
        if not d.fx.stutter then
          -- On ne met à jour lastBuf que si on lit réellement
          d.lastBuf = rawBuf
        end

        -- Appliquer les FX (modifie rawBuf sur place)
        local buf = applyFX(d, rawBuf)

        -- Volume final
        local gain = cfGain(deckKey) * d.vol * masterVol

        -- Peak pour le VU
        local peak = 0
        for i = 1, #buf do
          local v = math.abs(buf[i])
          if v > peak then peak = v end
        end
        d.vuPeak = peak * gain

        -- Pan : deck A fort à gauche, faible à droite (et vice-versa)
        local panVol
        if deckKey == "A" then
          panVol = (spk == spkL) and gain or gain * 0.08
        else
          panVol = (spk == spkR) and gain or gain * 0.08
        end
        panVol = math.min(3.0, panVol * 3.0)

        -- Envoi au speaker
        local ok = spk.playAudio(buf, panVol)
        if not ok then
          repeat
            local _, evName = os.pullEvent("speaker_audio_empty")
          until evName == spkName
          spk.playAudio(buf, panVol)
        end
      else
        sleep(0.05)
      end
    end
  end
end

-- ══════════════════════════════════════════════════════════════════
--  BOUCLE AUDIO MONO (mix des deux decks sur un seul speaker)
-- ══════════════════════════════════════════════════════════════════
local function monoLoop()
  -- En mono, on interleave les chunks des deux decks.
  -- Quand les deux jouent, on mixe les buffers.
  while true do
    local dA = decks.A
    local dB = decks.B
    local playA = dA.playing
    local playB = dB.playing

    if not playA and not playB then
      sleep(0.05)
    else
      -- Lire depuis A
      local bufA = nil
      if playA then
        if dA.fx.stutter and dA.lastBuf then
          bufA = dA.lastBuf
        elseif dA.handle then
          local c = dA.handle.read(16*1024)
          if c then bufA = dA.dec(c); dA.lastBuf = bufA
          else dA.playing=false; dA.status="FIN" end
        end
      end

      -- Lire depuis B
      local bufB = nil
      if playB then
        if dB.fx.stutter and dB.lastBuf then
          bufB = dB.lastBuf
        elseif dB.handle then
          local c = dB.handle.read(16*1024)
          if c then bufB = dB.dec(c); dB.lastBuf = bufB
          else dB.playing=false; dB.status="FIN" end
        end
      end

      -- Appliquer FX
      if bufA then bufA = applyFX(dA, bufA) end
      if bufB then bufB = applyFX(dB, bufB) end

      -- Mix
      local mixBuf = nil
      if bufA and bufB then
        local gainA = cfGain("A") * dA.vol * masterVol
        local gainB = cfGain("B") * dB.vol * masterVol
        local n = math.min(#bufA, #bufB)
        mixBuf = {}
        for i = 1, n do
          local v = bufA[i]*gainA + bufB[i]*gainB
          if v >  1 then v =  1 end
          if v < -1 then v = -1 end
          mixBuf[i] = v
        end
        beat = beat + 1
      elseif bufA then
        local g = cfGain("A") * dA.vol * masterVol
        mixBuf = bufA
        beat = beat + 1
        for i=1,#mixBuf do mixBuf[i]=mixBuf[i]*g end
      elseif bufB then
        local g = cfGain("B") * dB.vol * masterVol
        mixBuf = bufB
        beat = beat + 1
        for i=1,#mixBuf do mixBuf[i]=mixBuf[i]*g end
      end

      if mixBuf then
        local ok = spkL.playAudio(mixBuf, 3.0)
        if not ok then
          repeat local _,n2=os.pullEvent("speaker_audio_empty") until n2==nameL
          spkL.playAudio(mixBuf, 3.0)
        end
      else
        sleep(0.05)
      end
    end
  end
end

-- ══════════════════════════════════════════════════════════════════
--  CHARGEMENT CHANSON
-- ══════════════════════════════════════════════════════════════════
local function loadSong(dk)
  local d = decks[dk]
  term.setCursorPos(1,H); term.clearLine()
  bg(colors.blue); fg(colors.white)
  at(1,H); term.write(" Recherche ["..dk.."]: ")
  bg(colors.black); fg(colors.white)
  local q = read()
  if not q or q=="" then return end

  d.load  = true
  d.status= "Chargement..."
  drawUI()

  local ok, err = pcall(function()
    local h = http.get(API.."?v="..VER.."&search="..textutils.urlEncode(q))
    if not h then error("HTTP fail") end
    local data = textutils.unserialiseJSON(h.readAll()); h.close()
    if not (data and data[1]) then error("Non trouvé") end
    local s = data[1]
    d.title  = s.name   or "?"
    d.artist = s.artist or ""
    if d.handle then pcall(function() d.handle.close() end) end
    d.handle    = http.get({ url=API.."?v="..VER.."&id="..s.id, binary=true })
    if not d.handle then error("Stream fail") end
    d.dec       = dfpwm.make_decoder()
    d.lastBuf   = nil
    d.echoBuf   = nil
    d.flangePos = 0
    d.gateTick  = 0
    d.gateOpen  = true
    d.vuPeak    = 0
    d.status    = "PRÊT"
  end)

  if not ok then
    d.status = "ERREUR"
    d.title  = "[ ERREUR ]"
  end
  d.load = false
end

-- ══════════════════════════════════════════════════════════════════
--  CROSSFADER : conversion X → valeur CF
-- ══════════════════════════════════════════════════════════════════
local function setCF(x)
  cf = math.max(0, math.min(1, (x - CF_X1) / (CF_LEN - 1)))
end

-- ══════════════════════════════════════════════════════════════════
--  INPUT LOOP (clavier + souris)
-- ══════════════════════════════════════════════════════════════════
local function inputLoop()
  while true do
    drawUI()
    local ev, p1, p2, p3 = os.pullEvent()

    -- ── CLAVIER ───────────────────────────────────────────────
    if ev == "key" then
      local k = p1
      -- FX deck A
      if     k == keys.one   then decks.A.fx.gate    = not decks.A.fx.gate
      elseif k == keys.two   then decks.A.fx.crush   = not decks.A.fx.crush
      elseif k == keys.three then decks.A.fx.stutter = not decks.A.fx.stutter
      elseif k == keys.four  then decks.A.fx.reverb  = not decks.A.fx.reverb
      elseif k == keys.five  then decks.A.fx.echo    = not decks.A.fx.echo
      elseif k == keys.six   then decks.A.fx.flanger = not decks.A.fx.flanger
      -- FX deck B
      elseif k == keys.seven  then decks.B.fx.gate    = not decks.B.fx.gate
      elseif k == keys.eight  then decks.B.fx.crush   = not decks.B.fx.crush
      elseif k == keys.nine   then decks.B.fx.stutter = not decks.B.fx.stutter
      elseif k == keys.zero   then decks.B.fx.reverb  = not decks.B.fx.reverb
      elseif k == keys.minus  then decks.B.fx.echo    = not decks.B.fx.echo
      elseif k == keys.equals then decks.B.fx.flanger = not decks.B.fx.flanger
      -- Play/stop
      elseif k == keys.q then decks.A.playing = not decks.A.playing
      elseif k == keys.p then decks.B.playing = not decks.B.playing
      -- Load
      elseif k == keys.l then loadSong("A")
      elseif k == keys.o then loadSong("B")
      -- Crossfader clavier (pas à pas de 5%)
      elseif k == keys.left  then cf = math.max(0, cf - 0.05)
      elseif k == keys.right then cf = math.min(1, cf + 0.05)
      -- Crossfader positions rapides
      elseif k == keys.c then cf = 0.5   -- centre
      elseif k == keys.z then cf = 0.0   -- full A
      elseif k == keys.x then cf = 1.0   -- full B
      -- Volume master
      elseif k == keys.up   then masterVol = math.min(2.0, masterVol + 0.1)
      elseif k == keys.down then masterVol = math.max(0.0, masterVol - 0.1)
      -- Volume decks
      elseif k == keys.w then decks.A.vol = math.min(1.5, decks.A.vol + 0.1)
      elseif k == keys.s then decks.A.vol = math.max(0.0, decks.A.vol - 0.1)
      elseif k == keys.i then decks.B.vol = math.min(1.5, decks.B.vol + 0.1)
      elseif k == keys.k then decks.B.vol = math.max(0.0, decks.B.vol - 0.1)
      -- BPM (pour le gate)
      elseif k == keys.pageUp   then bpm = math.min(200, bpm + 4)
      elseif k == keys.pageDown then bpm = math.max(60,  bpm - 4)
      end

    -- ── SOURIS (clic) ─────────────────────────────────────────
    elseif ev == "mouse_click" then
      local btn, mx, my = p1, p2, p3

      -- Crossfader barre
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)

      -- Deck A
      elseif mx >= DA_X1 and mx <= DA_X2 then
        local d  = decks.A
        local dw = DA_X2 - DA_X1 + 1
        local col2 = DA_X1 + math.floor(dw/2)

        if my == Y_DECK_TOP then
          d.playing = not d.playing
        elseif my == Y_CTRL then
          if mx <= DA_X1 + 6 then
            d.playing = not d.playing
          elseif mx <= DA_X1 + 13 then
            loadSong("A")
          elseif mx >= DA_X1 + 15 then
            -- Barre de volume
            local vbarW = dw - 20
            local relx  = mx - (DA_X1 + 16)
            if vbarW > 2 and relx >= 0 then
              d.vol = math.min(1.5, (relx / vbarW) * 1.5)
            end
          end
        elseif my >= Y_FX_TOP and my <= Y_FX_TOP+2 then
          local col  = mx < col2 and 1 or 2
          local row  = my - Y_FX_TOP + 1
          local idx  = (row-1)*2 + col
          local fmap = {"gate","crush","stutter","reverb","echo","flanger"}
          if fmap[idx] then d.fx[fmap[idx]] = not d.fx[fmap[idx]] end
        end

      -- Deck B
      elseif mx >= DB_X1 and mx <= DB_X2 then
        local d  = decks.B
        local dw = DB_X2 - DB_X1 + 1
        local col2 = DB_X1 + math.floor(dw/2)

        if my == Y_DECK_TOP then
          d.playing = not d.playing
        elseif my == Y_CTRL then
          if mx <= DB_X1 + 6 then
            d.playing = not d.playing
          elseif mx <= DB_X1 + 13 then
            loadSong("B")
          elseif mx >= DB_X1 + 15 then
            local vbarW = dw - 20
            local relx  = mx - (DB_X1 + 16)
            if vbarW > 2 and relx >= 0 then
              d.vol = math.min(1.5, (relx / vbarW) * 1.5)
            end
          end
        elseif my >= Y_FX_TOP and my <= Y_FX_TOP+2 then
          local col  = mx < col2 and 1 or 2
          local row  = my - Y_FX_TOP + 1
          local idx  = (row-1)*2 + col
          local fmap = {"gate","crush","stutter","reverb","echo","flanger"}
          if fmap[idx] then d.fx[fmap[idx]] = not d.fx[fmap[idx]] end
        end
      end

    -- ── SOURIS (glisser) ─────────────────────────────────────
    elseif ev == "mouse_drag" then
      local mx, my = p2, p3
      if my == Y_CF_BAR and mx >= CF_X1 and mx <= CF_X2 then
        setCF(mx)
      end
    end
  end
end

-- ══════════════════════════════════════════════════════════════════
--  SPLASH
-- ══════════════════════════════════════════════════════════════════
cls()
local sy = math.max(1, math.floor(H/2) - 3)
local function splash(y,s,c) fg(c); at(math.floor((W-#s)/2)+1,y); term.write(s) end
splash(sy,   "╔══════════════════════════╗", colors.yellow)
splash(sy+1, "║  ♫  DJ MIXER PRO  v6  ♫ ║", colors.yellow)
splash(sy+2, "╚══════════════════════════╝", colors.yellow)
splash(sy+4, STEREO and "◈ STÉRÉO — "..#foundSpk.." speakers détectés"
                     or  "◎ MONO — 1 speaker détecté",
       STEREO and colors.lime or colors.orange)
for i, s in ipairs(foundSpk) do
  local role = i==1 and "[L] " or i==2 and "[R] " or "    "
  local ln   = "  "..role..s.name
  fg(i==1 and colors.cyan or colors.magenta)
  at(math.floor((W-#ln)/2)+1, sy+5+i); term.write(ln)
end
splash(sy+8, "Chargement...", colors.gray)
sleep(1.5)

-- ══════════════════════════════════════════════════════════════════
--  LANCEMENT
-- ══════════════════════════════════════════════════════════════════
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
at(1,1); fg(colors.white)
term.write("DJ Mixer Pro v6 fermé. À bientôt !\n")
