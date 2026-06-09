# serve.py — Local dev server for coordinate_picker.html
#
# Serves static files AND proxies /api/* requests to the Vercel backend,
# avoiding all CORS issues.
#
# Usage:
#   cd D:\Gears\BotaniNav-main2
#   python serve.py
#   Open http://localhost:8080/coordinate_picker.html

import http.server
import urllib.request
import urllib.error
import json

PORT = 8080
VERCEL_API = 'https://web-database-six.vercel.app/api'


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Proxy /api/* to Vercel
        if self.path.startswith('/api/'):
            remote_path = self.path[4:]  # strip /api prefix
            url = f'{VERCEL_API}{remote_path}'
            try:
                req = urllib.request.Request(url)
                with urllib.request.urlopen(req, timeout=15) as resp:
                    data = resp.read()
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(data)
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
            except Exception as e:
                self.send_response(502)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
            return

        # Serve static files normally
        super().do_GET()

    def log_message(self, format, *args):
        # Cleaner logging
        print(f'  {args[0]}')


if __name__ == '__main__':
    with http.server.HTTPServer(('', PORT), ProxyHandler) as server:
        print(f'🌱 BotaniNav dev server running at http://localhost:{PORT}')
        print(f'   Open http://localhost:{PORT}/coordinate_picker.html')
        print(f'   API proxy: /api/* → {VERCEL_API}/*')
        print()
        server.serve_forever()
