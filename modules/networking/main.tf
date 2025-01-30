data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.ecs_cluster_name}-vpc"
  }
}

resource "aws_subnet" "private" {
    count = var.enable_private_networking ? var.private_subnet_count : 0
    vpc_id = aws_vpc.main.id
    cidr_block = cidrsubnet(var.cidr_block, 8, count.index)
    availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

    tags = {
        Name = "${var.ecs_cluster_name}-private-${count.index + 1}"
    }
}

resource "aws_subnet" "public" {
    count = var.public_subnet_count
    vpc_id = aws_vpc.main.id 
    cidr_block = cidrsubnet(var.cidr_block, 8, count.index + var.private_subnet_count)
    availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

    tags = {
        Name = "${var.ecs_cluster_name}-public-${count.index + 1}"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "${var.ecs_cluster_name}-igw
    }
}

resource "aws_eip" "main" {
    count = var.enable_private_networking ? 1 : 0
    domain = "vpc"

    tags = {
        Name = "${var.ecs_cluster_name}-eip-${count.index + 1}
    }

    depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
    count = var.enable_private_networking ? 1 : 0
    allocation_id = aws_eip.main[count.index].id
    subnet_id = aws_subnet.private[count.index].id

    tags = {
        Name = "${var.ecs_cluster_name}-nat-${count.index + 1}"
    }

    depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id                = aws_vpc.main.id

  route {
    cidr_block          = "0.0.0.0/0"
    gateway_id          = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.ecs_cluster_name}-public"
  }
}

#create private route table
resource "aws_route_table" "private" {
  count  = var.enable_private_networking ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = { 
    Name = "${var.ecs_cluster_name}-private" 
  }
}


#create route table association for public route table
resource "aws_route_table_association" "public" {
  count = var.public_subnet_count
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#create route table association for private route table
resource "aws_route_table_association" "private" {
  count          = var.enable_private_networking ? var.private_subnet_count : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_security_group" "main" {
  name_prefix = "default-"
  description = "Default security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "main" {
  vpc_id             = aws_vpc.main.id
  service_name       = var.mongodb_endpoint_service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private[*].id]
  security_group_ids = [aws_security_group.main.id]
}