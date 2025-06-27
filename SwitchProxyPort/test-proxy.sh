#!/bin/bash

echo "🧪 Testing SwitchProxyPort..."
echo ""
echo "📋 Test Instructions:"
echo "1. Run the app: open SwitchProxyPort.app"
echo "2. Click the status bar icon and turn ON the proxy"
echo "3. Keep this terminal open to see logs"
echo "4. In another terminal, test with:"
echo "   curl -x http://127.0.0.1:8080 http://127.0.0.1:3000"
echo ""
echo "📊 You can monitor logs with:"
echo "   log stream --predicate 'processImagePath contains \"SwitchProxyPort\"' --level debug"
echo ""
echo "🐛 Or check Console.app for SwitchProxyPort logs"
echo ""
echo "🎯 Expected target ports to test:"
echo "   - Port 3000 (default)"
echo "   - Port 3001"  
echo "   - Port 3002"
echo ""
echo "💡 Make sure you have a service running on the target port (e.g., a simple HTTP server)"
echo ""
echo "🚀 Starting test server on port 3000 for 30 seconds..."

# Create a simple test server
python3 -c "
import http.server
import socketserver
import threading
import time

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        message = f'Hello from test server on port 3000! Request: {self.path}'
        self.wfile.write(message.encode())
        print(f'✅ Received request: {self.path}')

    def log_message(self, format, *args):
        print(f'🌐 Test Server: {format % args}')

PORT = 3000
with socketserver.TCPServer(('127.0.0.1', PORT), TestHandler) as httpd:
    print(f'🟢 Test server running on http://127.0.0.1:{PORT}')
    print('📡 Ready to receive proxy requests...')
    
    # Run for 30 seconds
    timer = threading.Timer(30.0, lambda: httpd.shutdown())
    timer.start()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        print('🛑 Test server stopped')
" &

SERVER_PID=$!

echo ""
echo "🔥 Test server started (PID: $SERVER_PID)"
echo "💪 Now test the proxy with:"
echo "   curl -x http://127.0.0.1:8080 http://127.0.0.1:3000"
echo ""
echo "⏱️  Server will auto-stop in 30 seconds, or press Ctrl+C to stop manually"

# Wait for server to finish
wait $SERVER_PID

echo ""
echo "✅ Test completed!"