from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import threading
import requests

class ForwardingHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        raw_body = self.rfile.read(content_length)

        try:
            body = json.loads(raw_body)
            forward_url = body.get("forward_request")
        except Exception as e:
            self.send_response(400)
            self.end_headers()
            return

        self.send_response(204)
        self.end_headers()

        if forward_url:
            threading.Thread(target=self.forward_request, args=(forward_url, raw_body)).start()

    def forward_request(self, url, body):
        try:
            headers = {"Content-Type": "application/json"}
            requests.post(url, data=body, headers=headers)
        except Exception as e:
            print(f"[!] Error forwarding to {url}: {e}")

    def log_message(self, format, *args):
        return

def run(server_class=HTTPServer, handler_class=ForwardingHandler, port=1316):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"[+] Listening on port {port}...")
    httpd.serve_forever()

if __name__ == "__main__":
    run()