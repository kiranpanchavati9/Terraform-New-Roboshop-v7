/*
  Project      : RobotShop Dev Environment
  Description  : Creates EC2 instances and Route53 DNS records for each microservice
                 using for_each meta-argument with dynamic length of components variable
  AMI          : Configured via var.ami
  Type         : Configured via var.instance_type
  SG           : Configured via var.vpc_sg_id
  Components   : Configured via var.components (frontend, mongodb, catalogue, redis,
                 user, cart, mysql, shipping, rabbitmq, payment)
  DNS Zone     : Configured via var.zone_id
  DNS Type     : Configured via var.dns_type
  TTL          : Configured via var.ttl
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
# Route53 DNS Records for each microservice
# ─────────────────────────────────────────
resource "aws_route53_record" "instances" {
  for_each = var.components

  zone_id = var.zone_id
  name    = "${each.key}-dev"
  type    = var.dns_type
  ttl     = var.ttl
  records = [aws_instance.instances[each.key].private_ip]
}

# ─────────────────────────────────────────
# Null Resource - SSH into each EC2 and
# install required packages
# ─────────────────────────────────────────
resource "null_resource" "yum-commands" {
  for_each = var.components

  depends_on = [aws_instance.instances]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/${var.key_name}"))
      host        = aws_instance.instances[each.key].public_ip
    }

    inline = [
      "sudo dnf install ansible -y",
      "sudo pip3 install ansible -y",
      "ansible-pull -i localhost, -U https://github.com/kiranpanchavati9/Roboshop-Ansible-Template-New.git playbooks/${each.key}.yml -e env=dev"
    ]
  }
}