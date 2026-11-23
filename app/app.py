import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body = b"healthy\n"
            content_type = "text/plain; charset=utf-8"
        else:
            payload = {
                "message": os.environ.get("APP_MESSAGE", "Hello from the API"),
                "service": "ict-lab-api",
            }
            body = (
                "<!doctype html><html lang='en'><meta charset='utf-8'>"
                "<title>ICT Infrastructures</title>"
                "<h1>" + payload["message"] + "</h1>"
                "<p>Response from service " + payload["service"] + ".</p>"
                "</html>\n"
            ).encode("utf-8")
            content_type = "text/html; charset=utf-8"

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(json.dumps({"client": self.client_address[0], "request": fmt % args}))


HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
