#----------------------------------------------------------
# IaC for first Deploy of Flask App stored on GitHub
# Provision Highly Available Web in any Region Default VPC
# Create:
#       - Security Group for Web Server 
#       - Launch Configuration with  Ubuntu Auto AMI Lookup (Min=2, Desire=2, Max=4)
#       - Auto Scaling Group using 3 Availability Zones
#       - Classic Load Balancer in 3 Availability Zones
# Made by Mykhaylo V
#----------------------------------------------------------

provider "aws" {
  region = var.region 
}

# Get data of Default AWS Availability Zones
data "aws_availability_zones" "available" {}

# Get latest Ubuntu 22.04
data "aws_ami" "latest_ubuntu" {
    owners = [ "099720109477" ]
    most_recent = true
    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}

resource "aws_default_vpc" "default" {} # This need to get VPC id

resource "aws_security_group" "web" {
  name        = "Web-Security-Group"
  vpc_id = aws_default_vpc.default.id # This need to set VPC id

  dynamic "ingress" {
    for_each = var.allow_ports #see variables.tf
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] #Set your IP #This need due to Security
    #ipv6_cidr_blocks = ["::/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Dynamic Security Group"
  }
}

resource "aws_launch_configuration" "web" {
  name_prefix   = "WebServer-Highly-Available-LC-"
  image_id      = data.aws_ami.latest_ubuntu.id
  instance_type = "t2.micro"
  security_groups = [ aws_security_group.web.id ]
  user_data = file("user_data.sh")
  associate_public_ip_address = true
  key_name = "Test-Ubuntu-Flask"

  lifecycle {
    create_before_destroy = true #for Blue/Green Deployment
  }
}

resource "aws_autoscaling_group" "web" {
  name = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size = 2
  max_size = 4  # Number of Servers
  desired_capacity = 2
  min_elb_capacity = 2 #Wait for 2 in ELB
  vpc_zone_identifier = [ aws_default_subnet.default_az1.id, 
                          aws_default_subnet.default_az2.id, 
                          aws_default_subnet.default_az3.id ] # From resource "aws_default_subnet"
  health_check_type = "ELB"
  load_balancers = [ aws_elb.web.name ] # From resource "aws_elb" "web"

  dynamic "tag" {
    for_each = {
      Name = "WebServer-in-ASG"
      Owner = "Mykhaylo"
      TAGKEY = "TAGVALUE"
    }
    content {
        key = tag.key
        value = tag.value
        propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "web" {
  name = "Web-HA-ELB"
  availability_zones = [ data.aws_availability_zones.available.names[1],
                         data.aws_availability_zones.available.names[2],
                         data.aws_availability_zones.available.names[3] ]
  security_groups = [ aws_security_group.web.id ]

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = 80
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 4
    timeout = 3
    target = "HTTP:80/"
    interval = 20   # seconds
  }

  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[2]
}

# only if your Region has more than 2 AZs
resource "aws_default_subnet" "default_az3" {
  availability_zone = data.aws_availability_zones.available.names[3]  
}
