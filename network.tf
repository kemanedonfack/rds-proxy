data "aws_vpc" "infrastructure_vpc" {
  id = "vpc-0c7a48ffa82b8c7ae"
}

data "aws_subnet" "first_subnet" {
  id = "subnet-08cfb65242d6db186"
}
data "aws_subnet" "second_subnet" {
  id = "subnet-0c819740100e5e234"
}
