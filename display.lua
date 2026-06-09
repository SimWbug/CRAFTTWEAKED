local monitor = peripheral.find("monitor")
if not monitor then error("Moniteur non trouve") end

-- Configurer la resolution max pour un 5x5 (environ 71x46)
monitor.setTextScale(0.5)
local monW, monH = monitor.getSize()

-- Charger l'image
local image = paintutils.loadImage("slot.nfp")
if not image then error("Image non trouvee") end

-- Calculer la taille de l'image d'origine
local imgH = #image
local imgW = 0
for _, row in ipairs(image) do
    if #row > imgW then imgW = #row end
end

-- Fonction pour dessiner l'image redimensionnee
local function drawScaledImage(img, targetW, targetH)
    local oldTerm = term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Calcul des ratios
    local scaleX = imgW / targetW
    local scaleY = imgH / targetH
    
    -- On utilise le plus gros ratio pour garder les proportions (aspect ratio)
    local scale = math.max(scaleX, scaleY)
    
    for y = 1, math.floor(imgH / scale) do
        if y > targetH then break end
        for x = 1, math.floor(imgW / scale) do
            if x > targetW then break end
            
            -- On pioche le pixel correspondant dans l'image d'origine
            local origX = math.floor(x * scale)
            local origY = math.floor(y * scale)
            
            if image[origY] and image[origY][origX] then
                local color = image[origY][origX]
                if color > 0 then -- Si ce n'est pas transparent
                    term.setBackgroundColor(color)
                    term.setCursorPos(x, y)
                    term.write(" ")
                end
            end
        end
    end
    term.redirect(oldTerm)
end

-- Executer l'affichage
drawScaledImage(image, monW, monH)
print("Image redimensionnee sur "..monW.."x"..monH)
