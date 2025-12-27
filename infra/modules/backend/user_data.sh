#!/bin/bash
set -euxo pipefail

# Root-only: system updates and packages
_dnfflags="-y"
dnf $_dnfflags update
dnf $_dnfflags install git python3.11 python3.11-pip amazon-cloudwatch-agent

# Write CloudWatch Agent config using variables passed from Terraform
cat <<'CW_CONF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ec2-user/System_Design_Pastebin/pastebin-backend/pastebin-backend.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}-app"
          }
        ]
      }
    }
  }
}
CW_CONF

# Start the CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# App setup as ec2-user
runuser -l ec2-user -c '
  set -euxo pipefail

  cd ~
  if [ ! -d "System_Design_Pastebin" ]; then
    git clone https://github.com/romitsutariya/System_Design_Pastebin.git
  fi
  cd System_Design_Pastebin/pastebin-backend

  /usr/bin/python3.11 -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt

  # Provide SQS queue URL to the app
  export SQS_QUEUE_URL="${queue_url}"
  echo "SQS_QUEUE_URL=${queue_url}" > .env

  # Start backend and log to a file collected by CloudWatch Agent
  nohup uvicorn main:app --host 0.0.0.0 --port 8000 > /home/ec2-user/System_Design_Pastebin/pastebin-backend/pastebin-backend.log 2>&1 &
'
