#!/bin/bash
set -euxo pipefail

# Root-only: system updates and packages
dnf -y update
dnf -y install git python3.11 python3.11-pip

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

  # Run your data script if needed:
  # python your_data_script.py

  nohup uvicorn main:app --host 0.0.0.0 --port 8000 > ~/pastebin-backend.log 2>&1 &
'