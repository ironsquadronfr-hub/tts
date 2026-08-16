rangeKey = "smokeToken"

require('!/TokenWithRangeRuler')

-- ===================== Iron Squadron : volume de fumee =====================
-- Le bouton R montre l'emprise de la fumee : l'anneau au sol (comportement
-- d'origine, inchange) ET le volume qu'elle occupe reellement.
--
-- Geometrie voulue par Martin : un cylindre couvrant P1 A PARTIR DU BORD DU
-- JETON, monte a la cote de silhouette A ENCOCHE (creature) au-dessus du jeton,
-- et DESCENDU JUSQU'A LA TABLE. Quand le jeton est perche, le volume s'allonge
-- donc vers le bas : hauteur = 2.707 + (y du jeton - y du sol).
--
-- ⚠⚠ AUCUNE MISE A L'ECHELLE. Le prefab est construit AUX COTES EXACTES de la
-- regle (rayon 6.37008, hauteur 2.707, base a l'origine). Deux raisons de ne
-- jamais l'etirer :
--   1. le rayon est fixe par la REGLE, pas par la taille du jeton ;
--   2. la fumee est faite de BILLBOARDS, et une echelle non uniforme les ECRASE
--      — l'ancienne version, qui posait un volume unite etire en
--      {rayon, hauteur/2, rayon}, les bavait verticalement d'un facteur 3,4.
--
-- Consequence : la hauteur ne se regle pas non plus par l'echelle. Pour
-- descendre jusqu'a la table quand le jeton est perche, on EMPILE des copies.

ISQ_SMOKE_BUNDLE = "https://raw.githubusercontent.com/ironsquadronfr-hub/tts/isq-tokens-v2/mod/data/tokens-v2/isq_smoke_volume_r13.unity3d"
ISQ_SILH_NOTCHED = 2.707   -- templateInfo.silhouetteHeight.notched
-- Rayon du prefab : 6.37008, releve sur l'anneau que le mod affiche deja
-- (projector_smokeToken : demi-socle 18,8 mm + 6 pouces). Il n'apparait pas ici
-- puisqu'on ne met rien a l'echelle.
ISQ_SMOKE_HAUT   = 2.707   -- hauteur du prefab
ISQ_SMOKE_MAXCOP = 5       -- garde-fou : chaque copie coute ~160 particules
ISQ_P2 = 12.0              -- portee 2 = 12 pouces = 12 unites TTS (1 pouce = 1 unite ici)

-- Vitesse d'approche de la hauteur cible, par image physique. 0.12 amene le
-- volume a destination en environ une demi-seconde.
ISQ_APPROCHE = 0.12

isqSmokeGUIDs = {}
isqSmokeVeut = false       -- etat VOULU, distinct de l'etat affiche

local isqBaseOnLoad = onLoad
local isqBaseToggle = toggleRangeRuler

function onLoad(state)
  if isqBaseOnLoad then isqBaseOnLoad(state) end
  isqSmokeGUIDs = {}
  isqSmokeVeut = false
  isqCreerBoutonE()
  -- IMPOSER, jamais basculer : une annulation (Ctrl+Z) rejoue ce demarrage avec
  -- l'etat de l'instantane, et un bascule s'inverserait au second passage.
  local veut, anciens = false, nil
  if state and state ~= "" then
    local ok, t = pcall(function() return JSON.decode(state) end)
    if ok and type(t) == "table" then
      veut = (t.fumee == true)
      anciens = t.volumes
    end
  end
  isqSmokeBalayerOrphelins(anciens)
  isqSmokeVeut = veut
  if veut then Wait.frames(function() isqSmokeShow() end, 4) end
end

-- Bouton E, jumeau du bouton R d'origine, pose a cote de lui : meme gabarit et
-- memes couleurs que dans TokenWithRangeRuler.
--
-- ⚠⚠ LE BOUTON DOIT SE LIRE SUR LES DEUX FACES.
-- Un bouton est attache au repere du jeton : retourne, on le voit par derriere,
-- donc EN MIROIR GAUCHE-DROITE (constate). Le mod d'origine repond en creant
-- DEUX boutons R, le second en {0,0,180}. On ne peut pas copier ca ici : deux
-- « E » superposes se lisent « H ». Un seul bouton, donc, reoriente au
-- retournement.
--
-- Le detail de la formule et le piege du signe sont dans !/RangeRulers, avec les
-- fonctions isqPositionBouton / isqOrientationBouton. Ici on ne fournit que
-- l'angle de PLACEMENT du bouton sur le cercle.
ISQ_E_ANGLE = 35.0

function isqCreerBoutonE()
  self.createButton({
    click_function = "isqToggleEffet",
    function_owner = self,
    label = "E",
    tooltip = "Fumee (effet)",
    position = isqPositionBouton(ISQ_E_ANGLE),
    rotation = isqOrientationBouton(ISQ_E_ANGLE),
    scale = { 0.5, 0.5, 0.5 },
    width = 400,
    height = 300,
    font_size = 200,
    color = { 0, 0, 0, 1 },
    font_color = { 0.1212, 0.8127, 0, 1 },
  })
  -- pour que l'include le reoriente au retournement, comme le R
  isqEnregistrerBouton("E", ISQ_E_ANGLE)
end

function isqToggleEffet()
  isqSmokeVeut = not isqSmokeVeut
  if isqSmokeVeut then isqSmokeShow() else isqSmokeHide() end
end

-- S MAJUSCULE. TTS n'appelle jamais 'onsave' en minuscules : c'est ce piege qui
-- a fait que le Global ne sauvegardait rien depuis 2021.
function onSave()
  -- l'etat VOULU, pas l'affiche : sinon sauvegarder pendant qu'on tient le
  -- jeton en main perdrait la fumee au rechargement.
  -- On note aussi les GUID des volumes : ils survivent a la sauvegarde et il
  -- faudra les detruire au chargement, cf isqSmokeBalayerOrphelins.
  return JSON.encode({ fumee = isqSmokeVeut, volumes = isqSmokeGUIDs })
end

-- ⚠ R redevient CE QU'IL ETAIT : l'anneau au sol, rien d'autre. La fumee est
-- passee sur son propre bouton E, pour pouvoir montrer l'emprise sans subir
-- l'effet, et inversement.
function toggleRangeRuler()
  isqBaseToggle()
end

function onDestroy()
  isqSmokeDetruire()
  if clearRangeRuler then clearRangeRuler() end
end


-- ⚠ Piste ESSAYEE ET ECARTEE : naitre a une echelle minuscule (0,02) pour que le
-- cube de remplacement de TTS disparaisse dans l'epaisseur du jeton. Bonne idee,
-- mais TTS ne dimensionne PAS son remplacant sur l'echelle de l'objet — le cube
-- sortait a taille normale quand meme. Ne pas la retenter.
--
-- Ce qui marche pour les creations qu'on ne peut pas eviter (premiere activation
-- de la session, changement du nombre de copies) : on ne cherche pas a empecher
-- le cube d'exister, on empeche qu'il soit VU. setInvisibleTo le masque « comme
-- s'il etait dans une zone cachee » ; on le revele apres un court delai. La fumee
-- met de toute facon ~2 s a monter en charge, un demi-seconde de retard ne se
-- remarque pas.
ISQ_COULEURS = {
  "White", "Brown", "Red", "Orange", "Yellow", "Green",
  "Teal", "Blue", "Purple", "Pink", "Grey", "Black",
}
ISQ_DELAI_REVEL = 0.4

-- ⚠ PAS DE onPickUp : la fumee SUIT le jeton pendant qu'on le deplace.
-- Il y en avait un, qui garait les volumes le temps du deplacement, contre la
-- levitation du jeton relache sur son propre volume. Mais deux parades avaient
-- ete posees EN MEME TEMPS pour ce probleme — celle-ci et le collider de 2 cm
-- marque « declencheur » cuit dans le prefab — et on ne savait donc pas si la
-- seconde suffisait. Elle suffit. Le suivi de l'enfant garde sa hauteur et ne
-- suit qu'en x/z, donc le nuage reste au sol quand on souleve le jeton.
-- Si la levitation revenait, c'est ce onPickUp qu'il faut remettre :
--     function onPickUp(colorName) isqSmokeHide() end

-- Le jeton peut etre repose sur un decor plus haut ou plus bas : on ne recalcule
-- pas le sol a chaque image (trop cher), on le refait au lacher.
--
-- ⚠ On attend que le jeton soit AU REPOS. Recreer le volume des le lacher le
-- remettrait sous un jeton encore en train de tomber, et on retrouverait la
-- levitation qu'on cherche a supprimer.
function onDrop(colorName)
  if not isqSmokeVeut then return end
  Wait.condition(
    function() isqSmokeShow() end,
    function() return self.resting end,
    5,
    function() isqSmokeShow() end)   -- filet : on n'attend pas indefiniment
end

-- Altitude du sol sous le jeton. Meme principe que le filtre macHitIsGround du
-- patcher : on ignore le jeton lui-meme, le volume, et tout ce qui est en main.
--
-- ⚠⚠ ON PREND LE PLUS BAS DES OBSTACLES, PAS LE PREMIER.
-- Avec le premier, un jeton pose sur un batiment renvoyait le TOIT du batiment :
-- la fumee s'arretait sur le toit au lieu de couler le long des murs jusqu'a la
-- table, et c'est exactement ce qu'on voyait en jeu. Le plus bas donne la table.
-- La borne de portee 2 (voir isqSmokeShow) empeche d'aller chercher le sol de la
-- piece si la table est percee ou si le rayon passe a cote.
function isqGroundY()
  local p = self.getPosition()
  local hits = Physics.cast({
    origin = { p.x, p.y - 0.02, p.z },
    direction = { 0, -1, 0 },
    type = 1,
    max_distance = 30,
  })
  local bas = nil
  for _, h in ipairs(hits or {}) do
    local o = h.hit_object
    -- le filtre par nom suffit et couvre toutes les copies empilees
    if o and o ~= self
       and o.held_by_color == nil
       and o.getName() ~= "Smoke Volume" then
      if bas == nil or h.point.y < bas then bas = h.point.y end
    end
  end
  return bas or (p.y - 0.4)   -- rien touche : on suppose le jeton pose sur la table
end

-- Les hauteurs de base des copies a empiler, du haut vers le bas.
-- Sortie en fonction a part pour que la CREATION et le REPOSITIONNEMENT
-- partagent le meme calcul : c'est en le comparant au nombre d'objets existants
-- qu'on decide si un simple deplacement suffit.
function isqSmokePlan()
  local b = self.getBounds()
  local sommetJeton = b.center.y + b.size.y * 0.5
  local basJeton = b.center.y - b.size.y * 0.5
  -- ⚠ Le nuage descend jusqu'a la table, mais jamais plus bas que P2 sous le
  -- DESSOUS du jeton (consigne de Martin). Sans cette borne, un jeton pose au
  -- bord d'un plateau troue ferait descendre le volume jusqu'au sol de la piece,
  -- et chaque copie coute ~160 particules.
  local sol = math.max(isqGroundY(), basJeton - ISQ_P2)

  -- ⚠ ANCRAGE PAR LE HAUT, jamais par le sol. C'est le SOMMET qui porte la
  -- regle : il doit tomber exactement a (sommet du jeton + 2.707). Empiler
  -- depuis le sol quantifiait ce sommet sur un multiple de 2.707 — un jeton pose
  -- a plat perdait deja les 6 cm d'epaisseur du jeton. En ancrant par le haut,
  -- c'est le BAS qui deborde, et il deborde sous la table, ou le plateau le
  -- masque : le seul cote ou un debordement ne coute rien.
  local sommetVolume = sommetJeton + ISQ_SILH_NOTCHED
  local pas = ISQ_SMOKE_HAUT   -- aucune mise a l'echelle : le prefab est aux cotes

  local plan = {}
  for i = 0, ISQ_SMOKE_MAXCOP - 1 do
    local sommetCopie = sommetVolume - i * pas
    -- On s'arrete des qu'une copie supplementaire ne depasserait presque plus du
    -- sol : elle serait masquee par le plateau et couterait ses ~160 particules
    -- pour rien. Le seuil de 8 % evite le cas frequent du jeton POSE A PLAT, ou
    -- les 6 cm d'epaisseur du jeton declenchaient a eux seuls une copie entiere.
    if i > 0 and sommetCopie <= sol + 0.08 * pas then break end
    table.insert(plan, sommetCopie - pas)
  end
  return plan
end

-- Cree UN volume a la hauteur donnee. Renvoie son GUID, ou nil si la hauteur
-- n'est pas exploitable.
function isqSmokeCreerUn(baseY)
  -- ⚠ baseY est INTERPOLE DANS DU CODE LUA. Un inf ou un nan (bornes d'objet
  -- degenerees) produirait « baseY = nan », qui n'est pas du Lua valide : le
  -- script de l'enfant ne compilerait pas, en silence. On verifie donc que le
  -- nombre est fini. Le GUID, lui, est alphanumerique : rien a echapper.
  if baseY ~= baseY or baseY == math.huge or baseY == -math.huge then
    print("Smoke Token : hauteur de volume invalide, copie ignoree")
    return nil
  end

  -- Suivi confie a l'objet lui-meme, comme le fait deja spawnRangeRuler : evite
  -- une minuterie Lua par jeton, qui tournerait en permanence.
  -- ⚠⚠ LE GLISSEMENT SE FAIT ICI, PAS AVEC setPositionSmooth.
  -- setPositionSmooth reveille la physique de l'objet : meme avec collide=false,
  -- TTS le deplace comme un objet mobile le temps de l'animation, et ca part en
  -- collisions. On interpole donc la hauteur nous-memes et on pose l'objet avec
  -- setPosition, qui est un placement direct, sans physique.
  --   baseY  = hauteur courante, qui approche cibleY image par image
  --   cibleY = hauteur voulue, que le parent met a jour au changement de niveau
  -- Le suivi en x/z reste instantane : c'est seulement la hauteur qui glisse.
  local suivi =
    "cible = '" .. self.getGUID() .. "'\n" ..
    "baseY = " .. tostring(baseY) .. "\n" ..
    "cibleY = " .. tostring(baseY) .. "\n" ..
    "approche = " .. tostring(ISQ_APPROCHE) .. "\n" ..
    "function onFixedUpdate()\n" ..
    "  local t = getObjectFromGUID(cible)\n" ..
    "  if t == nil then return end\n" ..
    "  if math.abs(cibleY - baseY) > 0.001 then\n" ..
    "    baseY = baseY + (cibleY - baseY) * approche\n" ..
    "    if math.abs(cibleY - baseY) < 0.005 then baseY = cibleY end\n" ..
    "  end\n" ..
    "  local q = t.getPosition()\n" ..
    "  local m = self.getPosition()\n" ..
    "  if math.abs(q.x - m.x) > 0.001 or math.abs(q.z - m.z) > 0.001\n" ..
    "     or math.abs(baseY - m.y) > 0.001 then\n" ..
    "    self.setPosition({q.x, baseY, q.z})\n" ..
    "  end\n" ..
    "end"

  local p = self.getPosition()
  -- Spawn en une seule fois, objet deja habille (bundle, verrou, nom, script).
  -- ⚠ Ca ne suffit PAS a supprimer le cube de remplacement — cf isqSmokeHide —
  -- mais c'est plus propre que spawnObject suivi de setCustomObject.
  local vol = spawnObjectJSON({ json = JSON.encode({
    Name = "Custom_Assetbundle",
    Transform = {
      posX = p.x, posY = baseY, posZ = p.z,
      rotX = 0, rotY = 0, rotZ = 0,
      scaleX = 1, scaleY = 1, scaleZ = 1,
    },
    Nickname = "Smoke Volume",
    Locked = true,
    Grid = false, Snap = false, Autoraise = false, Sticky = false,
    Tooltip = false, GridProjection = false, IgnoreFoW = false,
    DragSelectable = false, MeasureMovement = false, HideWhenFaceDown = false,
    CustomAssetbundle = {
      AssetbundleURL = ISQ_SMOKE_BUNDLE,
      AssetbundleSecondaryURL = "",
      MaterialIndex = 0,
      TypeIndex = 0,
      LoopingEffectIndex = 0,
    },
    LuaScript = suivi,
    LuaScriptState = "",
  }) })
  vol.interactable = false
  vol.setInvisibleTo(ISQ_COULEURS)
  local g = vol.getGUID()
  Wait.time(function()
    local o = getObjectFromGUID(g)
    if o then o.setInvisibleTo({}) end
  end, ISQ_DELAI_REVEL)
  return g
end

-- ⚠⚠ AJUSTEMENT INCREMENTAL, PAR PROXIMITE.
-- Deux choses a comprendre ensemble.
--
-- 1. La pile est ancree PAR LE HAUT : le sommet doit tomber sur
--    (sommet du jeton + 2.707). Quand le jeton monte, TOUTES les hauteurs
--    planifiees montent, et plan[1] est la copie du HAUT.
-- 2. On conserve les volumes deja en place et on ne cree que ce qui manque —
--    seules les copies neuves rejouent donc la montee en charge de la fumee.
--
-- ⚠ Combiner les deux avec un appariement POSITIONNEL (volume[i] -> plan[i])
-- donne l'inverse de ce qu'on veut : en montant sur un decor, le volume qui
-- existait AU SOL est reaffecte au sommet — il saute d'un etage — pendant qu'une
-- copie neuve eclot en bas, la ou il y avait deja de la fumee. On apparie donc
-- par PROXIMITE : chaque volume garde la hauteur planifiee la plus proche de la
-- sienne. Mesure sur le cas type (jeton monte sur un batiment de 2,5) :
--   plan   [1.06]  ->  [3.56 ; 0.85]
--   rang        l'ancien part a 3.56, le neuf nait a 0.85   (faux)
--   proximite   l'ancien reste a 0.85, le neuf nait a 3.56  (juste)
--
-- ⚠ Ca ne peut pas etre parfait, et ce n'est pas un defaut d'implementation :
-- le pas de la pile vaut 2.707, donc une montee qui ne change pas le NOMBRE de
-- copies deplace simplement le volume unique, sans rien a preserver. Et le
-- volume conserve se decale un peu (1.06 -> 0.85 ci-dessus) puisque sa hauteur
-- decoule du sommet.
function isqSmokeShow()
  -- on purge d'abord les GUID morts (objet supprime a la main, par exemple)
  local vivants = {}
  for _, g in ipairs(isqSmokeGUIDs) do
    if getObjectFromGUID(g) then table.insert(vivants, g) end
  end
  isqSmokeGUIDs = vivants

  local plan = isqSmokePlan()

  -- ⚠ On releve les hauteurs UNE FOIS avant d'apparier. L'appariement est
  -- glouton, donc en O(n3) : le faire en interrogeant l'objet a chaque
  -- comparaison donnait jusqu'a 125 getObjectFromGUID + getPosition par lacher,
  -- pour 5 valeurs qui ne bougent pas. Le cout tombe a 5 relevés.
  local hauteurs, libre, pris = {}, {}, {}
  for i, g in ipairs(isqSmokeGUIDs) do
    local o = getObjectFromGUID(g)
    hauteurs[i] = o and o.getPosition().y or nil
    libre[i] = (hauteurs[i] ~= nil)
  end

  -- Appariement glouton : a chaque tour on prend la paire (volume, hauteur) la
  -- plus proche encore libre.
  while true do
    local mP, mV, mD
    for pi, y in ipairs(plan) do
      if pris[pi] == nil then
        for vi = 1, #isqSmokeGUIDs do
          if libre[vi] then
            local d = math.abs(hauteurs[vi] - y)
            if mD == nil or d < mD then mD, mP, mV = d, pi, vi end
          end
        end
      end
    end
    if mP == nil then break end
    pris[mP] = isqSmokeGUIDs[mV]
    libre[mV] = false
  end

  -- les volumes non apparies sont en trop.
  -- ⚠ destroyObject annule les minuteries du script appelant : on detruit AVANT
  -- de creer, jamais l'inverse, sinon on effacerait les minuteries de revelation
  -- que la creation vient de poser.
  for vi, g in ipairs(isqSmokeGUIDs) do
    if libre[vi] then
      local o = getObjectFromGUID(g)
      if o then destroyObject(o) end
    end
  end

  -- on reconstruit la liste dans l'ordre du plan, en creant ce qui manque
  local neufs, liste = {}, {}
  for pi, y in ipairs(plan) do
    local g = pris[pi]
    if g == nil then
      g = isqSmokeCreerUn(y)
      if g then neufs[g] = true end
    end
    if g then table.insert(liste, g) end
  end
  isqSmokeGUIDs = liste

  local p = self.getPosition()
  for i, g in ipairs(isqSmokeGUIDs) do
    local o = getObjectFromGUID(g)
    if o and plan[i] then
      -- ⚠ On deplace la CIBLE, pas l'objet : c'est son propre onFixedUpdate qui
      -- l'y amene en glissant. Un volume conserve change de hauteur de 0,2 a 0,8
      -- selon les cas, et pose d'un coup ca fait un saut — tres visible a la
      -- descente, ou rien ne vient le masquer.
      o.setVar("cibleY", plan[i])
      if neufs[g] then
        -- il vient de naitre a la bonne place, et il a sa propre minuterie de
        -- revelation : le devoiler ici annulerait son masquage et le cube de
        -- remplacement redeviendrait visible.
        o.setVar("baseY", plan[i])
        o.setPosition({ p.x, plan[i], p.z })
      else
        o.setInvisibleTo({})
      end
    end
  end
end

-- Eteindre detruit les volumes : c'est ce qui fait que les rallumer REJOUE la
-- montee en charge de la fumee, au lieu de la faire reapparaitre deja pleine.
-- Le cube de remplacement que TTS affiche a la creation suivante est masque par
-- setInvisibleTo, cf isqSmokeCreerUn.
--
-- ⚠ Deux parades au cube ont ete essayees et ecartees avant celle-la : passer de
-- spawnObject a spawnObjectJSON (ne change que la forme du remplacant) et naitre
-- a une echelle minuscule (TTS ne dimensionne pas son remplacant sur l'echelle
-- de l'objet).
function isqSmokeHide()
  isqSmokeDetruire()
end

-- Destruction reelle. Reservee au demarrage (pour balayer ce qu'une sauvegarde
-- aurait laisse) et a la disparition du jeton.
function isqSmokeDetruire()
  local liste = isqSmokeGUIDs
  isqSmokeGUIDs = {}
  for _, g in ipairs(liste) do
    local o = getObjectFromGUID(g)
    -- destroyObject annule les minuteries du script appelant : on ne planifie
    -- rien apres cet appel dans la meme fonction.
    if o then destroyObject(o) end
  end
end

-- Une sauvegarde conserve les volumes (gares a -80 si la fumee etait eteinte).
-- Au chargement on les detruit, sinon ils s'accumuleraient de session en session.
--
-- ⚠ PAR GUID, PAS PAR PARCOURS DE TOUS LES OBJETS. La version precedente
-- appelait getAllObjects() puis lisait getVar("cible") sur chaque objet nomme
-- « Smoke Volume » : cout en N_jetons x N_objets a chaque chargement, sur une
-- table qui en compte des milliers. Et c'etait fragile — si le script de l'enfant
-- n'etait pas encore charge, getVar renvoyait nil et l'orphelin survivait.
-- Les GUID des objets crees survivent a la sauvegarde, on s'en sert directement.
function isqSmokeBalayerOrphelins(guids)
  for _, g in ipairs(guids or {}) do
    local o = getObjectFromGUID(g)
    if o and o.getName() == "Smoke Volume" then destroyObject(o) end
  end
end
