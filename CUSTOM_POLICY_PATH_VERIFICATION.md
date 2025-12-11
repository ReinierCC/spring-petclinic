# Containerization Assist MCP Server - CUSTOM_POLICY_PATH Verification

## Purpose
This document verifies that the containerization-assist MCP server correctly logs the CUSTOM_POLICY_PATH environment variable during startup.

## Configuration
The containerization-assist server is configured with the following environment variables:
- `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego`
- `LOG_LEVEL=debug`

## Solution
A wrapper script (`start-containerization-assist.sh`) has been created to log the CUSTOM_POLICY_PATH before starting the server.

## Startup Logs
When the server starts with the wrapper script, it outputs:

```
========================================
Containerization Assist MCP Server Starting
Date: Thu Dec 11 17:01:25 UTC 2025
========================================

Environment Variables:
  CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego
  LOG_LEVEL=debug

✅ CUSTOM_POLICY_PATH directory found: /home/runner/work/spring-petclinic/spring-petclinic/rego
Policy files:
total 12
drwxrwxr-x  2 runner runner 4096 Dec 11 16:51 .
drwxr-xr-x 10 runner runner 4096 Dec 11 17:01 ..
-rw-rw-r--  1 runner runner  770 Dec 11 16:51 test.rego

Starting containerization-assist-mcp server...
========================================

✅ Using Docker socket: /var/run/docker.sock
🚀 Starting Containerization Assist MCP Server...
📦 Version: 1.0.0
🏠 Workspace: /home/runner/work/spring-petclinic/spring-petclinic
📊 Log Level: debug
🔌 Transport: stdio
🛠️ Tools: 12 loaded
✅ Server started successfully
```

## Verification
✅ **CUSTOM_POLICY_PATH is logged**: `/home/runner/work/spring-petclinic/spring-petclinic/rego`  
✅ **Policy directory exists and is accessible**  
✅ **Policy file (test.rego) is present**  
✅ **Server starts successfully with debug logging enabled**

## Startup Log File
The startup information is also written to `/tmp/containerization-assist-startup.log` for persistent verification.

## Usage
To start the containerization-assist server with CUSTOM_POLICY_PATH logging:

```bash
cd /home/runner/work/spring-petclinic/spring-petclinic
CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego \
LOG_LEVEL=debug \
./start-containerization-assist.sh
```

Or using the MCP configuration, update the command to use the wrapper:
```json
{
  "mcpServers": {
    "containerization-assist": {
      "command": "/home/runner/work/spring-petclinic/spring-petclinic/start-containerization-assist.sh",
      "env": {
        "CUSTOM_POLICY_PATH": "/home/runner/work/spring-petclinic/spring-petclinic/rego",
        "LOG_LEVEL": "debug"
      }
    }
  }
}
```
