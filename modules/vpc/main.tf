resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env_name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each          = { for i, cidr in var.public_subnet_cidrs : i => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[each.key]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env_name}-public-subnet-${var.azs[each.key]}"
  }
}

resource "aws_subnet" "private_app" {
  for_each          = { for i, cidr in var.private_app_subnet_cidrs : i => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[each.key]
  tags = {
    Name = "${var.env_name}-private-app-subnet-${var.azs[each.key]}"
  }
}

resource "aws_subnet" "private_db" {
  for_each          = { for i, cidr in var.private_db_subnet_cidrs : i => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[each.key]
  tags = {
    Name = "${var.env_name}-private-db-subnet-${var.azs[each.key]}"
  }
}

resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)
  domain   = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = values(aws_subnet.public)[count.index].id
  tags = {
    Name = "${var.env_name}-nat-gateway-${var.azs[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.env_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_app_subnet_cidrs) > 0 ? length(var.azs) : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = {
    Name = "${var.env_name}-private-rt-${var.azs[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[index(var.azs, each.value.availability_zone)].id
}

resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[index(var.azs, each.value.availability_zone)].id
}


resource "aws_security_group" "alb" {
  count  = var.deploy_app_stack ? 1 : 0
  name   = "${var.env_name}-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "app" {
  count  = var.deploy_app_stack ? 1 : 0
  name   = "${var.env_name}-app-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jump_server" {
  count  = var.deploy_jump_server ? 1 : 0
  name   = "${var.env_name}-jump-server-sg"
  vpc_id = aws_vpc.main.id
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


data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_lb" "main" {
  count              = var.deploy_app_stack ? 1 : 0
  name               = "${var.env_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [for s in aws_subnet.public : s.id]
}

resource "aws_lb_target_group" "main" {
  count    = var.deploy_app_stack ? 1 : 0
  name     = "${var.env_name}-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  count             = var.deploy_app_stack ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

resource "aws_instance" "app" {
  count         = var.deploy_app_stack ? 3 : 0 
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  key_name      = var.key_name
  subnet_id     = values(aws_subnet.private_app)[count.index % 2].id
  vpc_security_group_ids = [aws_security_group.app[0].id]
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              # Your script to create the custom index.html would go here
              EOF

  tags = {
    Name = "${var.env_name}-app-server-${count.index + 1}"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.deploy_app_stack ? 3 : 0
  target_group_arn = aws_lb_target_group.main[0].arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

resource "aws_instance" "jump_server" {
  count         = var.deploy_jump_server ? 1 : 0
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  key_name      = var.key_name
  subnet_id     = values(aws_subnet.public)[0].id 
  vpc_security_group_ids = [aws_security_group.jump_server[0].id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.env_name}-jump-server"
  }
}
