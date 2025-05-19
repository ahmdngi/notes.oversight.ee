# MinIO Guide: Installation, Configuration, and Monitoring

MinIO is a high-performance, S3 compatible object storage server. It's ideal for storing unstructured data such as photos, videos, log files, backups, and container/VM images. This guide will walk you through various aspects of setting up, configuring, and monitoring MinIO on a Linux environment.


## 1. Linux Package Installation

For a direct installation on a Linux system (Debian/Ubuntu based):

**Download the MinIO Server package:**  
Choose the appropriate package for your architecture and desired version from the [MinIO downloads page](https://min.io/download#/linux).
    ``` bash
    #Download .deb package
    wget [https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20250228095516.0.0_amd64.deb](https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20250228095516.0.0_amd64.deb) -O minio.deb
    
    #Install the package
    sudo dpkg -i minio.deb

    #Create a data directory where MinIO will store its data.
    mkdir ~/minio
    
    #Launch the MinIO server
    minio server ~/minio --console-address :9001
    ```
    The server will be accessible at `http://YOUR_SERVER_IP:9000` and the console at `http://YOUR_SERVER_IP:9001`. You'll see the root user and password in the startup logs – **change these immediately for any non-testing setup!**
---

## 2. Configuring MinIO with systemd

Running MinIO as a systemd service ensures it starts on boot and can be managed like other system services.

1.  **Create a MinIO user and group (Recommended):**

    ``` bash
    sudo groupadd -r minio-user
    sudo useradd -r -g minio-user -s /sbin/nologin -d /usr/local/share/minio minio-user
    sudo chown minio-user:minio-user /usr/local/share/minio # Or your chosen data directory
    ```

2.  **Create the systemd service file:**
    The path can vary, but `/usr/lib/systemd/system/minio.service` or `/etc/systemd/system/minio.service` are common.

    File: `/usr/lib/systemd/system/minio.service` (or `/etc/systemd/system/minio.service`)

    ``` systemd
    [Unit]
    Description=MinIO
    Documentation=https://docs.min.io
    Wants=network-online.target
    After=network-online.target
    AssertFileIsExecutable=/usr/local/bin/minio

    [Service]
    Type=notify
    WorkingDirectory=/usr/local # Or the directory where your MinIO binary and data reside

    # IMPORTANT: Change User and Group if you created a dedicated one
    User=minio-user
    Group=minio-user

    # Optional: If you have a separate configuration directory
    # PermissionsStartOnly=true
    # ExecStartPre=/bin/mkdir -p /etc/minio/certs
    # ExecStartPre=/bin/chown minio-user:minio-user /etc/minio/certs

    ProtectProc=invisible
    EnvironmentFile=-/etc/default/minio
    ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
    ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

    # Let systemd restart this service always
    Restart=always
    # Specifies the maximum file descriptor number that can be opened by this process
    LimitNOFILE=1048576
    # Turn-off memory accounting by systemd, which is buggy.
    MemoryAccounting=no
    # Specifies the maximum number of threads this process can create
    TasksMax=infinity
    # Disable timeout logic and wait until process is stopped
    TimeoutSec=infinity
    # Disable killing of MinIO by the kernel's OOM killer
    OOMScoreAdjust=-1000
    SendSIGKILL=no

    [Install]
    WantedBy=multi-user.target
    # Built for ${project.name}-${project.version} (${project.name})
    ```
    *Note: Ensure `AssertFileIsExecutable` and `ExecStart` point to the correct path of your `minio` binary.*

3.  **Create the environment configuration file:**
    This file `/etc/default/minio` stores MinIO startup variables.

    File: `/etc/default/minio`

    ``` bash
    # Volume to be used for MinIO server.
    # Example: MINIO_VOLUMES="/mnt/data1 /mnt/data2 /mnt/data3 /mnt/data4"
    # For a single drive/path:
    MINIO_VOLUMES="/path/to/minio" # IMPORTANT: Ensure this path exists and has correct permissions for minio-user

    # Use if you want to run MinIO on a custom port and address.
    # Default is ":9000" for API and ":9001" for console if not specified.
    MINIO_OPTS="--address :9000 --console-address :9001"

    # Root user for the server.
    # IMPORTANT: CHANGE THESE DEFAULT CREDENTIALS FOR PRODUCTION!
    MINIO_ROOT_USER=minioadmin
    MINIO_ROOT_PASSWORD=minioadmin_strong_password_please_change

    # Set this for MinIO to reload entries with 'mc admin service restart'
    MINIO_CONFIG_ENV_FILE=/etc/default/minio

    # Optional: Specify the MinIO configuration directory
    # MINIO_CONFIG_DIR=/etc/minio
    ```
    **Security Alert:** Change `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` to strong, unique credentials. Ensure the `MINIO_VOLUMES` path exists and is writable by the `minio-user`.

4.  **Reload systemd, enable, and start the service:**

    ``` bash
    sudo systemctl daemon-reload
    sudo systemctl enable minio.service
    sudo systemctl start minio.service
    sudo systemctl status minio.service
    ```

---

## 3. MinIO Client (mc) Installation

The MinIO Client (`mc`) is a command-line tool for interacting with MinIO and S3-compatible services.
    ``` bash
    #Download the `mc` binary
    wget [https://dl.min.io/client/mc/release/linux-amd64/mc](https://dl.min.io/client/mc/release/linux-amd64/mc)
    
    #Make it executable
    chmod +x mc

    #Move it to your PATH
    sudo mv mc /usr/local/bin/mc
    ```
---

## 4. MinIO Client Admin Commands

To use `mc admin` commands, you first need to set up an alias for your MinIO server.

1.  **Set up an alias:**
    Replace `myminio` with your preferred alias name, `http://YOUR_MINIO_IP:9000` with your MinIO server's API address, and use the `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` you configured.

    ```bash
    # If running MinIO via systemd as minio-user, you might need to run mc commands as that user
    # sudo -u minio-user mc alias set myminio [http://192.168.21.1:9000](http://192.168.21.1:9000) minioadmin minioadmin_strong_password_please_change
    mc alias set myminio http://YOUR_MINIO_IP:9000 YOUR_ROOT_USER YOUR_ROOT_PASSWORD
    ```
    *(The example uses `192.168.21.1:9000` and default credentials. Update these accordingly.)*

2.  **Common admin commands:**
    (If MinIO is run by `minio-user` and `mc` needs access to its config, you might need `sudo -u minio-user mc ...`)

    * **Get server info:**
        ```bash
        mc admin info myminio
        ```
    * **Check for updates and update MinIO (if supported by your deployment):**
        ```bash
        mc admin update myminio
        ```
    * **View server logs:**
        ```bash
        mc admin logs myminio
        ```
    * **Trace API calls:**
        ```bash
        mc admin trace -a myminio
        # For specific calls, e.g., storage related
        # mc admin trace --call storage myminio
        ```
    * **Get user info:**
        ```bash
        mc admin user info myminio YOUR_USERNAME
        ```

---

## 5. Running MinIO with Docker

Docker provides a convenient way to run MinIO in an isolated environment.

* **Install Docker:** Follow the official instructions for your distribution, e.g., for Debian: [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)

### Direct Docker Run

This method is quick for testing but less manageable for production than Docker Compose [MinIO Docker Quickstart Guide](https://github.com/minio/minio/blob/master/docs/docker/README.md)  


1.  **Create a data directory on the host:**

    ```bash
    mkdir -p /path/to/minio/data
    ```

2.  **Run the MinIO container:**
    * `--user $(id -u):$(id -g)` is often used for rootless, or specify UID/GID (e.g., `1000:1000`).
    * **IMPORTANT:** Change default credentials.

    ```bash
    docker run \
       -p 9000:9000 \
       -p 9001:9001 \
       --user $(id -u):$(id -g) \
       --name minio1 \
       -e "MINIO_ROOT_USER=minioadmin" \
       -e "MINIO_ROOT_PASSWORD=minioadmin_strong_password_please_change" \
       -v /path/to/minio:/data \
       quay.io/minio/minio server /data --console-address ":9001"
    ```

### Using Docker Compose

Docker Compose is recommended for managing multi-container applications and for easier configuration management.

1.  **Create a `docker-compose.yml` file:**

    File: `docker-compose.yml`

    ```yaml
    version: '3.7' # Or a newer compatible version

    services:
      minio:
        image: quay.io/minio/minio
        container_name: minio1
        # To run as a specific user (e.g., current user or a dedicated one)
        # Ensure the user has write access to the volume mount path on the host.
        user: "1000:1000"
        ports:
          - "9000:9000"  # MinIO API port
          - "9001:9001"  # MinIO console port
        environment:
          # IMPORTANT: CHANGE THESE DEFAULT CREDENTIALS FOR PRODUCTION!
          - MINIO_ROOT_USER=minioadmin
          - MINIO_ROOT_PASSWORD=minioadmin_strong_password_please_change
          # Optional: Link to Prometheus for console monitoring (see Prometheus section)
          # - MINIO_PROMETHEUS_URL=http://prometheus:9090
        volumes:
          # Mount a host directory to /data in the container for persistent storage
          - /path/to/minio:/data # Ensure this host path exists and has correct permissions
        command: server /data --console-address ":9001"
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
          interval: 30s
          timeout: 20s
          retries: 3
        restart: always

      # Optional Prometheus service (see Prometheus section for prometheus.yml)
      # prometheus:
      #   image: prom/prometheus
      #   container_name: prometheus
      #   ports:
      #     - "9090:9090"
      #   volumes:
      #     - ./prometheus:/etc/prometheus # Mount your prometheus.yml here
      #   command:
      #     - '--config.file=/etc/prometheus/prometheus.yml'
      #   restart: always
    ```
    **Security & Permissions:**
    * Change `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`.
    * Ensure the host volume path (e.g., `/path/to/minio`) exists and that the user specified by `user:` (e.g., UID 1000) has write permissions to it. If `user:` is not set, the container runs as root, which might cause permission issues on the host volume if not managed carefully.

2.  **Run Docker Compose:**

    ```bash
    # In the directory containing docker-compose.yml
    docker-compose up -d
    ```

3.  **Update configuration and recreate container:**
    If you modify `docker-compose.yml`:

    ```bash
    docker-compose up -d # To update without recreation
    docker-compose up -d --force-recreate # To recreate a specific service:
    docker-compose up -d --force-recreate minio
    ```

### Docker Management

Common commands for managing Docker containers:

```bash
docker ps -a                 # List all containers (running and stopped)
docker logs -f minio1        # Tail logs of the 'minio1' container
docker inspect minio1        # Show detailed information about 'minio1'
docker rm minio1             # Remove the 'minio1' container (must be stopped first)
docker exec -it minio1 id    # Check the user under which the container's process is running 
```


## 6. Monitoring MinIO
As seen in the `docker-compose.yml` example, MinIO exposes health check endpoints.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
  interval: 30s
  timeout: 20s
  retries: 3
```
When this is added, docker ps will show the health status (e.g., (healthy)).

```bash
$ docker ps
CONTAINER ID   IMAGE                 COMMAND                  CREATED        STATUS                 PORTS                                             NAMES
7e204abad298   quay.io/minio/minio   "/usr/bin/docker-ent…"   10 minutes ago Up 10 minutes (healthy)   0.0.0.0:9000-9001->9000-9001/tcp, :::9000-9001->9000-9001/tcp   minio1
```

Note: MinIO does not have traditional log levels like DEBUG, INFO, WARN. You primarily rely on traces and metrics. [See GitHub Discussion #14213](https://github.com/minio/minio/discussions/14213) 

**Custom MinIO Trace Service with systemd**

This setup captures all MinIO administrative trace logs into a file, managed by a systemd service. This is useful if you're not using Docker and want persistent trace logging.

1. Create a script to run the trace command:
    Ensure the `mc` alias `myminio` is configured for the user who will run this script (e.g., root or minio-user).
    File: `/usr/local/bin/minio-trace.sh`

    ``` bash
    #!/bin/bash
    # Path to the log file
    LOG_FILE="/var/log/minio-trace.log" # Ensure this path is writable by the service user

    # Ensure mc is in PATH or provide full path
    # Ensure the alias 'myminio' is configured for the user running this script
    /usr/local/bin/mc admin trace -a --json myminio >> "$LOG_FILE" 2>&1
    ```
    Make the script executable:

    ```bash
    sudo chmod +x /usr/local/bin/minio-trace.sh
    ```    
2. Create the systemd service file:

    File: `/etc/systemd/system/minio-trace.service`

    ```
    [Unit]
    Description=MinIO Trace Logging Service
    After=network.target minio.service # Ensure MinIO service is up

    [Service]
    ExecStart=/usr/local/bin/minio-trace.sh
    Restart=always
    RestartSec=5 # Restart every 5 seconds if it fails
    User=root    # Or minio-user if that user has mc configured and permissions
    Group=root   # Or minio-user
    StandardOutput=append:/var/log/minio-trace-service.log # Service's own logs
    StandardError=append:/var/log/minio-trace-service.error.log # Service's error logs
    SyslogIdentifier=minio-trace

    [Install]
    WantedBy=multi-user.target
    ```
3. Reload systemd and start the service:

    ``` bash
    sudo systemctl daemon-reload
    sudo systemctl start minio-trace.service
    sudo systemctl enable minio-trace.service
    ```
4. Verify the service:

    ``` bash
    sudo systemctl status minio-trace.service
    tail -f /var/log/minio-trace.log
    ```
5. (Optional) Log Rotation:
    Prevent the log file from growing indefinitely using logrotate.

    File: `/etc/logrotate.d/minio-trace`
    ```       
    /var/log/minio-trace.log {
        daily
        rotate 7
        compress
        delaycompress
        missingok
        notifempty
        create 0640 root adm # Adjust user/group as needed
    }      
    ```
    **IMPORTANT:** This approach will create huge log file with a lot of unnecessary  noise.

### Prometheus Integration
MinIO exposes Prometheus-compatible metrics for detailed monitoring.

1. **Generate a bearer token for Prometheus**:
    Run this command on a machine with mc configured to access your MinIO server.

    ```bash
    mc admin prometheus generate myminio --api-version v2
    # This will output a bearer_token. Keep it secure!
    ```
    Note: There are different metrics API versions (e.g., v2, v3). Ensure consistency.

2. **Create Prometheus configuration file** (`prometheus.yml`):
    Replace `your_minio_server_ip:9000` with your MinIO server's API address and `YOUR_BEARER_TOKEN_HERE` with the token generated above.

    File: `prometheus/prometheus.yml` (e.g., in your docker-compose directory)

    ``` yaml
    global:
    scrape_interval: 15s

    rule_files:
    - /etc/prometheus/minio-alerting.rules.yml # Path inside Prometheus container

    scrape_configs:
    - job_name: 'minio-cluster'
        bearer_token: 'YOUR_BEARER_TOKEN_HERE'
        metrics_path: /minio/v2/metrics/cluster
        scheme: http # Or https if MinIO is configured with TLS
        static_configs:
        - targets: ['your_minio_server_ip:9000'] # Your MinIO server address

    - job_name: 'minio-node'
        bearer_token: 'YOUR_BEARER_TOKEN_HERE'
        metrics_path: /minio/v2/metrics/node
        scheme: http
        static_configs:
        - targets: ['your_minio_server_ip:9000']

    - job_name: 'minio-bucket'
        bearer_token: 'YOUR_BEARER_TOKEN_HERE'
        metrics_path: /minio/v2/metrics/bucket
        scheme: http
        static_configs:
        - targets: ['your_minio_server_ip:9000']
        # Optional: Add relabeling to filter specific buckets if needed
        # metric_relabel_configs:
        # - source_labels: [bucket_name]
        #   regex: 'importantbucket1|importantbucket2'
        #   action: keep

    - job_name: 'minio-resource' # Added for completeness, may not always be needed
        bearer_token: 'YOUR_BEARER_TOKEN_HERE'
        metrics_path: /minio/v2/metrics/resource
        scheme: http
        static_configs:
        - targets: ['your_minio_server_ip:9000']
    ```
3. **Add Prometheus to docker-compose.yml** (if using Docker):  
   Update your docker-compose.yml to include Prometheus. 
    ``` yaml
        version: '3.7'

        services:
        minio:
            image: quay.io/minio/minio
            container_name: minio1
            # user: "1000:1000"
            ports:
            - "9000:9000"
            - "9001:9001"
            environment:
            - MINIO_ROOT_USER=minioadmin
            - MINIO_ROOT_PASSWORD=minioadmin
            - MINIO_PROMETHEUS_URL=http://prometheus:9090 # For MinIO Console to link to Prometheus
            volumes:
            - /path/to/minio:/data
            command: server /data --console-address ":9001"
            healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
            interval: 30s
            timeout: 20s
            retries: 3
            restart: always

        prometheus:
            image: prom/prometheus:latest
            container_name: prometheus
            ports:
            - "9090:9090"
            volumes:
            - ./prometheus:/etc/prometheus          # Mount prometheus.yml and alert rules
            # - prometheus_data:/prometheus         # Optional: Persistent data for Prometheus
            command:
            - '--config.file=/etc/prometheus/prometheus.yml'
            restart: always
    ```
    Ensure your prometheus.yml and minio-alerting.rules.yml (see below) are in a directory named prometheus next to your docker-compose.yml.   
4. **Restart Docker Compose:**
    
    If you added Prometheus or updated its configuration:

    ```bash
    docker-compose up -d --force-recreate prometheus minio # Or just `docker-compose up -d`
    ```
    Access Prometheus at `http://your_docker_host_ip:9090`

### Prometheus Alerts
Create alert rules for Prometheus to notify you of issues.

1. Create an alert rules file:
Refer to [MinIO Prometheus Metrics List](https://min.io/docs/minio/linux/operations/monitoring/collect-minio-metrics-using-prometheus.html) and [Here](https://github.com/minio/minio/blob/master/docs/metrics/prometheus/list.md) for available metrics.

    File: `prometheus/minio-alerting.rules.yml`
    ``` yaml
    groups:
    - name: minio-alerts
    rules:
    - alert: MinIOTooManyNodesOffline
        expr: minio_cluster_nodes_offline_total{job="minio-cluster"} > 0 # Adjust threshold as needed
        for: 5m # Duration for which condition must be true
        labels:
        severity: critical
        annotations:
        summary: "Node offline in MinIO cluster (instance {{ $labels.instance }})"
        description: "{{ $value }} node(s) are offline in the MinIO cluster."

    - alert: MinIOTooManyDrivesOffline
        expr: minio_cluster_drive_offline_total{job="minio-cluster"} > 1 # Example: alert if more than 1 drive is offline
        for: 5m
        labels:
        severity: critical
        annotations:
        summary: "Drive offline in MinIO cluster (instance {{ $labels.instance }})"
        description: "{{ $value }} drive(s) are offline in the MinIO cluster."

    - alert: MinIOLowStorageCapacity
        expr: (minio_cluster_capacity_free_bytes{job="minio-cluster"} / minio_cluster_capacity_total_bytes{job="minio-cluster"}) * 100 < 10
        for: 15m
        labels:
        severity: warning
        annotations:
        summary: "MinIO cluster {{ $labels.instance }} low storage capacity"
        description: "Cluster {{ $labels.instance }} has less than 10% free storage capacity remaining ({{ $value | printf \"%.2f\" }}%)."

    # Add more alerts as needed, e.g., for certificate expiry, bucket usage, etc.
    ```
2. Ensure `prometheus.yml` points to this rules file:  
   This was done in the prometheus.yml example: `rule_files: - /etc/prometheus/minio-alerting.rules.yml`

You'll need to configure Alertmanager separately if you want Prometheus to send notifications (email, Slack, etc.).


### Debugging MinIO  
* Official Debugging Guide: [MinIO Debugging Documentation](https://github.com/minio/minio/blob/master/docs/debugging/README.md)
* Blog Post on Debugging:  [Debugging MinIO Installs](https://blog.min.io/debugging-minio-installs/)

Common tools include:   
* mc admin trace  
* mc admin logs  
* Server logs (if configured for systemd or viewed via docker logs)  
* Prometheus metrics  
  
## Important Notes
**MinIO Object Locking**  
MinIO supports S3 Object Locking (Object Retention), which enforces Write-Once Read-Many (WORM) policies. This is crucial for compliance and data protection.

[MinIO Object Locking Documentation](https://min.io/docs/minio/linux/administration/object-management/object-retention.html#minio-object-locking-legalhold)  

**Global `mc` Options**  
All `mc` commands support global options like `--config-dir`, `--quiet`, `--json`, etc. Some can also be set via environment variables.

[MinIO mc Reference - Global Options](https://min.io/docs/minio/linux/reference/minio-mc.html#global-options)
