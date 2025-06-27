![image](https://github.com/user-attachments/assets/d419f877-9d3f-4797-9ce0-8187d1411ae7)



# 🔍 Lyarinet Network Scanner Dashboard

This project provides a web-based dashboard to run network scans and view the results in a clean, responsive interface. You can now select which network interface to scan directly from the browser.

## ✅ Features

- 🚀 **Live Scans:** Trigger network scans directly from the web interface.
- 📡 **Interface Selection:** Choose to scan a specific interface (`eth0`, `wlan0`, etc.) or all of them.
- 📊 **Modern UI:** Clean, responsive table layout with device-type icons and live stats.
- 🔎 **Search & Filter:** Instantly search for devices by IP, MAC, hostname, etc.
- 🔄 **Auto-Refresh:** Automatically reloads results every 60 seconds.

## 📁 Project Files

- `api.py` – The Flask web server that handles API requests and serves the frontend.
- `index.html` – The main dashboard page with all the UI and JavaScript logic.
- `netscan.sh` – The core Bash script that performs the network scan using `nmap`.
- `scan_results.json` – The data file where scan results are stored.

---

## 🚀 How to Use

### 1. Generate your scan results:
Make sure your Bash scanner script outputs `scan_results.json` in the same folder as the HTML file.

### 2. Open in your browser:
```bash
firefox scan_results_viewer.html
```
Or with any modern browser: Chrome, Edge, Brave, etc.

### 3. Optional – Serve it locally:
```bash
python3 -m http.server
```
Then open [http://localhost:8000](http://localhost:8000) in your browser.

## 🌟 Optional Features

- 🖼 **Dark Mode:** Ask to enable a dark theme
- 📦 **Self-contained HTML:** Embed JSON results directly in the HTML
- 🌍 **Web Dashboard:** Host on a server (Apache, Nginx, etc.) to access remotely
----
## Step 1: Install Dependencies (One-Time Setup)

### 1. Install system tools (nmap and pip):    

```bash
sudo apt-get update
sudo apt-get install -y nmap python3-pip
```
### 2. Install the required Python library (Flask):

```bash
pip3 install flask
```
## Step 2: Run the Dashboard Script
### 1. Navigate to the correct directory where you saved the file.
```bash 
# Example: If it's in a folder called 'dashboard' on your Desktop
cd ~/Desktop/dashboard
```
### 2. Run the script using sudo. This is the most important part.
```sh
sudo python3 dashboard.py
```
### b. Edit the sudoers file safely:
Run the following command. Never edit /etc/sudoers directly.
```sh
sudo visudo
```
### Add the permission line:
Use the arrow keys to go to the very bottom of the file and add this line. Replace your_username and /full/path/to/netscan.sh with your actual username and the full path from step 4a.
```sh
# Allow the web server to run network scans without a password
your_username ALL=(ALL) NOPASSWD: /home/your_username/network-dashboard/netscan.sh
```

### Why sudo?
The nmap tool needs administrator (root) privileges to perform its most effective and detailed scans (like OS detection and stealth scans). By running the entire Python script with sudo, you grant nmap the permissions it needs to work correctly. This is a simpler approach than configuring the sudoers file.
You will see a message in your terminal indicating the server has started:

```sh
  🚀 Live Network Dashboard Server Starting...
  - To access, open a browser to http://<YOUR_IP>:5000
  - Press CTRL+C to quit.
  ```

  ### Keep this terminal window open! The server stops if you close it.
Step 3: Access Your Dashboard in a Browser
Find your server's IP address. Open a new terminal window (leave the server running in the first one) and run this command:

```sh
hostname -I | awk '{print $1}'
```
#### This will show you your local IP address (e.g., 192.168.1.123).
Open your web browser. On any computer, phone, or tablet connected to the same network, go to the following address, replacing <YOUR_SERVER_IP> with the IP you just found:

```
http://<YOUR_SERVER_IP>:5000
Example: http://192.168.1.123:5000
```


## 💡 Tip
Use the CSV file (`scan_results.csv`) for spreadsheet apps, and the JSON/HTML view for quick, portable browsing.

---
MIT License | © 2025 Asifagaria
