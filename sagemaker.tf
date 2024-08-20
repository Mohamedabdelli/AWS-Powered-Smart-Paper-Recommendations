

# Définition du rôle IAM pour SageMaker
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "sagemaker_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_execution_policy_attachment" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Définition du modèle SageMaker Hugging Face
resource "aws_sagemaker_model" "huggingface_model" {
  name                = "huggingface-sentence-transformer"
  execution_role_arn  = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image = "683313688378.dkr.ecr.us-east-1.amazonaws.com/tei:2.0.1-tei1.2.3-gpu-py310-cu122-ubuntu22.04"

    environment = {
      HF_MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
    }
  }
}

# Configuration de l'endpoint SageMaker
resource "aws_sagemaker_endpoint_configuration" "hf_endpoint_config" {
  name = "huggingface-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.huggingface_model.name
    initial_instance_count = 1
    instance_type          = "ml.g5.2xlarge"
    

  }
}

# Création de l'endpoint SageMaker
resource "aws_sagemaker_endpoint" "hf_endpoint" {
  name         = var.SageMaker_endpoind_name
  endpoint_config_name  = aws_sagemaker_endpoint_configuration.hf_endpoint_config.name
}

# Configuration de la cible d'auto-scaling
resource "aws_appautoscaling_target" "sagemaker_autoscaling_target" {
  max_capacity       = 2  # Nombre maximal d'instances
  min_capacity       = 1  # Nombre minimal d'instances
  resource_id        = "endpoint/${aws_sagemaker_endpoint.hf_endpoint.name}/variant/AllTraffic"
  scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
  service_namespace  = "sagemaker"
}

# Politique d'auto-scaling - scale up
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "sagemaker-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sagemaker_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.sagemaker_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.sagemaker_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0  # Pourcentage d'utilisation cible

    predefined_metric_specification {
      predefined_metric_type = "SageMakerVariantInvocationsPerInstance"
    }

    scale_in_cooldown  = 300  # Période de refroidissement pour réduire l'échelle
    scale_out_cooldown = 300  # Période de refroidissement pour augmenter l'échelle
  }
}



# Output pour obtenir le nom de l'endpoint
output "endpoint_name" {
  value = aws_sagemaker_endpoint.hf_endpoint.name
}
