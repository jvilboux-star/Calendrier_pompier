# Tournee Calendriers - V0.2 Android

Cette version est preparee pour generer un APK Android **en ligne avec Codemagic**, sans installer Flutter sur ton ordinateur.

## Ce que fait l'application

- Affiche une carte OpenStreetMap.
- Demande l'autorisation GPS et affiche ta position.
- Appui long sur la carte pour enregistrer une maison.
- Trois statuts :
  - Rouge : absent, a repasser.
  - Vert : termine.
  - Orange : a revoir plus tard.
- Ajout d'une note libre.
- Modification ou suppression d'un point.
- Sauvegarde locale sur le telephone.
- Liste rapide des maisons a repasser.

## Pourquoi il n'y a pas de dossier android dans le ZIP

C'est volontaire. Le fichier `codemagic.yaml` lance `scripts/prepare_android.sh` pendant la compilation. Le script demande a Flutter de creer automatiquement le squelette Android compatible avec la version Flutter presente sur Codemagic, puis ajoute les permissions GPS et Internet.

Cela evite de livrer un projet Android qui deviendrait rapidement obsolete.

## Generer l'APK avec Codemagic

### 1. Creer un compte GitHub

Va sur GitHub et cree un compte si tu n'en as pas.

### 2. Creer un depot

Cree un nouveau depot, par exemple :

`pompier-calendriers`

Decompresse ce ZIP puis envoie **le contenu du dossier** dans le depot GitHub. Le fichier `codemagic.yaml` doit etre visible a la racine du depot, au meme niveau que `pubspec.yaml`.

### 3. Connecter le depot a Codemagic

1. Ouvre Codemagic.
2. Cree un compte ou connecte-toi.
3. Choisis **Add application**.
4. Connecte GitHub.
5. Selectionne le depot `pompier-calendriers`.
6. Codemagic doit detecter le fichier `codemagic.yaml`.

### 4. Lancer la compilation

Selectionne le workflow :

`Android APK - Test`

Puis lance le build.

Le workflow effectue automatiquement :

1. Creation du squelette Android.
2. Ajout des permissions GPS et Internet.
3. Installation des dependances Flutter.
4. Compilation avec `flutter build apk --debug`.

### 5. Recuperer l'APK

Quand le build est termine, ouvre la section **Artifacts** du build et telecharge le fichier APK, normalement nomme :

`app-debug.apk`

Envoie-le ensuite sur ton telephone Android et ouvre-le pour l'installer.

Android peut afficher un avertissement du type "autoriser l'installation d'applications inconnues" pour ton navigateur ou ton gestionnaire de fichiers. Il faut autoriser cette source uniquement si tu reconnais bien le fichier que tu viens de compiler.

## Donnees et vie privee

La V0.2 enregistre les points et notes localement sur le telephone via `shared_preferences`. Elle n'envoie pas la liste des maisons vers un serveur de l'application.

La carte elle-meme utilise des tuiles OpenStreetMap accessibles par Internet. Pour une future version largement diffusee, il faudra choisir un fournisseur de tuiles adapte et verifier ses conditions d'utilisation.

## Dependances figees pour la V0.2

- flutter_map 8.3.2
- geolocator 14.1.1
- latlong2 0.10.1
- shared_preferences 2.5.3

Les versions sont figees pour limiter les changements imprevisibles pendant les premiers tests.

## Limites de cette V0.2

- Pas encore de nom/adresse automatique pour une maison.
- Pas d'itineraire optimise.
- Pas de synchronisation cloud.
- Pas de sauvegarde externe si l'application est desinstallee.
- APK debug destine aux tests, pas a une publication Google Play.

## Prochaine version envisageable

Pour une V0.3 : adresse lisible, tri par distance, bouton d'itineraire et filtre pour n'afficher que les maisons a repasser.
