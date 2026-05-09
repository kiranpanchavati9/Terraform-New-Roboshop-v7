# Terraform Null Resource

## What is Null Resource?
A resource that **does not create any real infrastructure**.
It is used to **run scripts/commands** as part of Terraform apply.

> Think of it as — "Don't build anything, just run this command for me."

---

## Example

```hcl
resource "null_resource" "yum-commands" {
  depends_on = [aws_instance.instances]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/${var.key_name}"))
      host        = aws_instance.instances[each.key].public_ip
    }
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl start nginx",
    ]
  }
}
```

---

## Null Resource vs Provisioner Inside `aws_instance`

| Feature | Inside `aws_instance` | `null_resource` |
|---|---|---|
| **If script fails** | EC2 is **destroyed** ❌ | EC2 stays safe ✅ |
| **Re-run script** | Must destroy EC2 | Just taint null_resource |
| **Separation** | Mixed together | Clean separation |
| **Risk** | High | Low |