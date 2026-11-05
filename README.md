# 🏠 Home Server

Serveur maison sous Ubuntu, avec Docker Compose :

| Application | Rôle | Adresse |
|---|---|---|
| **Homepage** | Page d'accueil qui regroupe tout | `http://IP:3000` |
| **Immich** | Sauvegarde des photos (comme Google Photos) | `http://IP:2283` |
| **Jellyfin** | Films et séries (« mini Netflix ») | `http://IP:8096` |
| **Seerr** (ex-Jellyseerr) | Demandes de films et séries | `http://IP:5055` |
| **Vaultwarden** | Gestionnaire de mots de passe (Bitwarden) | `http://IP:8222` |
| **Uptime Kuma** | Surveillance : te prévient si un service tombe | `http://IP:3001` |

> ℹ️ Jellyseerr a fusionné avec Overseerr sous le nom **Seerr**. C'est le même outil et la même interface.

---

## 📁 Organisation du dépôt

```
home_server/
├── docker-compose.yml     # définition de toutes les applications
├── .env.example           # modèle de configuration (copié en .env)
├── homepage/config/       # configuration de la page d'accueil
└── scripts/
    ├── install.sh         # installation automatique
    ├── update.sh          # mise à jour des applis
    └── backup.sh          # sauvegarde
```

Sur le serveur, les données sont rangées par défaut dans `/srv/homeserver/` :

```
/srv/homeserver/
├── appdata/   # configs et bases de données (Jellyfin, Vaultwarden…)
├── photos/    # photos Immich
└── media/
    ├── films/   # ← mets tes films ici
    └── series/  # ← et tes séries ici
```

Si tu as un deuxième disque, plus grand, change `PHOTOS_LOCATION` et `MEDIA_LOCATION` dans `.env` pour pointer dessus (ex : `/mnt/data/photos`).

---

## 🚀 Installation

### 1. Récupérer le dépôt sur le serveur

```bash
sudo apt install -y git
git clone https://github.com/AdrienDuot/Home_Server.git ~/home_server
cd ~/home_server
chmod +x scripts/*.sh
```

### 2. Lancer le script d'installation (2 fois)

```bash
./scripts/install.sh
```

- **1er lancement** : il crée le fichier `.env`. Il y met l'IP du serveur, ton fuseau horaire et un mot de passe aléatoire pour la base Immich, puis il s'arrête.
- Vérifie le fichier : `nano .env` (surtout les chemins des données).
- **2e lancement** : il crée les dossiers, télécharge les applis et démarre tout.

```bash
./scripts/install.sh
```

À la fin, il affiche les adresses de chaque application. Tu peux vérifier que tout tourne :

```bash
docker compose ps
```

### 3. Mettre une IP fixe au serveur

Dans l'interface de ta box internet, réserve l'adresse IP du serveur (« bail DHCP statique »). Sinon l'adresse peut changer et les liens ne marcheront plus.

---

## ⚙️ Première configuration de chaque appli

### Immich (photos)
1. Ouvre `http://IP:2283` et crée le compte administrateur.
2. Installe l'appli **Immich** sur ton téléphone (Android/iOS). Comme adresse du serveur, mets `http://IP:2283`.
3. Dans l'appli, active la **sauvegarde automatique** (icône nuage).

### Jellyfin (films & séries)
1. Copie tes films dans `/srv/homeserver/media/films` et tes séries dans `/srv/homeserver/media/series`.
   Nomme-les proprement : `Inception (2010)/Inception (2010).mkv`, `Breaking Bad/Season 01/Breaking Bad S01E01.mkv`.
2. Ouvre `http://IP:8096` et suis l'assistant :
   - Langue : Français.
   - Ajoute une médiathèque **Films**, dossier `/media/films`.
   - Ajoute une médiathèque **Séries**, dossier `/media/series`.
3. Sur la TV ou le téléphone, installe l'appli **Jellyfin**.

### Seerr (demandes de films)
1. Ouvre `http://IP:5055` et choisis **Jellyfin**.
2. Adresse de Jellyfin : `http://jellyfin:8096`. Connecte-toi ensuite avec ton compte Jellyfin.
3. Synchronise les médiathèques. Ta famille pourra se connecter avec ses comptes Jellyfin.

### Uptime Kuma (surveillance)
1. Ouvre `http://IP:3001` et crée un compte.
2. Ajoute une sonde par service, de type **HTTP**. Exemples : `http://immich_server:2283`, `http://jellyfin:8096`, `http://seerr:5055`, `http://vaultwarden:80`, `http://homepage:3000`.
3. Optionnel : ajoute une notification (Telegram, Discord, e-mail, ntfy…) pour être prévenu en cas de panne.

### Vaultwarden (mots de passe) — ⚠ HTTPS obligatoire
Le coffre web de Bitwarden **refuse de fonctionner en HTTP** (sauf depuis le serveur lui-même). La solution la plus simple est **Tailscale**, qui donne aussi l'accès depuis l'extérieur (voir plus bas).

```bash
# après avoir installé Tailscale (section suivante) :
sudo tailscale serve --bg --https=8443 http://localhost:8222
```

1. Tailscale affiche une adresse du type `https://mon-serveur.tailnet-xxxx.ts.net:8443`. Mets-la dans `.env` :
   `VAULTWARDEN_DOMAIN=https://mon-serveur.tailnet-xxxx.ts.net:8443`
2. Relance Vaultwarden : `docker compose up -d vaultwarden`.
3. Ouvre cette adresse et **crée ton compte**.
4. **Ferme les inscriptions** : dans `.env`, mets `VAULTWARDEN_SIGNUPS_ALLOWED=false`, puis relance `docker compose up -d vaultwarden`.
5. Dans l'appli ou l'extension **Bitwarden**, choisis « Auto-hébergé » et mets cette même adresse.

> 🔑 Ce coffre contient tous tes mots de passe : la sauvegarde (voir plus bas) est indispensable.

### Homepage (page d'accueil)
Ouvre `http://IP:3000` : toutes les applis y sont, avec leur état (en marche ou arrêtée).

Pour afficher des statistiques (nombre de films, de photos…) :
1. Crée une clé API dans l'appli voulue :
   - Jellyfin : *Tableau de bord → Clés API*.
   - Immich : *Paramètres du compte → Clés API*.
   - Seerr : *Paramètres → Général*.
2. Mets la clé dans `.env` (`HOMEPAGE_JELLYFIN_KEY=…`, etc.).
3. Décommente le bloc `widget:` correspondant dans `homepage/config/services.yaml`.
4. `docker compose up -d homepage`

---

## 🌍 Accès depuis l'extérieur (Tailscale)

**N'ouvre pas de ports sur ta box.** Utilise plutôt [Tailscale](https://tailscale.com), gratuit pour un usage perso. C'est un réseau privé entre tes appareils.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Installe aussi l'appli Tailscale sur ton téléphone et connecte-toi avec le même compte. Tu peux alors utiliser `http://mon-serveur:2283` (Immich), `http://mon-serveur:8096` (Jellyfin), etc., même en 4G.

Dans l'admin Tailscale, active **MagicDNS** et **HTTPS Certificates** (nécessaire pour `tailscale serve` et Vaultwarden).

Pour ouvrir Homepage via son nom Tailscale, ajoute-le dans `.env` :
`HOMEPAGE_ALLOWED_HOSTS=192.168.1.50:3000,localhost:3000,mon-serveur:3000`

---

## 💾 Sauvegardes

Branche un disque externe, puis :

```bash
./scripts/backup.sh /media/$USER/MonDisque/sauvegarde-serveur
```

Le script sauvegarde :
- la base de données Immich ;
- les photos ;
- toutes les configurations, dont Vaultwarden ;
- le fichier `.env`.

Il garde les 14 dernières sauvegardes.

**Automatiser** (tous les jours à 3h du matin) :
```bash
sudo crontab -e
# ajouter la ligne :
0 3 * * * /home/TON_USER/home_server/scripts/backup.sh /mnt/sauvegarde >> /var/log/homeserver-backup.log 2>&1
```

> 📸 Règle d'or : une photo qui n'existe qu'à un seul endroit n'est pas sauvegardée.

---

## 🔄 Commandes utiles

```bash
docker compose ps                  # état des services
docker compose logs -f jellyfin    # voir les journaux d'une appli
docker compose restart immich-server
docker compose down                # tout arrêter
docker compose up -d               # tout (re)démarrer
./scripts/update.sh                # tout mettre à jour
```

---

## 🎬 Accélération matérielle (optionnel)

Si ton PC a un processeur **Intel avec puce graphique intégrée** (Quick Sync), Jellyfin et Immich peuvent l'utiliser pour convertir les vidéos. Ça soulage beaucoup le processeur.

1. Vérifie : `ls /dev/dri` doit afficher `renderD128`.
2. Trouve le numéro du groupe `render` : `getent group render | cut -d: -f3`.
3. Dans `docker-compose.yml`, décommente les lignes `devices:` / `group_add:` de Jellyfin (mets le bon numéro de groupe), puis relance avec `docker compose up -d`.
4. Dans Jellyfin, va dans *Tableau de bord → Lecture → Transcodage*, choisis **Intel QuickSync (QSV)** ou **VAAPI**, et coche les codecs.

---

## 🧰 Dépannage

| Problème | Solution |
|---|---|
| `permission denied` sur docker | `sudo usermod -aG docker $USER`, puis déconnecte-toi et reconnecte-toi |
| Seerr ne démarre pas | `sudo chown -R 1000:1000 /srv/homeserver/appdata/seerr` |
| Homepage affiche « Host validation failed » | Ajoute l'adresse utilisée dans `HOMEPAGE_ALLOWED_HOSTS` (`.env`) |
| Jellyfin ne voit pas les films | Vérifie les droits : `sudo chown -R $USER: /srv/homeserver/media` |
| Vaultwarden : page blanche / erreur crypto | Il faut passer par HTTPS (voir la section Vaultwarden) |
| Immich lent au début | Normal : il analyse les photos (visages, recherche). Ça peut prendre des heures la première fois |
