provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

resource "aws_instance" "cyberitex_flask_api" {
  ami           = "ami-0e2c8caa4b6378d8c" # Replace with the desired AMI ID
  instance_type = "t2.micro"     # Choose instance type

  # Add a key pair for SSH access
  key_name = "your-key-name"     # Replace with your key pair name

  # Configure user data for instance initialization
  user_data = <<-EOT
    #!/bin/bash
    set -e
    curl -sSL https://raw.githubusercontent.com/CyberITEX/cyberitex-flask-api/main/user-data/install.sh | bash
  EOT

  tags = {
    Name = "CyberITEX-API-Instance"
  }
}

resource "aws_security_group" "cyberitex_sg" {
  name_prefix = "cyberitex-flask-api"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "cyberitex_instance" {
  ami           = "ami-0e2c8caa4b6378d8c" # Update with the appropriate AMI ID for your region
  instance_type = "t2.micro"     # Change as needed for your requirements
  key_name      = "your-key-name" # Replace with your key pair name

  security_groups = [
    aws_security_group.cyberitex_sg.name
  ]

  tags = {
    Name = "CyberITEX-API"
  }
}

output "instance_ip" {
  value = aws_instance.cyberitex_flask_api.public_ip
}
