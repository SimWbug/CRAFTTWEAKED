-- 1. Configuration du moniteur
-- Cherche automatiquement un moniteur connecté
local monitor = peripheral.find("monitor")

if not monitor then
    print("Erreur : Aucun moniteur detecte !")
    print("Assurez-vous qu'un moniteur est place a cote de l'ordinateur.")
    return
end

-- 2. Chargement de l'image
local imagePath = "blackjack.nfp"
local image = paintutils.loadImage(imagePath)

if not image then
    print("Erreur : Impossible de charger l'image '" .. imagePath .. "'")
    print("Verifiez que le fichier existe bien.")
    return
end

-- 3. Preparation de l'affichage
-- On redirige le dessin vers le moniteur au lieu de l'ecran de l'ordi
local oldTerm = term.redirect(monitor)

-- Optionnel : Regler la taille du texte pour plus de precision (0.5 est le plus petit)
monitor.setTextScale(0.5)

-- Nettoyer le moniteur avant de dessiner
term.setBackgroundColor(colors.black)
term.clear()

-- 4. Affichage de l'image
-- Dessine l'image aux coordonnées X=1, Y=1
paintutils.drawImage(image, 1, 1)

-- 5. Retour au terminal d'origine
term.redirect(oldTerm)

print("Image affichee avec succes sur le moniteur.")