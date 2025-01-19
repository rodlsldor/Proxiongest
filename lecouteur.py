from http.server import BaseHTTPRequestHandler, HTTPServer
import subprocess
import urllib.parse

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Parse les paramètres de l'URL
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        action = query.get("action", [""])[0]
        platform = query.get("platform", [""])[0]
        param1 = query.get("param1", [""])[0]
        param2 = query.get("param2", [""])[0]

        # Appelle le script Bash avec les paramètres
        try:
            result = subprocess.run(
                ["/chemin/vers/servo.sh", action, platform, param1, param2],
                capture_output=True,
                text=True,
                check=True
            )
            self.send_response(200)
            self.end_headers()
            self.wfile.write(result.stdout.encode())
        except subprocess.CalledProcessError as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(e.stderr.encode())

# Configurer le serveur
server = HTTPServer(('0.0.0.0', 5678), RequestHandler)
print("Serveur en écoute sur le port 5678...")
server.serve_forever()
