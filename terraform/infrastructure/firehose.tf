
module "firehose__processor" {
  source             = "./modules/firehose"
  prefix             = local.prefix
  region             = local.region
  layers             = [module.lambda-utils.layer_arn, module.nrlf.layer_arn, module.third_party.layer_arn]
  environment        = local.environment
  cloudwatch_kms_arn = module.kms__cloudwatch.kms_arn
}
