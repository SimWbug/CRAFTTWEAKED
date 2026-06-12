-- ============================================================
--  CGCasino - Slot Machine v1.0  |  slots.lua
--  3 rouleaux, 5 symboles, animations blit, connexion CGBank
--  Canal modem: 1011 (different de la roulette sur 1010)
-- ============================================================

-- ── CONFIG ───────────────────────────────────────────────────
local CFG = {
    modem_side = "top",
    server_ch  = 1000,
    my_ch      = 1011,
    bet_min    = 0.5,
    bet_max    = 50,
    bet_default= 1.0,
}

-- ── SYMBOLES ─────────────────────────────────────────────────
-- Chaque symbole: nom, caractere, couleur fg blit, couleur bg blit
-- On utilise des caracteres ASCII + couleurs vives
-- Blit color codes: 0=blk 1=red 2=grn 3=yel 4=blu 5=pur 6=cyn
--   7=wht 8=gry 9=lgy a=lbl b=pnk c=mag d=org e=lim f=brn

local SYMBOLS = {
    -- { id, label(3chars), fg_blit, bg_blit, poids, multiplicateurs }
    -- poids: frequence d'apparition (total = somme de tous les poids)
    -- mult[2] = gain si 2 identiques, mult[3] = gain si 3 identiques
    { id="7",    label=" 7 ", fg="3", bg="1", poids=2,  mult={2, 0, 50}  },  -- 7 = jackpot
    { id="dia",  label="<>+", fg="b", bg="4", poids=4,  mult={2, 0, 20}  },  -- diamant
    { id="bell", label="(o)", fg="3", bg="d", poids=6,  mult={2, 0, 10}  },  -- cloche
    { id="bar",  label="BAR", fg="7", bg="8", poids=8,  mult={2, 0, 5}   },  -- BAR
    { id="ceri", label="*o*", fg="1", bg="2", poids=12, mult={2, 2, 3}   },  -- cerise (paire gagne aussi)
    { id="lemon",label="()", fg="3", bg="2", poids=14, mult={2, 0, 2}   },  -- citron
}
-- Note: mult[1] unused, mult[2]=paire, mult[3]=triple

-- Construction de la roue (weighted)
local REEL = {}
for _, sym in ipairs(SYMBOLS) do
    for _ = 1, sym.poids do
        table.insert(REEL, sym.id)
    end
end
-- Taille de la roue
local REEL_SIZE = #REEL

-- Index par id
local SYM_BY_ID = {}
for _, s in ipairs(SYMBOLS) do SYM_BY_ID[s.id] = s end

-- ── PALETTE ──────────────────────────────────────────────────
local function setup_palette()
    term.setPaletteColor(colors.black,     0x050505)
    term.setPaletteColor(colors.white,     0xF0F0F0)
    term.setPaletteColor(colors.red,       0xCC1100)
    term.setPaletteColor(colors.green,     0x007722)
    term.setPaletteColor(colors.lime,      0x22EE55)
    term.setPaletteColor(colors.yellow,    0xFFCC00)
    term.setPaletteColor(colors.gray,      0x181818)
    term.setPaletteColor(colors.lightGray, 0x3A3A3A)
    term.setPaletteColor(colors.cyan,      0x008899)
    term.setPaletteColor(colors.orange,    0xDD6600)
    term.setPaletteColor(colors.blue,      0x1122AA)
    term.setPaletteColor(colors.lightBlue, 0x44AAFF)
    term.setPaletteColor(colors.pink,      0xFF2266)
    term.setPaletteColor(colors.magenta,   0xBB0099)
    term.setPaletteColor(colors.brown,     0x3D2010)
    term.setPaletteColor(colors.purple,    0x660099)
end

local function restore_palette()
    term.setPaletteColor(colors.black,     0x000000)
    term.setPaletteColor(colors.white,     0xFFFFFF)
    term.setPaletteColor(colors.red,       0xFF0000)
    term.setPaletteColor(colors.green,     0x00FF00)
    term.setPaletteColor(colors.lime,      0x7FFF00)
    term.setPaletteColor(colors.yellow,    0xFFFF00)
    term.setPaletteColor(colors.gray,      0x555555)
    term.setPaletteColor(colors.lightGray, 0xAAAAAA)
    term.setPaletteColor(colors.cyan,      0x00FFFF)
    term.setPaletteColor(colors.orange,    0xFF8800)
    term.setPaletteColor(colors.blue,      0x0000FF)
    term.setPaletteColor(colors.lightBlue, 0xADD8E6)
    term.setPaletteColor(colors.pink,      0xFFB6C1)
    term.setPaletteColor(colors.magenta,   0xFF00FF)
    term.setPaletteColor(colors.brown,     0x8B4513)
    term.setPaletteColor(colors.purple,    0x8B00FF)
end

-- ── API BANQUE ────────────────────────────────────────────────
os.loadAPI("cgbank_api")
local bank = cgbank_api.new(CFG.modem_side, CFG.server_ch, CFG.my_ch)

local MODEM = peripheral.wrap(CFG.modem_side)
local function bank_send(t)
    t.reply_ch = CFG.my_ch
    MODEM.transmit(CFG.server_ch, CFG.my_ch, t)
    local timer = os.startTimer(5)
    while true do
        local e, s, ch, rc, m = os.pullEvent()
        if e == "modem_message" and ch == CFG.my_ch and type(m) == "table" then
            os.cancelTimer(timer); return m
        elseif e == "timer" and s == timer then
            return { ok=false, msg="Timeout" }
        end
    end
end

local W, H = term.getSize()
local SESSION = { logged_in=false, name="", balance=0 }
local BET = CFG.bet_default
local LAST_WIN = 0
local WIN_STREAK = 0
local TOTAL_SPINS = 0

-- ── UTILITAIRES UI ───────────────────────────────────────────
local function cls()
    term.setBackgroundColor(colors.black)
    term.clear(); term.setCursorPos(1,1)
end

local function at(x, y, text, fg, bg)
    if y < 1 or y > H or x < 1 then return end
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    local mx = W - x + 1
    if #text > mx then text = text:sub(1, mx) end
    term.write(text)
end

local function center(y, text, fg, bg)
    at(math.max(1, math.floor((W-#text)/2)+1), y, text, fg, bg)
end

local function fill(y, fg, bg, char)
    at(1, y, string.rep(char or " ", W), fg, bg)
end

local function blit_at(x, y, txt, fg_s, bg_s)
    if y < 1 or y > H or x < 1 then return end
    term.setCursorPos(x, y)
    -- Tronque a la largeur dispo
    local max = W - x + 1
    if #txt > max then
        txt  = txt:sub(1, max)
        fg_s = fg_s:sub(1, max)
        bg_s = bg_s:sub(1, max)
    end
    term.blit(txt, fg_s, bg_s)
end

-- ── LAYOUT ───────────────────────────────────────────────────
-- Ecran 51x19 typique Advanced Computer
-- [Ligne 1]      Header titre
-- [Ligne 2]      Joueur + Solde
-- [Ligne 3]      Separateur
-- [Lignes 4-10]  Zone machine a sous (7 lignes)
-- [Ligne 11]     Separateur
-- [Ligne 12]     Tableau des gains
-- [Ligne 13]     Tableau des gains (suite)
-- [Ligne 14]     Separateur
-- [Ligne 15]     Mise actuelle + boutons +/-
-- [Ligne 16]     Message resultat
-- [Ligne 17]     Bouton SPIN + infos
-- [Ligne 18]     Bouton login/inscription
-- [Ligne 19]     Quit

local SLOT_Y    = 4   -- premiere ligne de la machine
local SLOT_H    = 7   -- hauteur de la zone machine
-- 3 rouleaux: chacun 9 chars de large, separes par 1 char
-- Total: 3*9 + 2 = 29 chars, centre dans W
local REEL_W    = 9
local REEL_GAP  = 1
local N_REELS   = 3
local REELS_TOTAL = N_REELS * REEL_W + (N_REELS-1) * REEL_GAP
local REELS_X   = math.floor((W - REELS_TOTAL) / 2) + 1
-- Position X du centre de chaque rouleau
local REEL_CX   = {}
for i = 0, N_REELS-1 do
    REEL_CX[i+1] = REELS_X + i*(REEL_W + REEL_GAP) + math.floor(REEL_W/2)
end
-- Ligne centrale de la machine (ligne de gain)
local WIN_LINE_Y = SLOT_Y + math.floor(SLOT_H / 2)

-- ── DESSIN DE LA MACHINE ─────────────────────────────────────
-- Dessine le cadre de la machine (fond + bords)
local function draw_machine_frame()
    -- Fond machine
    for y = SLOT_Y, SLOT_Y + SLOT_H - 1 do
        fill(y, colors.black, colors.lightGray)
    end

    -- Bords superieurs/inferieurs du cadre (lignes de neon)
    -- En utilisant blit pour alterner les couleurs
    local top_txt = string.rep("=", W)
    local top_fg  = string.rep("d", W)   -- orange
    local top_bg  = string.rep("8", W)   -- gray
    blit_at(1, SLOT_Y-1,          top_txt, top_fg, top_bg)
    blit_at(1, SLOT_Y+SLOT_H,     top_txt, top_fg, top_bg)

    -- Colonnes separatrices entre rouleaux
    for y = SLOT_Y, SLOT_Y+SLOT_H-1 do
        for i = 1, N_REELS-1 do
            local sx = REELS_X + i*(REEL_W+REEL_GAP) - 1
            at(sx, y, " ", colors.yellow, colors.gray)
        end
    end

    -- Ligne de gain (surlignee)
    local wl_txt = string.rep("-", W)
    local wl_fg  = string.rep("3", W)
    local wl_bg  = string.rep("7", W)
    blit_at(1, WIN_LINE_Y, wl_txt, wl_fg, string.rep("8", W))

    -- Fleches qui indiquent la ligne de gain
    at(REELS_X - 2, WIN_LINE_Y, ">", colors.yellow, colors.lightGray)
    at(REELS_X + REELS_TOTAL + 1, WIN_LINE_Y, "<", colors.yellow, colors.lightGray)
end

-- Dessine UN symbole a une position donnee
-- x,y = coin superieur gauche, sym = table symbole
-- highlight = true si c'est la ligne gagnante
local SYM_H = 3   -- hauteur d'un symbole en lignes

local function draw_symbol(x, y, sym, highlight)
    if not sym then sym = SYM_BY_ID["lemon"] end
    local bg_blit = highlight and "3" or sym.bg   -- jaune si gagnant
    local fg_blit = highlight and "0" or sym.fg

    -- 3 lignes par symbole: bordure / label / bordure
    -- Ligne 1: bordure haut
    local border_fg = highlight and "3" or "9"
    local border_bg = highlight and "3" or sym.bg
    local border_str = "+" .. string.rep("-", REEL_W - 2) .. "+"
    blit_at(x, y,   border_str,
            string.rep(border_fg, REEL_W),
            string.rep(border_bg, REEL_W))
    -- Ligne 2: symbole avec label centre
    local pad = math.floor((REEL_W - 2 - 3) / 2)  -- 2 pour les | , 3 pour le label
    local line2 = "|" .. string.rep(" ", pad) .. sym.label .. string.rep(" ", REEL_W-2-pad-3) .. "|"
    -- Blit ligne 2
    local l2_fg = fg_blit .. string.rep(fg_blit, #line2-2) .. fg_blit
    local l2_bg = bg_blit .. string.rep(bg_blit, #line2-2) .. bg_blit
    blit_at(x, y+1, line2:sub(1, REEL_W),
            l2_fg:sub(1, REEL_W),
            l2_bg:sub(1, REEL_W))
    -- Ligne 3: bordure bas
    blit_at(x, y+2, border_str,
            string.rep(border_fg, REEL_W),
            string.rep(border_bg, REEL_W))
end

-- Dessine les 3 symboles visibles d'un rouleau (position repos)
-- reel_idx = 1|2|3, symbols = table de 3 sym_ids (haut/milieu/bas)
local function draw_reel_static(reel_idx, symbols)
    local x = REELS_X + (reel_idx-1)*(REEL_W+REEL_GAP)
    for row = 1, 3 do
        local sym = SYM_BY_ID[symbols[row]] or SYM_BY_ID["lemon"]
        local y = SLOT_Y + (row-1)*SYM_H
        draw_symbol(x, y, sym, false)
    end
end

-- ── ETAT DES ROULEAUX ────────────────────────────────────────
-- Position courante dans la roue pour chaque rouleau
local reel_pos = { 1, 8, 15 }   -- positions de depart

local function get_sym_at(reel, offset)
    local idx = ((reel_pos[reel] + offset - 1) % REEL_SIZE) + 1
    return REEL[idx]
end

-- Symboles visibles (3 lignes) pour chaque rouleau
local function get_visible(reel)
    return {
        get_sym_at(reel, -1),
        get_sym_at(reel, 0),
        get_sym_at(reel, 1),
    }
end

-- ── ANIMATION SPIN ───────────────────────────────────────────
-- Anime un rouleau qui tourne puis s'arrete sur target_pos
-- On dessine symboles qui defilent (scroll vertical)
-- Pour simuler le scroll: on affiche offset fractionnaire
-- Simplifie: on fait juste defiler les positions entieres

local function spin_reel(reel_idx, target_pos, steps, delay_start, delay_end)
    -- Nombre de steps = tours effectues avant de s'arreter
    local x = REELS_X + (reel_idx-1)*(REEL_W+REEL_GAP)

    for step = 1, steps do
        -- Avancer la position
        reel_pos[reel_idx] = (reel_pos[reel_idx] % REEL_SIZE) + 1

        -- Si derniere frame: aller direct a target
        if step == steps then
            reel_pos[reel_idx] = target_pos
        end

        -- Dessiner les 3 symboles visibles
        local vis = get_visible(reel_idx)
        for row = 1, 3 do
            local sym = SYM_BY_ID[vis[row]] or SYM_BY_ID["lemon"]
            local y = SLOT_Y + (row-1)*SYM_H
            draw_symbol(x, y, sym, false)
        end

        -- Delay interpolé (acceleration -> deceleration)
        local t = step / steps
        local delay
        if t < 0.3 then
            delay = delay_start - (delay_start - 0.03) * (t / 0.3)
        elseif t < 0.7 then
            delay = 0.03
        else
            delay = 0.03 + (delay_end - 0.03) * ((t - 0.7) / 0.3)
        end
        os.sleep(delay)
    end
end

-- Animation complete des 3 rouleaux avec resultats pre-calcules
-- results = { sym_id, sym_id, sym_id }
local function animate_slots(results)
    -- Trouver les positions cibles dans REEL
    local targets = {}
    for r = 1, 3 do
        -- Chercher une occurrence du symbole cible dans la roue
        local candidates = {}
        for i, s in ipairs(REEL) do
            if s == results[r] then table.insert(candidates, i) end
        end
        targets[r] = candidates[math.random(#candidates)]
    end

    -- Lancer les 3 rouleaux en parallele avec des decalages
    -- Rouleau 1: s'arrete en premier
    -- Rouleau 2: s'arrete apres
    -- Rouleau 3: s'arrete en dernier

    -- On utilise parallel.waitForAll pour les faire tourner en meme temps
    -- avec des durees differentes

    local function spin1()
        spin_reel(1, targets[1], 25, 0.12, 0.20)
    end
    local function spin2()
        os.sleep(0.3)  -- demarre 0.3s apres le 1
        spin_reel(2, targets[2], 30, 0.10, 0.22)
    end
    local function spin3()
        os.sleep(0.7)  -- demarre 0.7s apres le 1
        spin_reel(3, targets[3], 35, 0.09, 0.25)
    end

    parallel.waitForAll(spin1, spin2, spin3)
end

-- ── CALCUL DES GAINS ─────────────────────────────────────────
-- Retourne (mult, description) selon les 3 symboles
local function calc_win(s1, s2, s3)
    -- Triple identique
    if s1 == s2 and s2 == s3 then
        local sym = SYM_BY_ID[s1]
        if sym then
            return sym.mult[3], "TRIPLE " .. sym.id:upper() .. " !"
        end
    end
    -- Paire (uniquement pour les cerises)
    if s1 == s2 or s2 == s3 or s1 == s3 then
        -- Cherche la paire
        local pair_id = nil
        if s1 == s2 then pair_id = s1
        elseif s2 == s3 then pair_id = s2
        else pair_id = s1 end
        local sym = SYM_BY_ID[pair_id]
        if sym and sym.mult[2] and sym.mult[2] > 0 then
            return sym.mult[2], "PAIRE " .. pair_id:upper()
        end
    end
    return 0, ""
end

-- ── TABLEAU DES GAINS ────────────────────────────────────────
local function draw_paytable(y)
    fill(y, colors.yellow, colors.black)
    center(y, " TABLEAU DES GAINS ", colors.black, colors.yellow)

    local col1 = math.floor(W * 0.02)
    local col2 = math.floor(W * 0.35)

    at(col1, y+1, "7 7 7", colors.yellow, colors.black)
    at(col1+6, y+1, "x50 mise", colors.lime, colors.black)
    at(col2, y+1, "<>+ <> <> + ", colors.lightBlue, colors.black)
    at(col2+8, y+1, "x20", colors.lime, colors.black)

    at(col1, y+2, "(o)(o)(o)", colors.yellow, colors.black)
    at(col1+10, y+2, "x10", colors.lime, colors.black)
    at(col2, y+2, "BAR BAR BAR", colors.lightGray, colors.black)
    at(col2+12, y+2, "x5", colors.lime, colors.black)

    at(col1, y+3, "*o**o**o*", colors.red, colors.black)
    at(col1+10, y+3, "x3", colors.lime, colors.black)
    at(col2, y+3, "*o* *o*", colors.red, colors.black)
    at(col2+8, y+3, "x2 (paire)", colors.lime, colors.black)
end

-- ── BOUTONS CLIQUABLES ───────────────────────────────────────
local BTNS = {}

local function make_btn(id, x1, y1, x2, y2, label, fg, bg)
    table.insert(BTNS, { id=id, x1=x1, y1=y1, x2=x2, y2=y2,
                          label=label, fg=fg, bg=bg })
end

local function draw_btn(btn, active)
    local bw = btn.x2 - btn.x1 + 1
    local bh = btn.y2 - btn.y1 + 1
    local fg = active and colors.black or btn.fg
    local bg = active and colors.yellow or btn.bg
    for y = btn.y1, btn.y2 do
        at(btn.x1, y, string.rep(" ", bw), fg, bg)
    end
    local lx = btn.x1 + math.floor((bw - #btn.label) / 2)
    local ly = btn.y1 + math.floor(bh / 2)
    at(lx, ly, btn.label, fg, bg)
end

local function draw_all_buttons()
    for _, btn in ipairs(BTNS) do
        draw_btn(btn, false)
    end
end

local function get_clicked_btn(mx, my)
    for _, btn in ipairs(BTNS) do
        if mx >= btn.x1 and mx <= btn.x2 and
           my >= btn.y1 and my <= btn.y2 then
            return btn.id
        end
    end
    return nil
end

-- ── CONSTRUCTION DU LAYOUT COMPLET ───────────────────────────
local BET_Y   = 0
local MSG_Y   = 0
local SPIN_Y  = 0
local FOOT_Y  = 0
local PAY_Y   = 0

local function build_layout()
    BTNS = {}
    PAY_Y  = SLOT_Y + SLOT_H + 1
    BET_Y  = PAY_Y + 4 + 1
    MSG_Y  = BET_Y + 2
    SPIN_Y = MSG_Y + 1
    FOOT_Y = H

    -- Bouton SPIN (grand, centre)
    local spin_w = 15; local spin_h = 3
    local spin_x = math.floor((W - spin_w) / 2) + 1
    make_btn("spin", spin_x, SPIN_Y, spin_x+spin_w-1, SPIN_Y+spin_h-1,
             ">>> SPIN <<<", colors.black, colors.yellow)

    -- Boutons mise
    local bw = 5
    local bx_center = math.floor(W/2)
    make_btn("bet_down", bx_center-12, BET_Y, bx_center-8, BET_Y,
             " << ", colors.white, colors.orange)
    make_btn("bet_up",   bx_center+8,  BET_Y, bx_center+12, BET_Y,
             " >> ", colors.white, colors.orange)

    -- Boutons preset mise
    make_btn("bet_05",  bx_center-20, BET_Y+1, bx_center-15, BET_Y+1, " 0.5", colors.white, colors.lightGray)
    make_btn("bet_1",   bx_center-13, BET_Y+1, bx_center-9,  BET_Y+1, "  1 ", colors.white, colors.lightGray)
    make_btn("bet_5",   bx_center-7,  BET_Y+1, bx_center-3,  BET_Y+1, "  5 ", colors.white, colors.lightGray)
    make_btn("bet_10",  bx_center+1,  BET_Y+1, bx_center+5,  BET_Y+1, " 10 ", colors.white, colors.lightGray)
    make_btn("bet_25",  bx_center+7,  BET_Y+1, bx_center+11, BET_Y+1, " 25 ", colors.white, colors.lightGray)
    make_btn("bet_50",  bx_center+13, BET_Y+1, bx_center+17, BET_Y+1, " 50 ", colors.white, colors.lightGray)

    -- Boutons pied de page
    make_btn("login",    2,    FOOT_Y, 12,   FOOT_Y, "[Connexion]",  colors.cyan,      colors.black)
    make_btn("register", 14,   FOOT_Y, 27,   FOOT_Y, "[Inscription]",colors.lightBlue, colors.black)
    make_btn("quit",     W-10, FOOT_Y, W,    FOOT_Y, "[Quitter]",    colors.lightGray, colors.black)
    make_btn("logout",   2,    FOOT_Y, 15,   FOOT_Y, "[Deconnexion]",colors.lightGray, colors.black)
end

-- ── DESSIN INTERFACE PRINCIPALE ──────────────────────────────
local function draw_hud()
    -- Header neon
    local h_txt = string.rep(" ", W)
    local h_fg  = string.rep("0", W)
    local h_bg  = string.rep("d", W)   -- orange
    blit_at(1, 1, h_txt, h_fg, h_bg)
    center(1, " CGCasino - Slot Machine ", colors.black, colors.orange)

    -- Ligne infos joueur
    fill(2, colors.black, colors.black)
    if SESSION.logged_in then
        at(2, 2, SESSION.name, colors.cyan, colors.black)
        local bal_s = string.format("Solde: %.4f CGC", SESSION.balance)
        at(W - #bal_s - 1, 2, bal_s,
           SESSION.balance > 0 and colors.lime or colors.red,
           colors.black)
        at(math.floor(W/2)-5, 2,
           string.format("Spins: %d", TOTAL_SPINS),
           colors.lightGray, colors.black)
    else
        center(2, "Non connecte - Connectez-vous pour jouer", colors.lightGray, colors.black)
    end
end

local function draw_bet_zone()
    fill(BET_Y, colors.black, colors.black)
    fill(BET_Y+1, colors.black, colors.black)

    -- Label mise
    local bet_str = string.format("%.2f CGC", BET)
    local bx = math.floor(W/2)
    at(bx - #bet_str - 1, BET_Y, "MISE:", colors.lightGray, colors.black)
    at(bx,                BET_Y, bet_str, colors.yellow, colors.black)

    -- Boutons << >>
    for _, btn in ipairs(BTNS) do
        if btn.id == "bet_down" or btn.id == "bet_up" then
            draw_btn(btn, false)
        end
    end
    -- Boutons preset
    for _, btn in ipairs(BTNS) do
        if btn.id:sub(1,4) == "bet_" and btn.id ~= "bet_down" and btn.id ~= "bet_up" then
            -- Highlight si valeur correspond
            local preset = tonumber(btn.id:sub(5)) or (btn.id=="bet_05" and 0.5 or 0)
            local is_active = math.abs(BET - preset) < 0.01
            draw_btn(btn, is_active)
        end
    end
end

local function draw_spin_button(active)
    for _, btn in ipairs(BTNS) do
        if btn.id == "spin" then
            draw_btn(btn, active)
        end
    end
end

local function draw_footer()
    fill(FOOT_Y, colors.black, colors.black)
    if SESSION.logged_in then
        for _, btn in ipairs(BTNS) do
            if btn.id == "logout" or btn.id == "quit" then
                draw_btn(btn, false)
            end
        end
    else
        for _, btn in ipairs(BTNS) do
            if btn.id == "login" or btn.id == "register" or btn.id == "quit" then
                draw_btn(btn, false)
            end
        end
    end
end

local function draw_message(msg, col)
    fill(MSG_Y, colors.black, colors.black)
    if msg and #msg > 0 then
        center(MSG_Y, msg, col or colors.white, colors.black)
    end
end

local function draw_full_ui(msg, msg_col)
    cls()
    draw_hud()
    -- Separateur
    local sep = string.rep("=", W)
    blit_at(1, 3, sep, string.rep("8", W), string.rep("0", W))

    draw_machine_frame()

    -- Dessiner les rouleaux en position courante
    for r = 1, 3 do
        local vis = get_visible(r)
        local x = REELS_X + (r-1)*(REEL_W+REEL_GAP)
        for row = 1, 3 do
            draw_symbol(x, SLOT_Y+(row-1)*SYM_H, SYM_BY_ID[vis[row]], false)
        end
    end

    draw_paytable(PAY_Y)
    draw_bet_zone()
    draw_message(msg, msg_col)
    draw_spin_button(false)
    draw_footer()

    -- Dernier gain
    if LAST_WIN > 0 then
        local win_str = string.format("Dernier gain: +%.4f CGC", LAST_WIN)
        at(W - #win_str - 1, MSG_Y, win_str, colors.lime, colors.black)
    end
end

-- ── WIN ANIMATION ────────────────────────────────────────────
-- Fait clignoter les symboles gagnants
local function flash_win(results, mult, desc)
    local positions = {}
    for r = 1, 3 do
        local x = REELS_X + (r-1)*(REEL_W+REEL_GAP)
        table.insert(positions, { x=x, sym=SYM_BY_ID[results[r]] })
    end

    -- 4 clignotements
    for flash = 1, 4 do
        local highlight = (flash % 2 == 1)
        for _, p in ipairs(positions) do
            draw_symbol(p.x, SLOT_Y+SYM_H, p.sym, highlight)
        end
        -- Message jackpot sur la ligne de gain
        if highlight then
            local msg = " " .. desc .. " x" .. mult .. " "
            center(WIN_LINE_Y, msg, colors.black, colors.yellow)
        else
            -- Redessiner la ligne normale
            local wl_txt = string.rep("-", W)
            blit_at(1, WIN_LINE_Y, wl_txt, string.rep("3", W), string.rep("8", W))
        end
        os.sleep(0.25)
    end
end

-- ── JACKPOT ANIMATION ────────────────────────────────────────
local function jackpot_animation()
    -- Affichage spectaculaire pour le 7 7 7
    for i = 1, 6 do
        local col = (i%2==1) and colors.yellow or colors.orange
        local bg  = (i%2==1) and colors.red    or colors.black
        fill(WIN_LINE_Y, col, bg)
        center(WIN_LINE_Y, "  *** JACKPOT ***  7 7 7 ***  ", col, bg)
        os.sleep(0.2)
    end
end

-- ── LOGIN / INSCRIPTION ───────────────────────────────────────
local function screen_login()
    cls()
    fill(1, colors.black, colors.orange)
    center(1, " CGCasino - Connexion ", colors.black, colors.orange)
    at(2, 4,  "Nom de compte : ", colors.lightGray, colors.black)
    term.setTextColor(colors.cyan); local name = read()
    at(2, 6,  "Mot de passe  : ", colors.lightGray, colors.black)
    term.setTextColor(colors.cyan); local pw = read("*")
    at(2, 8, "Verification...", colors.lightGray, colors.black)

    local res = bank_send({ cmd="login", account=name, password=pw })
    if res.ok then
        SESSION.logged_in = true
        SESSION.name      = name
        SESSION.balance   = res.balance or 0
        at(2, 8, "Bienvenue " .. name .. " ! Solde: " ..
           string.format("%.4f", SESSION.balance) .. " CGC", colors.lime, colors.black)
        os.sleep(1.5)
    else
        at(2, 8, "ECHEC: " .. (res.msg or "?"), colors.red, colors.black)
        os.sleep(2)
    end
end

local function screen_register()
    cls()
    fill(1, colors.black, colors.orange)
    center(1, " CGCasino - Inscription ", colors.black, colors.orange)
    at(2, 4, "Nom de compte  : ", colors.lightGray, colors.black)
    term.setTextColor(colors.cyan); local name = read()
    at(2, 6, "Mot de passe   : ", colors.lightGray, colors.black)
    term.setTextColor(colors.cyan); local pw1 = read("*")
    at(2, 8, "Confirmer mdp  : ", colors.lightGray, colors.black)
    term.setTextColor(colors.cyan); local pw2 = read("*")

    if pw1 ~= pw2 then
        at(2,10,"Mots de passe differents !",colors.red,colors.black)
        os.sleep(2); return
    end
    if #pw1 < 4 then
        at(2,10,"Trop court (4 min).",colors.red,colors.black)
        os.sleep(2); return
    end
    local res = bank_send({ cmd="register", account=name, password=pw1 })
    if res.ok then
        at(2,10,"Compte cree ! Connectez-vous.",colors.lime,colors.black)
    else
        at(2,10,"ECHEC: "..(res.msg or "?"),colors.red,colors.black)
    end
    os.sleep(2)
end

-- ── TOUR DE JEU ──────────────────────────────────────────────
local function do_spin()
    if not SESSION.logged_in then
        draw_message("Connectez-vous pour jouer !", colors.red)
        os.sleep(1.5); return
    end
    if SESSION.balance < BET then
        draw_message("Solde insuffisant !", colors.red)
        os.sleep(1.5); return
    end

    -- Retirer la mise
    local ok, msg, new_bal = bank.withdraw(SESSION.name, BET, "Slot machine")
    if not ok then
        draw_message("Erreur banque: " .. msg, colors.red)
        os.sleep(2); return
    end
    SESSION.balance = new_bal
    TOTAL_SPINS = TOTAL_SPINS + 1

    -- Mettre a jour HUD
    draw_hud()
    draw_spin_button(true)
    draw_message("En cours...", colors.yellow)

    -- Tirer les 3 resultats
    math.randomseed(os.time() * 997 + os.clock() * 100003 + TOTAL_SPINS * 31)
    local results = {}
    for r = 1, N_REELS do
        local idx = math.random(REEL_SIZE)
        results[r] = REEL[idx]
    end

    -- Animer
    animate_slots(results)

    -- Calculer gain
    local mult, desc = calc_win(results[1], results[2], results[3])
    LAST_WIN = 0

    if mult > 0 then
        -- Animation victoire
        if results[1] == "7" and results[2] == "7" and results[3] == "7" then
            jackpot_animation()
        else
            flash_win(results, mult, desc)
        end

        local gain = BET * mult
        LAST_WIN = gain - BET
        local ok2, _, nb2 = bank.deposit(SESSION.name, gain, "Gain slot x"..mult)
        if ok2 then SESSION.balance = nb2 end
        WIN_STREAK = WIN_STREAK + 1

        draw_full_ui(
            string.format("%s  +%.4f CGC (x%d) !", desc, LAST_WIN, mult),
            colors.lime
        )
    else
        WIN_STREAK = 0
        draw_full_ui(
            string.format("Perdu. -%.4f CGC  |  Retentez votre chance !", BET),
            colors.red
        )
    end

    -- Solde final
    local ok3, bal3 = bank.balance(SESSION.name)
    if ok3 then SESSION.balance = bal3 end
    draw_hud()
end

-- ── GESTION MISE ─────────────────────────────────────────────
local BET_STEPS = { 0.5, 1, 2, 5, 10, 25, 50 }
local bet_step_idx = 2  -- 1.0 par defaut

local function set_bet(val)
    BET = math.max(CFG.bet_min, math.min(CFG.bet_max, val))
    -- Trouver l'index le plus proche
    local best = 1
    for i, v in ipairs(BET_STEPS) do
        if math.abs(v - BET) < math.abs(BET_STEPS[best] - BET) then best = i end
    end
    bet_step_idx = best
end

local function bet_up()
    if bet_step_idx < #BET_STEPS then
        bet_step_idx = bet_step_idx + 1
        BET = BET_STEPS[bet_step_idx]
    end
end

local function bet_down()
    if bet_step_idx > 1 then
        bet_step_idx = bet_step_idx - 1
        BET = BET_STEPS[bet_step_idx]
    end
end

-- ── MAIN ─────────────────────────────────────────────────────
setup_palette()
build_layout()
cls()

-- Splash
center(math.floor(H/2)-2, "CGCasino", colors.yellow, colors.black)
center(math.floor(H/2),   "Slot Machine", colors.orange, colors.black)
center(math.floor(H/2)+2, "Connexion CGBank...", colors.lightGray, colors.black)

local ping_ok, ping_msg = bank.ping()
if not ping_ok then
    cls()
    center(math.floor(H/2)-1, "CGBank hors ligne !", colors.red, colors.black)
    center(math.floor(H/2)+1, ping_msg, colors.gray, colors.black)
    os.sleep(4)
    restore_palette(); cls(); return
end
os.sleep(0.5)

math.randomseed(os.time())
-- Positions initiales aleatoires
for r = 1, 3 do
    reel_pos[r] = math.random(REEL_SIZE)
end

local cur_msg = "Connectez-vous et appuyez sur SPIN !"
local cur_col = colors.yellow

while true do
    if SESSION.logged_in then
        local ok, bal = bank.balance(SESSION.name)
        if ok then SESSION.balance = bal end
    end

    draw_full_ui(cur_msg, cur_col)
    cur_msg = nil; cur_col = nil

    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "mouse_click" then
        local mx, my = p2, p3
        local btn = get_clicked_btn(mx, my)

        if btn == "spin" then
            do_spin()
        elseif btn == "quit" then
            break
        elseif btn == "login" and not SESSION.logged_in then
            screen_login()
        elseif btn == "register" and not SESSION.logged_in then
            screen_register()
        elseif btn == "logout" and SESSION.logged_in then
            SESSION.logged_in = false
            SESSION.name = ""; SESSION.balance = 0
            cur_msg = "Deconnecte."; cur_col = colors.lightGray
        elseif btn == "bet_down" then
            bet_down()
        elseif btn == "bet_up" then
            bet_up()
        elseif btn == "bet_05" then set_bet(0.5)
        elseif btn == "bet_1"  then set_bet(1)
        elseif btn == "bet_5"  then set_bet(5)
        elseif btn == "bet_10" then set_bet(10)
        elseif btn == "bet_25" then set_bet(25)
        elseif btn == "bet_50" then set_bet(50)
        end

    elseif ev == "key" then
        local key = p1
        if key == keys.space or key == keys.enter then
            do_spin()
        elseif key == keys.q then
            break
        elseif key == keys.c and not SESSION.logged_in then
            screen_login()
        elseif key == keys.i and not SESSION.logged_in then
            screen_register()
        elseif key == keys.left then
            bet_down()
        elseif key == keys.right then
            bet_up()
        end
    end
end

cls()
center(math.floor(H/2), "A bientot au CGCasino !", colors.yellow, colors.black)
os.sleep(1.2)
restore_palette(); cls()
