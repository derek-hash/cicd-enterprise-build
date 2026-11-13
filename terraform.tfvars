student_name = "derek"
networks     = ["devops", "internal", "web"]

# Shared server: publish on loopback only and reach RDP/viewer through an
# SSH tunnel (ssh -L 3002:localhost:3002 cncs-sysadmin@192.168.3.224).
bind_ip = "127.0.0.1"

# "Enterprise Build assignment" splits host ports by range: Student A uses 3000-3012,
# Student B uses 4000-4012. Keep every external port in your range.
services = {
  "gitea" = {
    image   = "gitea/gitea"
    network = "devops"
    ports   = [{ internal = 3000, external = 3000 }]
  }
  "apache" = {
    image   = "httpd"
    network = "web"
    ports   = [{ internal = 80, external = 3001 }]
  }
}

vms = {
  "derek-win11" = {
    os          = "win11"
    rdp_port    = 3002
    viewer_port = 3003
  }
  "derek-win2025" = {
    os          = "win2025"
    rdp_port    = 3004
    viewer_port = 3005
  }
}
