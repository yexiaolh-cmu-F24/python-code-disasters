#!/bin/bash
# Initialization script for Hadoop cluster
# This script runs on cluster initialization

set -e

echo "Initializing Hadoop cluster..."

# Install Python dependencies
pip3 install --upgrade pip
pip3 install mrjob

# Configure Hadoop settings
echo "Configuring Hadoop..."

# Set environment variables
export HADOOP_HOME=/usr/lib/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Ensure proper permissions
chmod -R 755 /usr/lib/hadoop

echo "Hadoop initialization complete!"


