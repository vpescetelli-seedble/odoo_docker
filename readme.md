# Odoo Docker Setup

Questa repository consente di configurare e avviare un'istanza di Odoo con supporto per le versioni **Community** e **Enterprise** utilizzando Docker. Segui le istruzioni per impostare il tuo ambiente.

---

## **Prerequisiti**
- Un server con **Docker** e **Docker Compose** installati.
- Le porte **80**, **8080**, **443** e **8443** devono essere libere.
- Accesso alla repository GitHub di **Odoo Enterprise** (per la versione Enterprise).

---

## **Passaggi per la Configurazione**

### **1. Scarica la Repository**
Clona la repository sul tuo server:
```bash
git clone [<repository-url>](https://github.com/vpescetelli-seedble/odoo_docker.git)
cd odoo_docker
```
### **2. Configura il Token GitHub (Versione Enterprise)**
Se utilizzi la versione **Enterprise**, segui questi passaggi:

1. Accedi al tuo account GitHub.
2. Crea un **Personal Access Token (PAT)** con i seguenti permessi:
   - `repo`
   - `read:org`
   - `read:packages`
3. Inserisci il token nel file **Dockerfile** per **staging** e **production**.

#### **Esempio (Dockerfile di Staging):**
```dockerfile
# Dockerfile
ARG GITHUB_TOKEN=tuo_personal_access_token
```
Ripeti la stessa cosa per il Dockerfile di Production

### **3. Cambiare la Versione di Odoo**
Per cambiare la versione di Odoo, segui questi passaggi:

1. Modifica il valore di `ODOO_VERSION` nei Dockerfile di **staging** e **production**.

#### **Esempio:**
```dockerfile
# Dockerfile
ARG ODOO_VERSION=18.0
```
Sostituisci 18.0 con la versione che preferisci

### **4. Avviare i Container**
Una volta configurato, esegui il seguente comando dalla root della repository per costruire e avviare i container:

```bash
docker compose up --build
```

## **Accesso ai Servizi**

### **Staging**
- HTTP: [http://localhost:8080](http://localhost:8080)
- HTTPS: [https://localhost:8443](https://localhost:8443)

### **Production**
- HTTP: [http://localhost:80](http://localhost)
- HTTPS: [https://localhost443](https://localhost)


