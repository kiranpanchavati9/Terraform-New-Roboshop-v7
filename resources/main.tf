/*
  Project      : RobotShop Dev Environment
  Description  : Creates EC2 instances and Route53 DNS records for each microservice
                 using for_each meta-argument with dynamic length of components variable
*/

# ─────────────────────────────────────────
# EC2 Instances for each microservice
# ─────────────────────────────────────────
resource "aws_instance" "instances" {

  for_each = var.components

  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = var.vpc_sg_id
  iam_instance_profile   = var.iam_role
  key_name               = var.key_name

  tags = {
    Name        = each.key
    Environment = "dev"
    Project     = "RobotShop"
  }
}

# ─────────────────────────────────────────
# Route53 DNS Records
# ─────────────────────────────────────────
resource "aws_route53_record" "instances" {

  for_each = var.components

  zone_id = var.zone_id
  name    = "${each.key}-dev"
  type    = var.dns_type
  ttl     = var.ttl

  records = each.key == "frontend" ? [
    aws_instance.instances[each.key].public_ip
  ] : [
    aws_instance.instances[each.key].private_ip
  ]
}

# ─────────────────────────────────────────
# Post Configuration using remote-exec
# ─────────────────────────────────────────
resource "null_resource" "post-config" {

  for_each = var.components

  depends_on = [
    aws_instance.instances
  ]

  triggers = {
    instance_id = aws_instance.instances[each.key].id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/.ssh/roboshop-dev.pem")
    host        = aws_instance.instances[each.key].public_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {

    inline = [

      # Wait for cloud-init/rpm locks
      "while sudo lsof /var/lib/rpm/.rpm.lock >/dev/null 2>&1; do sleep 5; done",

      # Wait for server boot completion
      "sleep 60",

      # Install required packages
      "sudo dnf install -y python3 python3-pip git",

      # Install ansible via pip
      "sudo pip3 install ansible",

      # Create symlinks
      "sudo ln -sf /usr/local/bin/ansible /usr/bin/ansible",

      "sudo ln -sf /usr/local/bin/ansible-pull /usr/bin/ansible-pull",

      # Verify ansible
      "ansible --version",

      # Execute ansible-pull
      "ansible-pull -i localhost, -U https://github.com/kiranpanchavati9/Roboshop-Ansible-Template-New.git playbooks/${each.key}.yml -e env=dev -vvv; exit 0"
    ]
  }
}