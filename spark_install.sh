#!/bin/bash

# Ensure the script is run as jj
if [ "$(whoami)" != "jj" ]; then
    echo "This script must be run as user jj!"
    exit 1
fi

# Install Ubuntu and Python packages
echo -e "\n***************************************************************"
echo "Installing Ubuntu and Python packages..."
echo "***************************************************************"
sudo apt-get update
sudo apt install -y jupyter-core jupyter-notebook python3-pip
wget https://downloads.lightbend.com/scala/2.13.16/scala-2.13.16.deb
sudo dpkg -i scala-2.13.16.deb
rm scala-2.13.16.deb
pip3 install --upgrade jupyter
pip3 install --upgrade py4j
pip3 install --upgrade findspark
pip3 install --upgrade jupyter_server
pip3 install --upgrade jupyterlab


# Set up Jupyter Notebook password
echo -e "\n***************************************************************"
echo "Setting up Jupyter Notebook password..."
echo "***************************************************************"
CONFIG_FILE="$HOME/.jupyter/jupyter_notebook_config.py"

# Prompt for password and generate hash
echo "Please enter your desired Jupyter password:"
read -s JUPYTER_PLAIN
echo
echo "Please confirm your password:"
read -s JUPYTER_CONFIRM
echo

if [ "$JUPYTER_PLAIN" != "$JUPYTER_CONFIRM" ]; then
    echo "Passwords do not match! Exiting..."
    exit 1
fi

# Generate password hash
JUPYTER_HASH=$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$JUPYTER_PLAIN'))")

# Create the config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Generating Jupyter Notebook configuration file..."
    /home/jj/.local/bin/jupyter notebook --generate-config
fi

# Remove any existing lines for these settings (optional cleanup)
sed -i '/c.NotebookApp.ip/d' "$CONFIG_FILE"
sed -i '/c.NotebookApp.open_browser/d' "$CONFIG_FILE"
sed -i '/c.NotebookApp.port/d' "$CONFIG_FILE"
sed -i '/c.NotebookApp.token/d' "$CONFIG_FILE"
sed -i '/c.NotebookApp.password/d' "$CONFIG_FILE"

# Append the required configuration settings with hashed password
cat <<EOL >> "$CONFIG_FILE"
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.open_browser = False
c.NotebookApp.port = 8888
c.NotebookApp.token = ''
c.NotebookApp.password = '$JUPYTER_HASH'
EOL

# Create a systemd service file for Jupyter Notebook
echo -e "\n***************************************************************"
echo "Creating a systemd service file for Jupyter Notebook..."
echo "***************************************************************"
SERVICE_FILE="/etc/systemd/system/jupyter.service"

# Write the service file; this requires sudo privileges.
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Jupyter Notebook
After=network.target

[Service]
Type=simple
ExecStart=/home/jj/.local/bin/jupyter lab --config=$CONFIG_FILE
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$HOME
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd so it picks up the new service, then enable and start it.
echo "Enabling and starting the Jupyter Notebook service..."
sudo systemctl daemon-reload
sudo systemctl enable jupyter.service
sudo systemctl restart jupyter.service


# Download and extract Spark
echo -e "\n***************************************************************"
echo "Downloading and extracting Spark..."
echo "***************************************************************"
sudo -u hadoop bash <<EOF
    cd /home/hadoop
    wget https://archive.apache.org/dist/spark/spark-3.5.4/spark-3.5.4-bin-hadoop3-scala2.13.tgz -P /home/hadoop
    tar xzf spark-*.tgz -C /home/hadoop
    mv spark-3.5.4-bin-hadoop3-scala2.13 spark-3.5.4
    chmod 777 /home/hadoop/spark-3.5.4
    chmod 777 /home/hadoop/spark-3.5.4/python
    rm /home/hadoop/spark-*.tgz  # Clean up tar file
EOF

# Define Spark environment variables
SPARK_SETUP="\n###############\n# Spark Setup #\n###############\nexport SPARK_HOME=/home/hadoop/spark-3.5.4\nexport PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin\nexport PYSPARK_PYTHON=/usr/bin/python3\n"

# Add environment variables to hadoop's .bashrc
sudo -u hadoop bash -c "echo -e '$SPARK_SETUP' >> /home/hadoop/.bashrc"

# Add environment variables to jj's .bashrc
echo -e "$SPARK_SETUP" >> /home/jj/.bashrc

# Source the updated .bashrc files
sudo -u hadoop bash -c "source /home/hadoop/.bashrc"
source /home/jj/.bashrc

# Start Spark Master and Worker
echo -e "\n***************************************************************"
echo "Starting Spark Master and Worker..."
echo "***************************************************************"
sudo -u hadoop bash -c "/home/hadoop/spark-3.5.4/sbin/start-master.sh --host localhost --port 7077"
sudo -u hadoop bash -c "/home/hadoop/spark-3.5.4/sbin/start-worker.sh spark://localhost:7077"

# Display final instructions
echo -e "\n***************************************************************"
echo -e "\nSpark installation and setup completed successfully!"
echo "You can now access your Jupyter Notebook server at https://<your-external-ip>:8888"
echo "Use the following password to log in: $JUPYTER_PLAIN"
echo "The Spark Master UI is available at http://localhost:8080."
echo "The Spark Worker UI is available at http://localhost:8081."
echo "***************************************************************"
