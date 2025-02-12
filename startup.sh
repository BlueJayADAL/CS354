#!/bin/bash

# Switch to user 'jj' and start VNC server
sudo -u jj -i <<EOF
cd /home/jj
/usr/bin/vncserver -localhost no
EOF

# Switch to user 'hadoop' and start big data services
sudo -u hadoop -i <<EOF
/home/hadoop/hadoop-3.4.1/sbin/start-dfs.sh
/home/hadoop/hadoop-3.4.1/sbin/start-yarn.sh
/home/hadoop/hadoop-3.4.1/bin/mapred --daemon start historyserver
/home/hadoop/spark-3.5.4/sbin/start-master.sh --host localhost --port 7077
/home/hadoop/spark-3.5.4/sbin/start-worker.sh spark://localhost:7077
EOF
