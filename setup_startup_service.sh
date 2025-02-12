#!/bin/bash

SERVICE_NAME="startup-script"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="/home/jj/startup.sh"

# Ensure the script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: $SCRIPT_PATH not found. Please create the script before running this setup."
    exit 1
fi

# Create the systemd service file
echo "Creating systemd service..."
sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Run startup script on boot
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=always
User=jj
WorkingDirectory=/home/jj
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set execute permission for the startup script
echo "Setting execute permissions on $SCRIPT_PATH..."
sudo chmod +x "$SCRIPT_PATH"

# Reload systemd daemon to apply changes
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling the startup service..."
sudo systemctl enable "$SERVICE_NAME"

# Start the service immediately
echo "Starting the service..."
sudo systemctl start "$SERVICE_NAME"

# Check service status
echo "Checking service status..."
sudo systemctl status "$SERVICE_NAME" --no-pager

echo "Setup completed! The startup script will now run at every boot."
