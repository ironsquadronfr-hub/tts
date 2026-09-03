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

-- ⚠ NE PAS PASSER A UN r14 : un bundle portant ce nom a ete construit le 16/08
-- pour tester l'extinction en douceur, il n'a jamais ete publie et n'apporte
-- rien (cf le bloc « ADOUCIR LA DISPARITION » plus bas). r13 reste la reference.
ISQ_SMOKE_BUNDLE = "https://raw.githubusercontent.com/ironsquadronfr-hub/tts/isq-tokens-v2/mod/data/tokens-v2/isq_smoke_volume_r13.unity3d"
ISQ_SILH_NOTCHED = 2.707   -- templateInfo.silhouetteHeight.notched
-- Rayon du prefab : 6.37008, releve sur l'anneau que le mod affiche deja
-- (projector_smokeToken : demi-socle 18,8 mm + 6 pouces). Il n'apparait pas ici
-- puisqu'on ne met rien a l'echelle.
ISQ_SMOKE_HAUT   = 2.707   -- hauteur du prefab
ISQ_SMOKE_MAXCOP = 5       -- garde-fou : chaque copie coute ~160 particules
ISQ_P2 = 12.0              -- portee 2 = 12 pouces = 12 unites TTS (1 pouce = 1 unite ici)

-- ⚠ Tolerance de comparaison des hauteurs, en unites TTS. Sert a decider si deux
-- volumes se touchent ou s'il reste un trou entre eux. Assez large pour absorber
-- le bruit de getPosition, assez fine devant le pas de 2.707.
ISQ_EPS_Y = 0.02

-- ⚠ Vide tolere entre deux volumes, en unites TTS. Comme les volumes conservés
-- ne bougent plus, le raccord avec la tete ne tombe jamais pile et un petit
-- interstice peut s'ouvrir. Le combler couterait une copie entiere (~160
-- particules) posee presque au meme endroit qu'une existante : sous ce seuil on
-- laisse le vide, invisible dans de la fumee diffuse. 0.4 = 15 % du pas.
ISQ_TROU_TOLERE = 0.4

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
-- Delai avant de devoiler un volume neuf, le temps que TTS charge l'assetbundle
-- et cesse d'afficher son cube de remplacement.
--
-- ⚠ DEUX VALEURS, et c'est volontaire. Le volume nait invisible et continue
-- d'emettre pendant qu'il est masque : plus on le devoile tard, plus il apparait
-- DEJA DENSE, donc plus son apparition est brutale. Les 0,4 s ne se justifient
-- qu'a froid, quand aucun volume n'existe encore et que l'asset peut ne pas etre
-- charge. Des qu'il y a deja de la fumee en scene, l'asset est en cache, le cube
-- ne peut plus apparaitre, et on devoile presque tout de suite pour que la copie
-- neuve monte en charge SOUS LES YEUX du joueur au lieu de surgir a moitie faite.
ISQ_DELAI_REVEL = 0.4        -- a froid : aucun volume en scene
ISQ_DELAI_REVEL_CHAUD = 0.05 -- a chaud : l'asset est deja charge

-- ⚠⚠ ADOUCIR LA DISPARITION : TROIS PISTES ESSAYEES, TOUTES ECARTEES.
-- Un volume retire — typiquement la tete, quand le jeton redescend — s'efface
-- aujourd'hui d'un coup. C'est le seul defaut connu qui reste. Tout ce qui suit
-- a ete teste EN JEU le 16/08 ; ne pas le refaire.
--
-- 1. FONDU PAR setColorTint. Le shader de particules du prefab IGNORE la teinte.
--    Baisser l'alpha ne change rien a l'image.
--
-- 2. ENFOUISSEMENT sous le plateau, pour que la table masque le volume a mesure
--    qu'il descend. Techniquement operationnel, mais le rendu ne va pas.
--
-- 3. COUPER L'EMISSION depuis Lua, avec le bundle tel qu'il etait. Impossible :
--      setLoopingEffectIndex  n'existe pas  (« cannot access field »)
--      getLoopingEffects      renvoie null  -> AUCUN effet declare dans le bundle
--      playLoopingEffect(1)   renvoie ok    -> et ne fait rien, faute d'effet
--
-- 4. AJOUTER L'EFFET MANQUANT AU BUNDLE, puis basculer dessus. C'etait la suite
--    logique de la 3, et la seule qui restait. Un bundle r14 a ete construit avec
--    un composant TTSAssetBundleEffects declarant deux boucles — « Fumee », qui
--    reference le systeme de particules, et « Eteint », vide — puis teste en
--    local via le cache TTS. VERDICT : le nuage coupe toujours d'un coup. TTS ne
--    se contente pas d'arreter l'effet sortant, il le PURGE : les bouffees deja
--    nees sont effacees au lieu de finir leur vie. Le bundle r14 n'a donc jamais
--    ete publie et r13 reste la reference.
--
-- ⚠⚠ SUJET CLOS. Les quatre prises possibles — opacite, geometrie, pilotage de
-- l'emission, contenu du bundle — sont epuisees. La disparition seche n'est pas
-- un manque de soin, c'est une limite de TTS : le moteur ne laisse jamais un
-- systeme de particules s'eteindre progressivement sur commande. Ne pas rouvrir
-- sans element nouveau du cote de TTS lui-meme.
ISQ_FONDU = 0          -- garde pour memoire ; plus aucun mecanisme derriere

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

-- Geometrie de la colonne au moment du lacher. Deux valeurs seulement, car on ne
-- calcule plus de grille complete : les volumes deja poses gardent leur hauteur
-- et ne sont donc alignes sur rien (cf isqSmokeShow).
--   yTete = hauteur de base du volume du HAUT. Seule hauteur imposee.
--   sol   = plancher sous lequel il est inutile d'empiler.
function isqSmokeGeometrie()
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
  return sommetJeton + ISQ_SILH_NOTCHED - ISQ_SMOKE_HAUT, sol
end

-- Cree UN volume a la hauteur donnee. Renvoie son GUID, ou nil si la hauteur
-- n'est pas exploitable.
function isqSmokeCreerUn(baseY, delai)
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
  -- ⚠⚠ SURTOUT PAS setPositionSmooth. Il reveille la physique de l'objet : meme
  -- avec collide=false, TTS le deplace comme un objet mobile le temps de
  -- l'animation, et ca part en collisions. On pose donc l'objet avec
  -- setPosition, qui est un placement direct, sans physique.
  --
  -- ⚠ ET AUCUNE INTERPOLATION DE HAUTEUR NON PLUS. Une version precedente
  -- faisait glisser le volume vers sa nouvelle hauteur sur une demi-seconde,
  -- pour adoucir le repositionnement. C'etait une erreur : le decalage a adoucir
  -- ne valait que 0,2 a 0,8, il etait imperceptible tant qu'il etait instantane,
  -- et l'etaler dans le temps l'a rendu parfaitement visible — on voyait le
  -- disque de fumee du bas traverser la table. Depuis, les volumes conservés ne
  -- bougent tout simplement plus en hauteur (cf isqSmokeShow), donc il n'y a
  -- plus rien a adoucir.
  --
  --   cibleY = hauteur de ce volume. FIGEE apres la creation, sauf pour le
  --            volume de TETE, seul a suivre le jeton en hauteur.
  -- Le suivi en x/z, lui, reste permanent pour tous : la colonne accompagne le
  -- jeton quand on le fait glisser sur la table.
  local suivi =
    "cible = '" .. self.getGUID() .. "'\n" ..
    "cibleY = " .. tostring(baseY) .. "\n" ..
    "function onFixedUpdate()\n" ..
    "  local t = getObjectFromGUID(cible)\n" ..
    "  if t == nil then return end\n" ..
    "  local q = t.getPosition()\n" ..
    "  local m = self.getPosition()\n" ..
    "  if math.abs(q.x - m.x) > 0.001 or math.abs(q.z - m.z) > 0.001\n" ..
    "     or math.abs(cibleY - m.y) > 0.001 then\n" ..
    "    self.setPosition({q.x, cibleY, q.z})\n" ..
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
  end, delai or ISQ_DELAI_REVEL)
  return g
end

-- ⚠⚠ LES VOLUMES CONSERVES NE BOUGENT PAS. C'est la regle qui organise toute
-- cette fonction, et il faut la garder en tete avant d'y toucher.
--
-- Ce qu'il y avait avant : une grille de hauteurs recalculee a chaque lacher, sur
-- laquelle on redistribuait les volumes existants par proximite. Comme la grille
-- est indexee sur le sommet du jeton, elle se translate EN ENTIER des que le
-- jeton change d'altitude — donc chaque volume conserve devait se decaler de 0,2
-- a 0,8 pour la rejoindre. Instantane, ce decalage passait inapercu ; adouci par
-- une interpolation, il devenait un disque de fumee qui traverse la table sous
-- les yeux du joueur. Les deux versions montraient un mouvement que rien ne
-- justifie : la fumee posee au sol n'a aucune raison de bouger parce que le jeton
-- est monte sur une caisse.
--
-- Ce qu'on fait a la place, du haut vers le bas :
--   1. le volume de TETE suit le jeton. Lui seul change de hauteur — c'est lui
--      qui porte la regle du sommet — et son mouvement est solidaire du jeton,
--      donc naturel a l'oeil. On ne le reutilise que s'il est encore PROCHE de
--      la nouvelle tete : sinon on le laisse en place et on en cree une neuve,
--      sans quoi un volume pose au sol remonterait d'un etage entier.
--   2. tous les autres restent EXACTEMENT ou ils sont. On se contente de
--      detruire ceux devenus inutiles : passes au-dessus de la tete, ou enfouis
--      sous le sol.
--   3. on comble les manques avec des volumes NEUFS.
--
-- ⚠ Consequence assumee : les volumes figes ne sont plus alignes sur la tete. Le
-- raccord se fait par CHEVAUCHEMENT, jamais bord a bord. Un recouvrement passe
-- inapercu dans de la fumee diffuse, un trou se verrait tout de suite — donc en
-- cas de doute on chevauche. Les ecarts sous ISQ_TROU_TOLERE sont laisses tels
-- quels : combler 20 cm de vide couterait une copie entiere (~160 particules)
-- posee presque au meme endroit qu'une existante.

-- Retire un volume. Sec, faute de mieux — cf le bloc « ADOUCIR LA DISPARITION ».
function isqSmokeRetirer(o)
  if o ~= nil then destroyObject(o) end
end

function isqSmokeShow()
  -- on purge d'abord les GUID morts (objet supprime a la main, par exemple)
  local vivants = {}
  for _, g in ipairs(isqSmokeGUIDs) do
    if getObjectFromGUID(g) then table.insert(vivants, g) end
  end
  isqSmokeGUIDs = vivants

  local yTete, sol = isqSmokeGeometrie()
  local pas = ISQ_SMOKE_HAUT   -- aucune mise a l'echelle : le prefab est aux cotes

  -- ⚠ On releve les hauteurs UNE FOIS. Les interroger au fil des comparaisons
  -- donnait des dizaines de getObjectFromGUID + getPosition par lacher, pour 5
  -- valeurs qui ne bougent pas pendant le calcul.
  local vols = {}
  for _, g in ipairs(isqSmokeGUIDs) do
    local o = getObjectFromGUID(g)
    if o then table.insert(vols, { g = g, o = o, y = o.getPosition().y }) end
  end
  table.sort(vols, function(a, c) return a.y > c.y end)

  -- ⚠ A froid (aucun volume en scene) l'asset peut ne pas etre charge : il faut
  -- le delai long, sinon le cube de remplacement se voit. A chaud il est en
  -- cache, et un delai long ne ferait que rendre l'apparition plus brutale.
  local revel = (#vols == 0) and ISQ_DELAI_REVEL or ISQ_DELAI_REVEL_CHAUD

  -- 1. LA TETE, seul volume autorise a changer de hauteur.
  -- ⚠ On prend le plus PROCHE de la nouvelle tete, pas le plus haut. Avec le plus
  -- haut, un jeton qui monte de deux etages ferait remonter le volume du sol
  -- jusqu'au sommet. Et on ne le reutilise que si l'ecart reste petit devant le
  -- pas : au-dela, ce volume-la est de la fumee qui a coule jusqu'en bas, il doit
  -- rester ou il est et c'est une tete NEUVE qu'il faut creer plus haut.
  local tete, ecartTete
  for _, v in ipairs(vols) do
    local d = math.abs(v.y - yTete)
    if ecartTete == nil or d < ecartTete then tete, ecartTete = v, d end
  end
  if tete and ecartTete >= 0.35 * pas then tete = nil end
  if tete then
    tete.o.setVar("cibleY", yTete)
    tete.y = yTete
  end

  -- 2. LES FIGES. On garde leur hauteur ; on ne detruit que l'inutile.
  -- ⚠ destroyObject annule les minuteries du script appelant : on detruit ICI,
  -- avant toute creation, sinon on effacerait les minuteries de revelation que la
  -- creation vient de poser.
  local figes = {}
  for _, v in ipairs(vols) do
    if v ~= tete then
      -- sous la tete, et debordant encore assez du sol pour valoir ses ~160
      -- particules. Le seuil de 8 % evite le cas frequent du jeton POSE A PLAT,
      -- ou les 6 cm d'epaisseur du jeton declenchaient a eux seuls une copie.
      if v.y < yTete - ISQ_EPS_Y and v.y + pas > sol + 0.08 * pas then
        table.insert(figes, v)
      else
        isqSmokeRetirer(v.o)
      end
    end
  end

  -- 3. ON REMPLIT, du haut vers le bas. « curseur » est la hauteur de base du
  -- dernier volume retenu : tout ce qui est sous lui reste a couvrir.
  local liste, curseur = {}, nil

  if tete then
    tete.o.setInvisibleTo({})
    table.insert(liste, tete.g)
    curseur = yTete
  else
    local g = isqSmokeCreerUn(yTete, revel)
    if g then
      table.insert(liste, g)
      curseur = yTete
    end
  end

  -- 3b. les figes, en comblant d'abord le vide au-dessus de chacun
  for _, v in ipairs(figes) do
    while curseur ~= nil
      and #liste < ISQ_SMOKE_MAXCOP
      and v.y + pas < curseur - ISQ_TROU_TOLERE do
      local g = isqSmokeCreerUn(curseur - pas, revel)
      if g == nil then break end
      table.insert(liste, g)
      curseur = curseur - pas
    end
    if #liste < ISQ_SMOKE_MAXCOP then
      v.o.setInvisibleTo({})
      table.insert(liste, v.g)
      curseur = v.y
    else
      isqSmokeRetirer(v.o)
    end
  end

  -- 3c. sous le dernier volume, on descend jusqu'au sol
  while curseur ~= nil
    and #liste < ISQ_SMOKE_MAXCOP
    and curseur > sol + 0.08 * pas do
    local g = isqSmokeCreerUn(curseur - pas, revel)
    if g == nil then break end
    table.insert(liste, g)
    curseur = curseur - pas
  end

  isqSmokeGUIDs = liste
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
