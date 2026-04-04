
# Laboratoire CI/CD – GitHub Actions + Docker Hub + k3s

> **Objectif du labo**  
Mettre en place un pipeline CI/CD complet qui :
- construit une image Docker à partir d’une application Node.js,
- pousse l’image sur Docker Hub,
- déploie automatiquement l’application dans un cluster k3s dans les namespaces `dev`, `qa` et `prod` selon la branche Git (`dev`, `qa`, `main`).

---

## 1. Contexte du labo

Dans ce labo, tu vas :

- Travailler avec un **cluster k3s** déjà préparé par ton enseignant.
- Utiliser **GitHub** pour héberger ton code et déclencher le pipeline.
- Utiliser **Docker Hub** pour stocker les images Docker.
- Utiliser **GitHub Actions** pour automatiser build + push + déploiement.

Les environnements sont mappés ainsi :

| Branche Git | Namespace k3s | Tag d’image Docker |
|------------|---------------|--------------------|
| `dev`      | `dev`         | `:dev`             |
| `qa`       | `qa`          | `:qa`              |
| `main`     | `prod`        | `:prod`            |

---

## 2. Prérequis

Avant de commencer, tu dois avoir :

- Un **compte GitHub**.
- Un **compte Docker Hub**.
- L’accès à la **VM control-plane** du cluster k3s (avec VS Code).
- Un **kubeconfig** fourni par ton enseignant (sous forme de texte) qui permet au pipeline de déployer sur le cluster.

---

## 3. Mise en place et récupéreration du projet de départ

### 3.1. Installer la fonctionnalité git, node.js et créer un répertoire pour le projet sur kube-worker1 dans le répertoire projet.
   ````
   sudo apt install git
   sudo apt install npm
   cd /home/etudiant/Documents/project
   code
   ````

### 3.2. Dans VS Code,
   - Aller vous positionner dans projet (Ctrl-K ctrl-O)
   - Faire menu view et terminal pour afficher un terminal
   - Dans le terminal positionnz-vous dans /home/etudiant/Documents/project/ (cd /home/etudiant/Documents/project/)

### 3.3. Fork du dépôt

1. Sur ce repo Git, clique sur **Fork** (en haut à droite).
   
   
  <img width="807" height="126" alt="image" src="https://github.com/user-attachments/assets/6a75eefe-3e00-456b-83f6-4996d646d911" />
<br><br>
2. Choisis ton compte GitHub comme destination.
<br><br>
<img width="807" height="608" alt="image" src="https://github.com/user-attachments/assets/e2039f23-3744-4138-a09e-d5362708b140" />
<br><br>
Tu as maintenant ton propre dépôt avec le code du labo.

### 3.2. Cloner ton fork sur la VM

Sur la VM (dans VS Code ou terminal) tu vas téléchager de ton git le projet en local sur la vm dans le répertoire project.

```bash
git clone https://github.com/<TON_USERNAME>/cicd2026.git
cd cicd2026
```

---

## 4. Structure du projet

Tu devrais voir une structure similaire à :

```text
.
├─ app/
│  ├─ package.json
│  ├─ server.js        # Application Node.js "hello world"
├─ Dockerfile
├─ k8s/
│  ├─ deployment-dev.yaml
│  ├─ deployment-qa.yaml
│  ├─ deployment-prod.yaml
├─ .github/
│  └─ workflows/
│     └─ ci-cd.yaml
└─ README.md
```

> Si certains fichiers manquent, ils seront créés dans les étapes suivantes.

---

## 5. Comprendre l’application

L’application est une petite appli Node.js qui expose un serveur HTTP sur le port `3000` et affiche un message (par exemple `"hello world"`).

Pour la tester localement (optionnel) :

```bash
cd app
npm install
npm start
```

Puis, dans le navigateur de la VM, test cette url.
`http://localhost:3000`

---

## 6. Dockeriser l’application

### 6.1. Vérifier le Dockerfile

Ouvre le fichier `Dockerfile` à la racine du projet. Il devrait ressembler à ceci avec des commentaires pour votre compréhension:

```Dockerfile
FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --only=production

COPY . .

EXPOSE 3000

CMD ["node", "app/server.js"]
```

Ce fichier décrit comment construire l’image Docker de l’application.

---

## 7. Manifests Kubernetes

Les manifests Kubernetes décrivent comment déployer l’application dans le cluster k3s.

### 7.1. Fichier `k8s/deployment-dev.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app-dev
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-app
      env: dev
  template:
    metadata:
      labels:
        app: hello-app
        env: dev
    spec:
      containers:
        - name: hello-app
          image: DOCKER_HUB_USERNAME/hello-app:dev
          ports:
            - containerPort: 3000
          env:
            - name: APP_ENV
              value: dev
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-app-dev
  namespace: dev
spec:
  selector:
    app: hello-app
    env: dev
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
  type: ClusterIP
---
apiVersion: v1
kind: Ingress
metadata:
  name: hello-app-dev
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: "traefik"
spec:
  rules:
# ajouter dans le /etc/host
# 192.168.21.100  hello.cluster.local
    - host: hello.cluster.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-app-dev
                port:
                  number: 80
```

> **Important :**  
> `DOCKER_HUB_USERNAME` sera remplacé automatiquement par ton vrai nom Docker Hub dans le pipeline.

### 7.2. Fichiers `k8s/deployment-qa.yaml` et `k8s/deployment-prod.yaml`

Vous devez les faire et ils devraient être similaires, mais avec :

- `namespace: qa` et tag `:qa` pour `deployment-qa.yaml`
- `namespace: prod` et tag `:prod` pour `deployment-prod.yaml`

---

## 8. Configuration des secrets GitHub

Les secrets permettent de stocker des informations sensibles (mots de passe, tokens, kubeconfig) sans les mettre dans le code.

### 8.1. Créer un token Docker Hub

1. Connecte-toi à **Docker Hub**.
2. Va dans **Account Settings → Security**.
3. Crée un **Access Token**.
4. Copie ce token pour l'utiliser plus tard (tu ne pourras plus le revoir après, donc copie le dans un fichier txt).

### 8.2. Ajouter les secrets dans ton dépôt GitHub

Dans ton dépôt GitHub :

1. Va dans **Settings**.
2. Dans le menu de gauche, clique sur **Secrets and variables → Actions**.
3. Clique sur **New repository secret** et crée les secrets suivants :

- `DOCKERHUB_USERNAME`  
  → ton nom d’utilisateur Docker Hub (ex. `danny123`)

- `DOCKERHUB_TOKEN`  
  → le token Docker Hub que tu as créé

- `KUBECONFIG_CONTENT`  
  → colle ici **tout le contenu** du fichier kubeconfig fourni par ton enseignant

---

## 9. Workflow GitHub Actions

Le workflow GitHub Actions est un fichier YAML qui décrit les étapes du pipeline CI/CD.

### 9.1. Fichier `.github/workflows/ci-cd.yaml`

Ouvre le fichier, il y a des commentaires pour t'aider à le comprendre :

```yaml
name: CI/CD k3s + Docker Hub

on:
  push:
    branches: [ "dev", "qa", "main" ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: ${{ secrets.DOCKERHUB_USERNAME }}/hello-app

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Set image tag based on branch
        id: vars
        run: |
          if [ "${GITHUB_REF_NAME}" = "dev" ]; then
            echo "TAG=dev" >> $GITHUB_OUTPUT
            echo "K8S_ENV=dev" >> $GITHUB_OUTPUT
          elif [ "${GITHUB_REF_NAME}" = "qa" ]; then
            echo "TAG=qa" >> $GITHUB_OUTPUT
            echo "K8S_ENV=qa" >> $GITHUB_OUTPUT
          else
            echo "TAG=prod" >> $GITHUB_OUTPUT
            echo "K8S_ENV=prod" >> $GITHUB_OUTPUT
          fi

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE_NAME }}:${{ steps.vars.outputs.TAG }}

      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/kubectl

      - name: Configure kubeconfig
        run: |
          echo "${{ secrets.KUBECONFIG_CONTENT }}" > kubeconfig
          export KUBECONFIG=$PWD/kubeconfig
          echo "KUBECONFIG=$PWD/kubeconfig" >> $GITHUB_ENV

      - name: Update image in manifest
        run: |
          sed -i "s|DOCKER_HUB_USERNAME/hello-app:${{ steps.vars.outputs.TAG }}|${{ env.IMAGE_NAME }}:${{ steps.vars.outputs.TAG }}|g" k8s/deployment-${{ steps.vars.outputs.K8S_ENV }}.yaml

      - name: Apply Kubernetes manifests
        run: |
          kubectl apply -f k8s/deployment-${{ steps.vars.outputs.K8S_ENV }}.yaml
```

**Ce que fait ce workflow :**

1. Récupère le code (`checkout`).
2. Se connecte à Docker Hub.
3. Choisit un tag d’image selon la branche (`dev`, `qa`, `prod`).
4. Construit et pousse l’image Docker vers Docker Hub.
5. Installe `kubectl`.
6. Configure l’accès au cluster avec le kubeconfig.
7. Met à jour le manifest Kubernetes avec le bon nom d’image.
8. Applique le manifest dans le bon namespace.

---

## 10. Étapes du labo – Ce que tu dois faire

### Étape 1 – Vérifier que tout est en place

- Le dépôt est forké et cloné.
- Les fichiers `Dockerfile`, `k8s/*.yaml` et `.github/workflows/ci-cd.yaml` existent.
- Les secrets GitHub sont configurés (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `KUBECONFIG_CONTENT`).

### Étape 2 – Modifier le message de l’application

1. Ouvre `app/server.js`.
2. Repère le texte `"hello world"`.
3. Modifie-le, par exemple :

- Pour la branche `dev` : `"Hello de l'environnement de DEV"`
- Pour la branche `qa` : `"Hello de l'environnement de QA"`
- Pour la branche `main` : `Hello de l'environnement de PROD"`

> Tu peux commencer par `dev`, puis refaire plus tard pour `qa` et `main`.

### Étape 3 – Pousser sur la branche `dev`

Dans le terminal, à la racine du projet :

```bash
git checkout dev
git add .
git commit -m "Changer le message pour dev"
git push origin dev
```

### Étape 4 – Observer le pipeline GitHub Actions

1. Va sur ton dépôt GitHub.
2. Clique sur l’onglet **Actions**.
3. Tu devrais voir un workflow nommé **CI/CD k3s + Docker Hub** en cours d’exécution.
4. Attends qu’il passe au **vert** (succès).  
   - S’il est **rouge**, clique dessus pour lire les logs et comprendre l’erreur.

### Étape 5 – Vérifier le déploiement dans k3s (namespace `dev`)

Sur la VM control-plane (terminal) :

```bash
kubectl get pods -n dev
kubectl get svc -n dev
```

Tu devrais voir un pod `hello-app-dev` et un service `hello-app-dev`.

Pour tester l’application :

```bash
kubectl port-forward svc/hello-app-dev -n dev 8080:80
```

Puis, dans le navigateur de la VM :  
`http://localhost:8080`

Tu dois voir le message que tu as configuré pour `dev`.

### Étape 6 – Refaire pour `qa` et `prod`

1. Modifie le message dans `server.js` pour `qa`.
2. Bascule sur la branche `qa` :

```bash
git checkout qa
# merge ou re-appliquer la modification selon les consignes du prof
git add .
git commit -m "Change message for qa"
git push origin qa
```

3. Vérifie le pipeline dans l’onglet **Actions**.
4. Vérifie le namespace `qa` :

```bash
kubectl get pods -n qa
kubectl port-forward svc/hello-app-qa -n qa 8081:80
```

5. Refaire la même logique pour `main` → namespace `prod`.

---

## 11. Pour aller plus loin (optionnel)

Si tu as terminé en avance, tu peux :

- Ajouter une étape **tests** dans le workflow (ex. `npm test`) avant le build Docker.
- Ajouter une étape de **validation manuelle** avant le déploiement en `prod`.
- Modifier les manifests pour augmenter le nombre de replicas.

---

## 12. Checklist de fin de labo

- [ ] Les secrets GitHub sont configurés.
- [ ] Le workflow GitHub Actions s’exécute sans erreur pour `dev`.
- [ ] L’application est accessible dans le namespace `dev`.
- [ ] Le pipeline fonctionne aussi pour `qa` et `prod`.
- [ ] Tu comprends le rôle de chaque étape du pipeline.