#!/bin/bash

# Ensure the script is run as jj
if [ "$(whoami)" != "jj" ]; then
    echo "This script must be run as user jj!"
    exit 1
fi

# Install Java 17 (only for Kafka) without changing system default
echo -e "\n***************************************************************"
echo "Installing Java 21 for Kafka ..."
echo "***************************************************************"
sudo apt update
sudo apt install -y openjdk-21-jdk

# Set up Java 21 for Kafka in hadoop's environment
sudo -u hadoop bash <<'EOF'
    echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> /home/hadoop/.bashrc
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /home/hadoop/.bashrc
EOF

# Set up Java 17 for Kafka in jj's environment
echo -e "\n***************************************************************"
echo "Setting up Java 21 for Kafka in jj's environment..."
echo "***************************************************************"
echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> ~/.bashrc
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc

# Download and install Kafka
echo -e "\n***************************************************************"
echo "Downloading and installing Kafka as user hadoop..."
echo "***************************************************************"
sudo -u hadoop bash <<'EOF'
    cd /home/hadoop
    wget https://dlcdn.apache.org/kafka/4.0.0/kafka_2.13-4.0.0.tgz -P /home/hadoop
    tar -xzf kafka_2.13-4.0.0.tgz -C /home/hadoop
    rm kafka_2.13-4.0.0.tgz
    mv kafka_2.13-4.0.0 kafka
    mkdir -p /home/hadoop/kafka/logs
    chmod 777 /home/hadoop/kafka
    chown -R hadoop:hadoop /home/hadoop/kafka

    # Generate cluster ID for KRaft mode
    cd /home/hadoop/kafka
    CLUSTER_ID=$(bin/kafka-storage.sh random-uuid)
    
    # Configure server.properties (KRaft is default in 4.0)
    cp config/server.properties config/server.properties.bak
        cat >> config/server.properties <<EOL

# KRaft Mode Configuration
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093
inter.broker.listener.name=PLAINTEXT
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
log.dirs=/home/hadoop/kafka/logs
EOL

    # Format log direcotries 
    bin/kafka-storage.sh format --standalone -t $CLUSTER_ID -c config/server.properties
EOF

# Set up Kafka environment variables in hadoop's .bashrc
echo -e "\n***************************************************************"
echo "Setting up Kafka environment variables..."
echo "***************************************************************"
sudo -u hadoop bash <<'EOF'
    echo -e "\n# Kafka Environment" >> /home/hadoop/.bashrc
    echo "export KAFKA_HOME=/home/hadoop/kafka" >> /home/hadoop/.bashrc
    echo "export PATH=\$PATH:\$KAFKA_HOME/bin" >> /home/hadoop/.bashrc
    source /home/hadoop/.bashrc
EOF

# Set up Kafka evnvironment variables for jj
echo -e "\n***************************************************************"
echo "Setting up Kafka environment variables for user jj..."
echo "***************************************************************"
echo -e "\n# Kafka Environment" >> ~/.bashrc
echo "export KAFKA_HOME=/home/hadoop/kafka" >> ~/.bashrc
echo "export PATH=\$PATH:\$KAFKA_HOME/bin" >> ~/.bashrc
source ~/.bashrc

# Create systemd service (using direct Java 17 path)
echo -e "\n***************************************************************"
echo "Creating systemd service for Kafka..."
echo "***************************************************************"
sudo bash -c 'cat > /etc/systemd/system/kafka.service' <<EOL
[Unit]
Description=Apache Kafka Server
After=network.target

[Service]
Type=simple
User=hadoop
Group=hadoop
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64"
Environment="PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/home/hadoop/kafka/bin/kafka-server-start.sh /home/hadoop/kafka/config/server.properties
ExecStop=/home/hadoop/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
WorkingDirectory=/home/hadoop/kafka
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOL

# Enable and start service
echo "Enabling and starting Kafka..."
sudo systemctl daemon-reload
sudo systemctl enable kafka
sudo systemctl start kafka
sleep 5  # Wait for startup
sudo systemctl status kafka --no-pager

# Verification
echo -e "\n***************************************************************"
echo "Verifying installation..."
sudo -u hadoop bash -c "/home/hadoop/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null" && \
    echo "Kafka is running successfully!" || echo "Kafka startup check failed"

# Final instructions
cat <<EOL

***************************************************************
Kafka 4.0 (KRaft mode) installation complete!

Key Paths:
  Kafka Home:    /home/hadoop/kafka
  Java 21:      /usr/lib/jvm/java-21-openjdk-amd64
  Logs:         /home/hadoop/kafka/logs
  Config:       /home/hadoop/kafka/config/server.properties

Management:
  Start:        sudo systemctl start kafka
  Stop:         sudo systemctl stop kafka
  Status:       sudo systemctl status kafka
  Logs:         journalctl -u kafka -f
***************************************************************
EOL


   
