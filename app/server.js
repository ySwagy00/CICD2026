const http = require('http');

const PORT = process.env.PORT || 3000;
const ENV = process.env.APP_ENV || 'dev';

const messages = {
  dev: "Bomboclat zbi	 de l'environnement de DEV, je suis Zakaria",
  qa: "Yuh thi  shi workin de l'environnement de QA",
  prod: "Sa marche de l'environnement de PROD",
};

const message = messages[ENV] || 'Hello World';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(message + '\n');
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT} – ${message}`);
});
