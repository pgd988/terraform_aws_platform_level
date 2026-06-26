data "aws_ssm_parameter" "default_tg_arn" {
  name = "/platform/alb/default_tg_arn"
}

# Deploy NGINX default backend via Helm with TargetGroupBinding
resource "helm_release" "default_nginx" {
  name       = "default-nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "default"
  version    = "18.1.5" 

  values = [
    <<EOF
service:
  type: ClusterIP
  ports:
    http: 80

containerPorts:
  http: 8080

# Single default server returning 403 on root
serverBlock: |-
  server {
    listen 8080 default_server;
    server_name _;
    
    location / {
      return 403 "Forbidden\n";
    }
  }

# Bind ALB IP Target Group directly to NGINX Service
extraManifests:
  - apiVersion: elbv2.k8s.aws/v1beta1
    kind: TargetGroupBinding
    metadata:
      name: default-nginx-tgb
      namespace: default
    spec:
      serviceRef:
        name: default-nginx
        port: 80
      targetGroupARN: ${data.aws_ssm_parameter.default_tg_arn.value}
EOF
  ]
}
