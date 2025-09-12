resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = "aws-observability"
  }

  data = {
    "output.conf" = <<EOF
[OUTPUT]
        Name cloudwatch_logs
        Match   *
        region eu-west-3
        log_group_name /aws/eks/fargate-cluster/karpenter
        log_stream_prefix karpenter-
        auto_create_group true
EOF

    "parsers.conf" = <<EOF
[PARSER]
        Name crio
        Format Regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
EOF

    "filters.conf" = <<EOF
[FILTER]
        Name parser
        Match *
        Key_name log
        Parser crio
EOF
  }

  depends_on = [
    module.eks,
  ]
}
