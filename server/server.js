const express = require('express');
const { exec } = require('child_process');
const cors = require('cors');  // Importer CORS

const app = express();

// Configurer CORS pour autoriser les requêtes depuis localhost:3000
app.use(cors({
  origin: 'http://localhost:3000'
}));

app.use(express.json());

app.post('/deploy', (req, res) => {
  const { gitUrl, projectName, dbPassword } = req.body;

  if (!gitUrl || !projectName || !dbPassword) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // 1. Cloner le dépôt GitHub
  const cloneCommand = `git clone ${gitUrl} /tmp/${projectName}`;
  exec(cloneCommand, (cloneErr, cloneStdout, cloneStderr) => {
    if (cloneErr) {
      console.error(`Erreur lors du clonage du dépôt : ${cloneErr}`);
      return res.status(500).json({ error: 'Erreur lors du clonage du dépôt' });
    }
    console.log(`Dépôt cloné : ${cloneStdout}`);

    // 2. Construire l'image Docker
    const buildCommand = `docker build -t your-registry/${projectName}:latest /tmp/${projectName}`;
    exec(buildCommand, (buildErr, buildStdout, buildStderr) => {
      if (buildErr) {
        console.error(`Erreur lors du build Docker : ${buildErr}`);
        return res.status(500).json({ error: 'Erreur lors du build Docker' });
      }
      console.log(`Image Docker construite : ${buildStdout}`);

      // 3. Pousser l'image dans un registre Docker
      const pushCommand = `docker push your-registry/${projectName}:latest`;
      exec(pushCommand, (pushErr, pushStdout, pushStderr) => {
        if (pushErr) {
          console.error(`Erreur lors du push Docker : ${pushErr}`);
          return res.status(500).json({ error: 'Erreur lors du push Docker' });
        }
        console.log(`Image Docker poussée : ${pushStdout}`);

        // 4. Déployer sur Kubernetes
        const deployCommand = `kubectl apply -f /path/to/deployment.yaml --namespace=${projectName}`;
        exec(deployCommand, (deployErr, deployStdout, deployStderr) => {
          if (deployErr) {
            console.error(`Erreur lors du déploiement Kubernetes : ${deployErr}`);
            return res.status(500).json({ error: 'Erreur lors du déploiement Kubernetes' });
          }
          console.log(`Déploiement réussi : ${deployStdout}`);
          res.status(200).json({ message: 'Déploiement réussi !' });
        });
      });
    });
  });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Serveur backend lancé sur le port ${PORT}`);
});
