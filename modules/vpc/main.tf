resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
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
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.env_name}-private-app-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.env_name}-private-db-subnet-${count.index + 1}"
  }
}


resource "aws_eip" "nat" {
  count  = length(var.private_app_subnet_cidrs) > 0 ? length(var.public_subnet_cidrs) : 0
  domain = "vpc"
  tags = {
    Name = "${var.env_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.private_app_subnet_cidrs) > 0 ? length(var.public_subnet_cidrs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.env_name}-nat-gateway-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

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
  count = length(var.private_app_subnet_cidrs) > 0 ? length(var.public_subnet_cidrs) : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.env_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private_app" {
  count          = length(var.private_app_subnet_cidrs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "private_db" {
  count          = length(var.private_db_subnet_cidrs)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

resource "aws_security_group" "jump_server" {
  count = var.deploy_jump_server ? 1 : 0

  name        = "${var.env_name}-jump-server-sg"
  description = "Allow SSH traffic to the jump server"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name = "${var.env_name}-jump-server-sg"
  }
}

resource "aws_instance" "jump_server" {
  count = var.deploy_jump_server ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id 
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jump_server[0].id]

  tags = {
    Name = "${var.env_name}-jump-server"
  }
}

resource "aws_eip" "jump_server" {
  count    = var.deploy_jump_server ? 1 : 0
  instance = aws_instance.jump_server[0].id
  domain   = "vpc" 
}


resource "aws_security_group" "alb" {
  count = var.deploy_app_stack ? 1 : 0

  name        = "${var.env_name}-alb-sg"
  description = "Allow HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name = "${var.env_name}-alb-sg"
  }
}

resource "aws_security_group" "app_server" {
  count = var.deploy_app_stack ? 1 : 0

  name        = "${var.env_name}-app-server-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_name}-app-server-sg"
  }
}

resource "aws_instance" "app_server" {
  count = var.deploy_app_stack ? 3 : 0 

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_app[count.index % length(var.private_app_subnet_cidrs)].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_server[0].id]

  tags = {
    Name = "${var.env_name}-app-server-${count.index + 1}"
  }
}

resource "aws_lb" "main" {
  count = var.deploy_app_stack ? 1 : 0

  name               = "${var.env_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.env_name}-alb"
  }
}

resource "aws_lb_target_group" "main" {
  count = var.deploy_app_stack ? 1 : 0

  name     = "${var.env_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group_attachment" "main" {
  count = var.deploy_app_stack ? 3 : 0 

  target_group_arn = aws_lb_target_group.main[0].arn
  target_id        = aws_instance.app_server[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  count = var.deploy_app_stack ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}