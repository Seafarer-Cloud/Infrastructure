import React, { useState } from 'react';
import './App.css';

function App() {
  const [gitUrl, setGitUrl] = useState('');
  const [projectName, setProjectName] = useState('');
  const [dbPassword, setDbPassword] = useState('');
  const [responseMessage, setResponseMessage] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();

    const data = {
      gitUrl,
      projectName,
      dbPassword,
    };

    try {
      const response = await fetch('http://localhost:5000/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      const result = await response.json();
      setResponseMessage(result.message || 'Deployment triggered successfully');
    } catch (error) {
      console.error('Error during deployment:', error);
      setResponseMessage('Error triggering deployment');
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Deploy Your WordPress Application</h1>
        <form onSubmit={handleSubmit} className="deploy-form">
          <div>
            <label htmlFor="gitUrl">GitHub Repository URL</label>
            <input
              type="text"
              id="gitUrl"
              value={gitUrl}
              onChange={(e) => setGitUrl(e.target.value)}
              required
            />
          </div>
          <div>
            <label htmlFor="projectName">Project Name</label>
            <input
              type="text"
              id="projectName"
              value={projectName}
              onChange={(e) => setProjectName(e.target.value)}
              required
            />
          </div>
          <div>
            <label htmlFor="dbPassword">Database Password</label>
            <input
              type="password"
              id="dbPassword"
              value={dbPassword}
              onChange={(e) => setDbPassword(e.target.value)}
              required
            />
          </div>
          <button type="submit">Deploy</button>
        </form>

        {responseMessage && <p>{responseMessage}</p>}
      </header>
    </div>
  );
}

export default App;
