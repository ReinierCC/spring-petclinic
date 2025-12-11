# Azure Deployment Checklist

Use this checklist to ensure a successful deployment to Azure.

## Pre-Deployment

### ☐ Prerequisites Installed

- [ ] **Azure CLI** installed and working
  ```bash
  az --version
  ```
  Install: https://docs.microsoft.com/cli/azure/install-azure-cli

- [ ] **Azure Developer CLI (azd)** installed and working
  ```bash
  azd version
  ```
  Install: https://aka.ms/azd-install

- [ ] **Docker** installed (for local testing)
  ```bash
  docker --version
  ```
  Install: https://docs.docker.com/get-docker/

- [ ] **Java 17+** installed (for local development)
  ```bash
  java -version
  ```

### ☐ Azure Account Setup

- [ ] Have an active Azure subscription
- [ ] Verified subscription ID
  ```bash
  az account list -o table
  az account show --query id -o tsv
  ```

- [ ] Sufficient permissions (Contributor or Owner role)
  ```bash
  az role assignment list --assignee <your-email> -o table
  ```

### ☐ Cost Awareness

- [ ] Reviewed estimated costs (~$20-50/month)
- [ ] Understand the pricing model for each service
- [ ] Set up budget alerts (optional but recommended)

## Environment Configuration

### ☐ Authentication

- [ ] Logged into Azure CLI
  ```bash
  az login
  ```

- [ ] Logged into Azure Developer CLI
  ```bash
  azd auth login
  ```

- [ ] Verified authentication
  ```bash
  az account show
  ```

### ☐ Environment Variables

- [ ] Created `.env` file from `.env.example`
  ```bash
  cp .env.example .env
  ```

- [ ] Set `AZURE_SUBSCRIPTION_ID`
- [ ] Set `AZURE_ENV_NAME` (e.g., petclinic-prod)
- [ ] Set `AZURE_LOCATION` (e.g., eastus)
- [ ] Generated secure `POSTGRES_ADMIN_PASSWORD`

### ☐ Environment Creation

- [ ] Created azd environment
  ```bash
  azd env new <your-env-name>
  ```

- [ ] Set environment variables in azd
  ```bash
  azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
  azd env set AZURE_LOCATION <region>
  azd env set POSTGRES_ADMIN_PASSWORD <password>
  ```

## Deployment

### ☐ Initial Deployment

- [ ] Validated Bicep templates (optional)
  ```bash
  ./scripts/validate-bicep.sh
  ```

- [ ] Performed dry-run deployment
  ```bash
  azd provision --preview
  ```

- [ ] Reviewed resources to be created
- [ ] Executed full deployment
  ```bash
  azd up
  ```

- [ ] Deployment completed successfully
- [ ] Noted the application URL from output

### ☐ Deployment Verification

- [ ] Application URL is accessible
- [ ] Application loads without errors
- [ ] Can navigate through the application
- [ ] Database connection is working
- [ ] Can create/view/update/delete pet owners
- [ ] Can create/view/update/delete pets
- [ ] Can create/view visits

## Post-Deployment

### ☐ Monitoring Setup

- [ ] Accessed Application Insights in Azure Portal
- [ ] Verified logs are being collected
  ```bash
  azd monitor --logs
  ```

- [ ] Checked application health endpoint
  ```bash
  curl https://<your-app-url>/actuator/health
  ```

- [ ] Set up alerts for errors (optional)
- [ ] Configured dashboard in Azure Portal (optional)

### ☐ Security Review

- [ ] Verified Managed Identity is working
- [ ] Checked Key Vault contains secrets
- [ ] Confirmed database uses SSL/TLS
- [ ] Reviewed firewall rules
- [ ] Ensured container runs as non-root user

### ☐ Performance & Scaling

- [ ] Verified auto-scaling configuration
- [ ] Checked resource utilization
- [ ] Tested application under load (optional)
- [ ] Adjusted scaling rules if needed

## CI/CD Setup (Optional)

### ☐ GitHub Actions

- [ ] Created Azure service principal
  ```bash
  az ad sp create-for-rbac --name "github-petclinic" \
    --role contributor \
    --scopes /subscriptions/<subscription-id> \
    --sdk-auth
  ```

- [ ] Added GitHub Secrets:
  - [ ] `AZURE_CLIENT_ID`
  - [ ] `AZURE_TENANT_ID`
  - [ ] `AZURE_SUBSCRIPTION_ID`
  - [ ] `POSTGRES_ADMIN_PASSWORD`

- [ ] Added GitHub Variables:
  - [ ] `AZURE_ENV_NAME`
  - [ ] `AZURE_LOCATION`

- [ ] Tested workflow by pushing to main branch
- [ ] Verified successful deployment via GitHub Actions

## Documentation

### ☐ Project Documentation

- [ ] Updated team wiki/docs with deployment URL
- [ ] Documented environment variables
- [ ] Recorded database credentials location
- [ ] Created runbook for common operations
- [ ] Documented rollback procedure

## Maintenance

### ☐ Regular Tasks

- [ ] Schedule regular backups (PostgreSQL)
- [ ] Set up cost monitoring alerts
- [ ] Plan for security updates
- [ ] Review and rotate secrets quarterly
- [ ] Monitor application performance metrics
- [ ] Keep infrastructure code in source control

## Troubleshooting Checklist

If deployment fails, check:

- [ ] Subscription has enough quota
  ```bash
  az vm list-usage --location <region> -o table
  ```

- [ ] Resource names are unique globally
- [ ] No conflicting resources in subscription
- [ ] Network connectivity is working
- [ ] Bicep templates compile without errors
- [ ] Environment variables are set correctly
- [ ] Authentication is working
- [ ] Reviewed deployment logs
  ```bash
  azd monitor --logs
  az monitor activity-log list -g <resource-group>
  ```

## Cleanup Checklist

When decommissioning:

- [ ] Backed up any necessary data
- [ ] Exported PostgreSQL database
  ```bash
  az postgres flexible-server db show-connection-string
  pg_dump ... > backup.sql
  ```

- [ ] Documented any learnings
- [ ] Deleted the environment
  ```bash
  azd down --force --purge
  ```

- [ ] Verified all resources are deleted
  ```bash
  az group list -o table
  ```

- [ ] Removed local environment files
  ```bash
  rm -rf .azure/<env-name>
  ```

## Additional Resources

- [ ] Bookmarked [Azure Portal](https://portal.azure.com)
- [ ] Joined [Azure Community](https://techcommunity.microsoft.com/azure)
- [ ] Read [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [ ] Reviewed [Spring on Azure documentation](https://learn.microsoft.com/azure/developer/java/spring/)

---

**Completion Date**: _________________

**Deployed By**: _________________

**Environment Name**: _________________

**Application URL**: _________________

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
