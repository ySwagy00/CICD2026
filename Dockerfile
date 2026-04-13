# ------------------------------------------------------------
# 1. Choix de l'image de base
# ------------------------------------------------------------
# On utilise Node.js version 18, basée sur Alpine Linux.
# Alpine est une distribution très légère → images plus petites,
# déploiements plus rapides, moins de surface d’attaque.
FROM node:18-alpine


# ------------------------------------------------------------
# 2. Définition du répertoire de travail dans le conteneur
# ------------------------------------------------------------
# Toutes les commandes suivantes seront exécutées dans /usr/src/app.
# C’est ici que notre application sera copiée et exécutée.
WORKDIR /usr/src/app


# ------------------------------------------------------------
# 3. Copie des fichiers package.json et package-lock.json
# ------------------------------------------------------------
# On copie uniquement les fichiers nécessaires à l'installation
# des dépendances. Cela permet de profiter du cache Docker :
# si package.json ne change pas, Docker ne réinstalle pas tout.
COPY app/package*.json ./app/


# ------------------------------------------------------------
# 4. Installation des dépendances Node.js
# ------------------------------------------------------------
# --omit=dev : installe seulement les dépendances de production
# --prefix app : indique à npm d’installer dans le dossier app/
#
# Pourquoi ne pas installer les devDependencies ?
# → En production, elles ne servent à rien (tests, outils, etc.)
# → L’image est plus légère et plus sécuritaire.
RUN npm install --omit=dev --prefix app


# ------------------------------------------------------------
# 5. Copie du reste de l'application
# ------------------------------------------------------------
# On copie tout le contenu du dossier app/ dans le conteneur.
# Cela inclut server.js, les fichiers sources, etc.
COPY app/ ./app/


# ------------------------------------------------------------
# 6. Exposition du port
# ------------------------------------------------------------
# L’application écoute sur le port 3000.
# EXPOSE ne publie pas le port, mais documente l’intention.
EXPOSE 3000


# ------------------------------------------------------------
# 7. Commande de démarrage du conteneur
# ------------------------------------------------------------
# On lance l'application Node.js.
# Le chemin "app/server.js" correspond à ce qu’on a copié plus haut.
CMD ["node", "app/server.js"]
 
