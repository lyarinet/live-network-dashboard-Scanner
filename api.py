#!/usr/bin/env python3
from flask import Flask, jsonify, send_from_directory, request
import subprocess
import os
import logging
import re

# Configure basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)

# The absolute path to the directory where this script is located
APP_DIR = os.path.dirname(os.path.abspath(__file__))
SCAN_SCRIPT_PATH = os.path.join(APP_DIR, 'netscan.sh')
RESULTS_JSON_PATH = os.path.join(APP_DIR, 'scan_results.json')

def get_network_interfaces():
    """Helper function to get a list of network interfaces, plus 'all'."""
    try:
        # Command to list interface names, excluding the loopback 'lo'
        cmd = "ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        interfaces = result.stdout.strip().split('\n')
        # Add 'all' as a primary option
        return ['all'] + [iface for iface in interfaces if iface]
    except Exception as e:
        logging.error(f"Could not get network interfaces: {e}")
        # Provide a fallback for safety
        return ['all']

@app.route('/')
def serve_index():
    """Serves the main index.html file."""
    logging.info("Serving index.html")
    return send_from_directory(APP_DIR, 'index.html')

@app.route('/scan_results.json')
def serve_scan_results():
    """Serves the latest scan results JSON file, creating an empty one if it doesn't exist."""
    if not os.path.exists(RESULTS_JSON_PATH):
        logging.warning("scan_results.json not found, creating an empty one.")
        with open(RESULTS_JSON_PATH, 'w') as f:
            f.write("[]")
    return send_from_directory(APP_DIR, 'scan_results.json')

@app.route('/api/interfaces', methods=['GET'])
def list_interfaces():
    """API endpoint to provide the list of available network interfaces."""
    interfaces = get_network_interfaces()
    return jsonify(interfaces)

@app.route('/api/scan', methods=['POST'])
def trigger_scan():
    """
    API endpoint to trigger the netscan.sh script.
    Requires the script to be runnable with passwordless sudo.
    Accepts a JSON body like: {"interface": "eth0"}
    """
    logging.info("Received request to /api/scan")

    if not os.path.exists(SCAN_SCRIPT_PATH):
        logging.error(f"Scan script not found at {SCAN_SCRIPT_PATH}")
        return jsonify({"status": "error", "message": "Scan script not found on server."}), 500

    data = request.get_json()
    if not data or 'interface' not in data:
        return jsonify({"status": "error", "message": "Missing 'interface' in request body."}), 400

    selected_interface = data['interface']
    
    # --- SECURITY VALIDATION ---
    # Ensure the provided interface is one of the ones found on the system
    available_interfaces = get_network_interfaces()
    if selected_interface not in available_interfaces:
        logging.warning(f"Invalid interface '{selected_interface}' requested by client.")
        return jsonify({"status": "error", "message": "Invalid interface specified."}), 400
    
    logging.info(f"Scan requested for interface: {selected_interface}")

    # These inputs correspond to the prompts in netscan.sh:
    # 1. Interface choice: e.g., "eth0" or "all"
    # 2. Scan type: "1" (Standard Scan)
    script_input = f"{selected_interface}\n1\n"
    command = ['sudo', SCAN_SCRIPT_PATH]

    try:
        logging.info(f"Executing command: {' '.join(command)} with input '{script_input.strip()}'")
        process = subprocess.run(
            command,
            input=script_input,
            text=True,
            capture_output=True,
            check=True,
            timeout=300
        )
        logging.info("Scan script executed successfully.")
        logging.debug(f"Script STDOUT: {process.stdout}")
        return jsonify({"status": "success", "message": "Scan completed."}), 200

    except subprocess.TimeoutExpired:
        logging.error("Scan script timed out.")
        return jsonify({"status": "error", "message": "Scan script timed out after 5 minutes."}), 500
    except subprocess.CalledProcessError as e:
        logging.error(f"Scan script failed with exit code {e.returncode}.")
        logging.error(f"Script STDERR: {e.stderr}")
        return jsonify({"status": "error", "message": "Scan script failed to execute.", "details": e.stderr}), 500
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        return jsonify({"status": "error", "message": f"An unexpected server error occurred: {e}"}), 500

if __name__ == '__main__':
    logging.info("Starting Flask server on http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)