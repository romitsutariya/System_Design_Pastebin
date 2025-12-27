provider "aws" {
  region = "us-east-1"
}

###############################
# Core infrastructure (VPC, subnets, security groups)
###############################
module "core" {
  source = "./modules/core"
}

###############################
# Backend infrastructure
###############################
module "backend" {
  source          = "./modules/backend"
  vpc_id          = module.core.vpc_id
  subnet_a_id     = module.core.public_subnet_a_id
  subnet_b_id     = module.core.public_subnet_b_id
  allow_sg_id     = module.core.ec2_sg_id
  alb_sg_id       = module.core.alb_sg_id
  instance_type   = "t3.micro"
  public_key_path = "./keys/id_rsa.pub"
  user_data       = file("./modules/backend/user_data.sh")
}


###############################
# Lambda for SQS -> Polly -> S3
###############################

module "voice" {
  source               = "./modules/voice"
  queue_arn            = module.backend.queue_url
  function_source_path = "${path.module}/../pastebin-voice/function.py"
  bucket_prefix        = "pastebin-voice-output"
  function_name        = "pastebin-voice-worker"
  voice                = "Joanna"
  engine               = "neural"
  timeout              = 30
}


