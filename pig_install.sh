#!/bin/bash

# Ensure the script is run as jj
if [ "$(whoami)" != "jj" ]; then
    echo "This script must be run as user jj!"
    exit 1
fi

# Download and extract Pig
echo -e "\n***************************************************************"
echo "Downloading and extracting Pig..."
echo "***************************************************************"
sudo -u hadoop bash <<EOF
    wget https://dlcdn.apache.org/pig/pig-0.17.0/pig-0.17.0.tar.gz -P /home/hadoop
    tar xzf /home/hadoop/pig-0.17.0.tar.gz -C /home/hadoop
    rm /home/hadoop/pig-0.17.0.tar.gz  # Clean up tar file
EOF

# Define Pig environment variables
PIG_SETUP="\n#############\n# PIG Setup #\n#############\nexport PIG_HOME=/home/hadoop/pig-0.17.0\nexport PATH=\$PATH:\$PIG_HOME/bin\nexport PIG_CLASSPATH=\$PIG_HOME/conf:\$HADOOP_INSTALL/etc/hadoop\nexport PIG_CONF_DIR=\$PIG_HOME/conf\n"

# Add environment variables to hadoop's .bashrc
sudo -u hadoop bash -c "echo -e '$PIG_SETUP' >> /home/hadoop/.bashrc"

# Add environment variables to jj's .bashrc
echo -e "$PIG_SETUP" >> /home/jj/.bashrc

# Source the updated .bashrc files
sudo -u hadoop bash -c "source /home/hadoop/.bashrc"
source /home/jj/.bashrc

echo -e "\nPig installation and setup completed successfully!"
