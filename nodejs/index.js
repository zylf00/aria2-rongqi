const http = require('http');
const fs = require('fs');
const exec = require("child_process").exec;
const PORT = process.env.PORT || 3000; 

// Run start.sh
fs.chmod("start.sh", 0o777, (err) => {
  if (err) {
      console.error(`start.sh empowerment failed: ${err}`);
      return;
  }
  console.log(`start.sh empowerment successful`);
  const child = exec('bash start.sh');
  child.stdout.on('data', (data) => {
      console.log(data);
  });
  child.stderr.on('data', (data) => {
      console.error(data);
  });
  child.on('close', (code) => {
      console.log(`child process exited with code ${code}`);
      console.clear();
      console.log(`App is running`);
  });
});

// create HTTP server
const server = http.createServer((req, res) => {
    if (req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Hello world!');
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
    }
  });

server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
