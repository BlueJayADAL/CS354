#!/bin/bash

SERVICE_NAME="startup-script"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
VNC_SERVICE_NAME="vncserver"
VNC_SERVICE_PATH="/etc/systemd/system/${VNC_SERVICE_NAME}.service"
STARTUP_SCRIPT_PATH="/home/hadoop/startup_script.sh"

# Create the startup script
echo "Creating startup script..."
sudo tee "$STARTUP_SCRIPT_PATH" > /dev/null <<EOF
#!/bin/bash
cd /home/hadoop
/home/hadoop/hadoop-3.4.1/sbin/start-dfs.sh
/home/hadoop/hadoop-3.4.1/sbin/start-yarn.sh
/home/hadoop/spark-3.5.4/sbin/start-master.sh --host localhost --port 7077
/home/hadoop/spark-3.5.4/sbin/start-worker.sh spark://localhost:7077
/home/hadoop/hadoop-3.4.1/bin/mapred --daemon start historyserver
EOF

# Make the startup script executable
sudo chmod +x "$STARTUP_SCRIPT_PATH"

# Create the systemd service file for the startup script
echo "Creating systemd service for startup script..."
sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Run startup script on boot
After=network.target

[Service]
Type=simple
ExecStart=$STARTUP_SCRIPT_PATH
Restart=always
User=hadoop
WorkingDirectory=/home/hadoop
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create the systemd service file for the VNC server
echo "Creating systemd service for VNC server..."
sudo tee "$VNC_SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Start VNC Server for user jj
After=network.target

[Service]
Type=forking
User=jj
Group=jj
WorkingDirectory=/home/jj
ExecStart=/usr/bin/vncserver -localhost no
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon to apply changes
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the startup service to start on boot
echo "Enabling the startup service..."
sudo systemctl enable "$SERVICE_NAME"

# Start the startup service immediately
echo "Starting the startup service..."
sudo systemctl start "$SERVICE_NAME"

# Enable the VNC server service to start on boot
echo "Enabling the VNC server service..."
sudo systemctl enable "$VNC_SERVICE_NAME"

# Start the VNC server service immediately
echo "Starting the VNC server service..."
sudo systemctl start "$VNC_SERVICE_NAME"

# Check service status
echo "Checking startup service status..."
sudo systemctl status "$SERVICE_NAME" --no-pager

echo "Checking VNC server service status..."
sudo systemctl status "$VNC_SERVICE_NAME" --no-pager

echo "Setup completed! The startup script and VNC server will now run at every boot."