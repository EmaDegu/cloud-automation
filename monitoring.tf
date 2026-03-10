#resource "aws_instance" "prometheus" {
# ami             = data.aws_ami.al2.id
#instance_type   = var.instance_type_monitor
# subnet_id       = aws_subnet.private_a.id
# security_groups = [aws_security_group.sg_monitoring.id]
# tags            = { Name = "prometheus" }
#}

#resource "aws_instance" "grafana" {
# ami             = data.aws_ami.al2.id
# instance_type   = var.instance_type_monitor
# subnet_id       = aws_subnet.private_b.id
# security_groups = [aws_security_group.sg_monitoring.id]
# tags            = { Name = "grafana" }
#}

#resource "aws_instance" "loki" {
# ami             = data.aws_ami.al2.id
# instance_type   = var.instance_type_monitor
# subnet_id       = aws_subnet.private_b.id
# security_groups = [aws_security_group.sg_monitoring.id]
# tags            = { Name = "loki" }
#}


#monitoring soar alerts in cloudwatch
resource "aws_cloudwatch_dashboard" "soar_dashboard" {
  dashboard_name = "SOAR-Monitoring"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/Lambda", "Invocations", "FunctionName", "${aws_lambda_function.soar_action.function_name}" ],
          [ ".", "Errors", ".", "." ]
        ],
        "region": "eu-central-1",
        "title": "SOAR Lambda Metrics"
      }
    }
  ]
}
EOF
}




##################################
# MONITORING (Prometheus + Grafana + Loki + Promtail + Alertmanager)
# + node_exporter + cloudwatch_exporter + EC2 SD + Grafana provisioning
##################################

# --- IAM so Prometheus EC2 SD & CloudWatch exporter can read AWS ---
data "aws_iam_policy_document" "monitor_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "monitor_role" {
  name               = "monitor-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.monitor_trust.json
}

# EC2 Describe for ec2_sd_configs, CW read for cloudwatch_exporter
data "aws_iam_policy_document" "monitor_policy" {
  statement {
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }
  statement {
    actions   = ["cloudwatch:GetMetricData", "cloudwatch:ListMetrics", "cloudwatch:GetMetricStatistics"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "monitor_policy" {
  name   = "monitor-ec2-cw-read"
  policy = data.aws_iam_policy_document.monitor_policy.json
}

resource "aws_iam_role_policy_attachment" "monitor_attach" {
  role       = aws_iam_role.monitor_role.name
  policy_arn = aws_iam_policy.monitor_policy.arn
}

resource "aws_iam_instance_profile" "monitor_profile" {
  name = "monitor-instance-profile"
  role = aws_iam_role.monitor_role.name
}

# --- EC2 host (private) running everything with Docker Compose ---
resource "aws_instance" "monitor" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_monitor
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.sg_monitoring.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.monitor_profile.name
  user_data_replace_on_change = true

  # OPTIONAL: persistent volume for Loki/Grafana (uncomment to add an extra EBS)
  # ebs_block_device {
  #   device_name = "/dev/xvdb"
  #   volume_size = 50
  #   volume_type = "gp3"
  #   encrypted   = true
  # }

  user_data = <<-EOT
    #!/bin/bash
    set -eux

    #--- OS & Docker ---
    yum update -y
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker

    # Docker Compose (standalone)
    curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    # If you attached an extra EBS volume, format & mount (uncomment if used)
    # mkfs -t xfs /dev/xvdb
    # mkdir -p /opt/monitor
    # echo '/dev/xvdb /opt/monitor xfs defaults,nofail 0 2' >> /etc/fstab
    # mount -a

    #--- Layout ---
    mkdir -p /opt/monitor/prometheus/rules
    mkdir -p /opt/monitor/grafana/provisioning/datasources
    mkdir -p /opt/monitor/grafana/provisioning/dashboards
    mkdir -p /opt/monitor/grafana/dashboards
    mkdir -p /opt/monitor/loki/chunks /opt/monitor/loki/rules
    mkdir -p /opt/monitor/promtail
    mkdir -p /opt/monitor/alertmanager
    mkdir -p /opt/monitor/cloudwatch_exporter

    # IDs & region for templating
    REGION="$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | awk -F\" '/region/{print $4}')"

    #--- docker-compose ---
    cat > /opt/monitor/docker-compose.yml <<'COMPOSE'
    version: "3.8"
    services:
      prometheus:
        image: prom/prometheus:latest
        container_name: prometheus
        environment:
          - AWS_SDK_LOAD_CONFIG=1
          - AWS_REGION='eu-central-1'
        volumes:
          - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - ./prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
        ports:
          - "9090:9090"
        restart: unless-stopped

      alertmanager:
        image: prom/alertmanager:latest
        container_name: alertmanager
        volumes:
          - ./alertmanager/config.yml:/etc/alertmanager/config.yml:ro
        ports:
          - "9093:9093"
        restart: unless-stopped

      grafana:
        image: grafana/grafana:latest
        container_name: grafana
        environment:
          - GF_SECURITY_ADMIN_USER=admin
          - GF_SECURITY_ADMIN_PASSWORD=admin
          - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
        volumes:
          - ./grafana:/var/lib/grafana
          - ./grafana/provisioning:/etc/grafana/provisioning
          - ./grafana/dashboards:/var/lib/grafana/dashboards
        ports:
          - "3000:3000"
        depends_on:
          - prometheus
          - loki
        restart: unless-stopped

      loki:
        image: grafana/loki:2.9.8
        container_name: loki
        command: -config.file=/etc/loki/config/loki-config.yml
        volumes:
          - ./loki/loki-config.yml:/etc/loki/config/loki-config.yml:ro
          - ./loki:/loki
        ports:
          - "3100:3100"
        restart: unless-stopped

      promtail:
        image: grafana/promtail:2.9.8
        container_name: promtail
        command: -config.file=/etc/promtail/config.yml
        volumes:
          - /var/log:/var/log:ro
          - ./promtail/config.yml:/etc/promtail/config.yml:ro
        depends_on:
          - loki
        restart: unless-stopped

      # Local node metrics (for this EC2)
      node_exporter:
        image: prom/node-exporter:latest
        container_name: node_exporter
        pid: "host"
        network_mode: "host"
        command:
          - '--path.rootfs=/host'
        volumes:
          - /:/host:ro,rslave
        restart: unless-stopped

      # Optional: CloudWatch metrics → Prometheus
      cloudwatch_exporter:
        image: prom/cloudwatch-exporter:latest
        container_name: cloudwatch_exporter
        environment:
          - AWS_SDK_LOAD_CONFIG=1
          - AWS_REGION='eu-central-1'
        volumes:
          - ./cloudwatch_exporter/config.yml:/config/config.yml:ro
        command: ["--config.file=/config/config.yml"]
        ports:
          - "9106:9106"
        restart: unless-stopped
    COMPOSE

    #--- Prometheus config (EC2 SD + local exporters) ---
    cat > /opt/monitor/prometheus/prometheus.yml <<'PROM'
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files:
      - /etc/prometheus/alerts.yml

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['alertmanager:9093']

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'node_exporter-local'
        static_configs:
          - targets: ['localhost:9100']

      # Discover EC2 instances that have tag Monitoring=Enabled and scrape node_exporter on 9100
      - job_name: 'node_exporter-ec2'
        ec2_sd_configs:
          - region: eu-central-1
            port: 9100
        relabel_configs:
          - source_labels: [__meta_ec2_tag_Monitoring]
            regex: Enabled
            action: keep
          - source_labels: [__meta_ec2_private_ip]
            target_label: instance_ip
          - source_labels: [__meta_ec2_tag_Name]
            target_label: instance

      - job_name: 'loki'
        static_configs:
          - targets: ['loki:3100']

      - job_name: 'promtail'
        metrics_path: /metrics
        static_configs:
          - targets: ['promtail:9080']

      # Optional CloudWatch exporter
      - job_name: 'cloudwatch_exporter'
        static_configs:
          - targets: ['cloudwatch_exporter:9106']
    PROM

    #--- Prometheus alert rules ---
    cat > /opt/monitor/prometheus/alerts.yml <<'ALERTS'
    groups:
    - name: system.rules
      rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels: { severity: critical }
        annotations:
          summary: "Instance down ({{ $labels.instance }})"
          description: "Instance {{ $labels.instance }} is down."

      - alert: HighCPU
        expr: 100 - (avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels: { severity: warning }
        annotations:
          summary: "CPU > 80% on {{ $labels.instance }}"
          description: "CPU usage high on {{ $labels.instance }}"

      - alert: HighMem
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 2m
        labels: { severity: warning }
        annotations:
          summary: "Memory > 80% on {{ $labels.instance }}"
          description: "Memory usage high on {{ $labels.instance }}"

      - alert: PromtailDown
        expr: up{job="promtail"} == 0
        for: 2m
        labels: { severity: critical }
        annotations:
          summary: "Promtail down"
          description: "Promtail appears to be down"
    ALERTS

    # Alertmanager config 
    cat > /opt/monitor/alertmanager/config.yml <<'AM'
    global:
      resolve_timeout: 5m
    route:
      receiver: 'oncall'
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h
    receivers:
    - name: 'oncall'
      email_configs:
        - to: 'e.degutyte@student.fontys.nl'
          from: 'alertmanager@example.com'
          smarthost: 'smtp.gmail.com:587'
          auth_username: 'alertmanagere'
          auth_password: 'REPLACE_ME'
          require_tls: true
    AM

    #--- Loki config (filesystem) ---
    cat > /opt/monitor/loki/loki-config.yml <<'LOKI'
    auth_enabled: false
    server:
      http_listen_port: 3100
    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory
    schema_config:
      configs:
      - from: 2020-10-15
        store: boltdb-shipper
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 24h
    limits_config:
      retention_period: 168h   # 7 days; tune for your disk
    LOKI

    #--- Promtail config ---
    cat > /opt/monitor/promtail/config.yml <<'PT'
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    clients:
      - url: http://loki:3100/loki/api/cs1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
      - job_name: system
        static_configs:
          - targets: [localhost]
            labels:
              job: varlogs
              __path__: /var/log/*.log
    PT

    #--- CloudWatch exporter config (pick namespaces you care about) ---
    cat > /opt/monitor/cloudwatch_exporter/config.yml <<'CWE'
    region: eu-central-1
    metrics:
      - aws_namespace: AWS/EC2
        aws_metric_name: CPUUtilization
        aws_dimensions: [InstanceId]
        aws_statistics: [Average, Maximum]
        period_seconds: 300
        range_seconds: 600
      - aws_namespace: AWS/ApplicationELB
        aws_metric_name: TargetResponseTime
        aws_dimensions: [LoadBalancer, TargetGroup]
        aws_statistics: [Average, p90, Maximum]
        period_seconds: 300
        range_seconds: 600
    CWE

    #--- Grafana provisioning: data sources for Prometheus & Loki ---
    cat > /opt/monitor/grafana/provisioning/datasources/datasources.yml <<'DS'
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
    DS

    # Permissions for Grafana (UID 472) and Loki (UID 10001)
    chown -R 472:472 /opt/monitor/grafana
    chmod -R 755 /opt/monitor/grafana
    chown -R 10001:10001 /opt/monitor/loki
    chmod -R 755 /opt/monitor/loki

    # Start stack
    cd /opt/monitor
    export REGION="$REGION"
    docker-compose up -d
  EOT

}
