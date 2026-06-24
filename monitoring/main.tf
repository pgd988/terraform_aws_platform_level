resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "Platform-Services-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Platform Services Monitoring\nDefault dashboard template."
        }
      }
    ]
  })
}
