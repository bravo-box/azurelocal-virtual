# Architecture Overview - Azure Local Virtual

This document provides an architectural overview of the Azure Local Virtual solution accelerator for Azure Government.

## Solution Overview

Azure Local Virtual is an Infrastructure as Code (IaC) solution that automates the deployment of a virtualized Azure Local instance in Azure Government Cloud. It creates a sandbox environment for testing, developing, and demonstrating Azure Local and Azure Arc capabilities without requiring physical hardware.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Government Cloud                     │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Resource Group                          │    │
│  │                                                      │    │
│  │  ┌────────────────────────────────────────────┐    │    │
│  │  │         Virtual Network                     │    │    │
│  │  │  ┌──────────────┐   ┌──────────────┐      │    │    │
│  │  │  │    Subnet    │   │   Bastion    │      │    │    │
│  │  │  │  (VM Host)   │   │   Subnet     │      │    │    │
│  │  │  └──────────────┘   └──────────────┘      │    │    │
│  │  └────────────────────────────────────────────┘    │    │
│  │                                                      │    │
│  │  ┌────────────────────────────────────────────┐    │    │
│  │  │       LocalBox Host VM                     │    │    │
│  │  │  (Windows Server 2022 Datacenter AE)       │    │    │
│  │  │                                             │    │    │
│  │  │  ┌───────────────────────────────────┐    │    │    │
│  │  │  │      Hyper-V (Nested VMs)         │    │    │    │
│  │  │  │  ┌──────┐  ┌──────┐  ┌──────┐    │    │    │    │
│  │  │  │  │ Node │  │ Node │  │  DC  │    │    │    │    │
│  │  │  │  │  1   │  │  2   │  │      │    │    │    │    │
│  │  │  │  └──────┘  └──────┘  └──────┘    │    │    │    │
│  │  │  │     Azure Local Cluster           │    │    │    │
│  │  │  └───────────────────────────────────┘    │    │    │
│  │  └────────────────────────────────────────────┘    │    │
│  │                                                      │    │
│  │  ┌────────────────┐  ┌──────────────────┐         │    │
│  │  │   Azure        │  │    Storage       │         │    │
│  │  │   Bastion      │  │    Account       │         │    │
│  │  └────────────────┘  └──────────────────┘         │    │
│  │                                                      │    │
│  │  ┌──────────────────────────────────────┐          │    │
│  │  │   Log Analytics Workspace            │          │    │
│  │  │   - VM Insights                      │          │    │
│  │  │   - Security Center                  │          │    │
│  │  │   - Update Management                │          │    │
│  │  └──────────────────────────────────────┘          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Azure Arc Services                      │    │
│  │  - Connected Machines                                │    │
│  │  - Azure Local Registration                         │    │
│  │  - Policy & Governance                               │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Host Virtual Machine

**Purpose**: Primary compute resource that hosts the nested Hyper-V environment.

**Specifications**:
- **OS**: Windows Server 2022 Datacenter Azure Edition
- **Size**: Standard_E32s_v5 (recommended)
  - 32 vCPUs
  - 256 GB RAM
  - Nested virtualization enabled
- **Storage**:
  - OS Disk: 256 GB Premium SSD
  - Data Disk: 1 TB Premium SSD (for nested VMs)
- **Networking**: Accelerated networking enabled

**Roles**:
- Hyper-V host for nested cluster VMs
- Management endpoint for the cluster
- Azure Arc connection point

### 2. Networking Components

#### Virtual Network
- **Address Space**: 10.0.0.0/16 (configurable)
- **Subnet for VMs**: 10.0.1.0/24
- **Bastion Subnet**: 10.0.250.0/24 (optional)

#### Network Security Group
- **RDP (3389)**: Inbound access for management (should be restricted in production)
- **WinRM (5985-5986)**: Remote PowerShell management
- **HTTPS (443)**: Secure web access

#### Public IP Address
- **Type**: Static (Standard SKU)
- **DNS**: Automatic FQDN generation
- **Purpose**: External access to host VM

#### Azure Bastion (Optional)
- **Purpose**: Secure RDP access without exposing public IP
- **SKU**: Standard
- **Benefits**: No need for VPN, enhanced security

### 3. Storage Components

#### Storage Account
- **Type**: Standard_LRS
- **Purpose**: Boot diagnostics and logs
- **Encryption**: Microsoft-managed keys

#### Managed Disks
- **OS Disk**: Premium SSD for performance
- **Data Disk**: Premium SSD for nested VM storage
- **Benefits**: High IOPS and throughput for nested VMs

### 4. Monitoring & Management

#### Log Analytics Workspace
- **Purpose**: Centralized logging and monitoring
- **Solutions**:
  - VM Insights: Performance and health monitoring
  - Security Center: Security posture management
  - Update Management: Patch compliance tracking

#### Azure Monitor Agent
- **Deployment**: Automatic via VM extension
- **Data Collection**: System logs, performance metrics, security events

### 5. Azure Arc Integration

#### Connected Machine Agent
- **Purpose**: Hybrid resource management
- **Features**:
  - Policy enforcement
  - Extension management
  - RBAC integration
  - Inventory and tagging

#### Azure Local Registration
- **Endpoint**: Azure Government Arc endpoint
- **Management**: Azure portal integration
- **Benefits**: Cloud-based lifecycle management

## Nested Virtualization Architecture

### Hyper-V Layer

```
┌───────────────────────────────────────────────────┐
│            Host VM (Physical)                     │
│                                                   │
│  ┌─────────────────────────────────────────┐    │
│  │         Hyper-V Virtual Switch          │    │
│  │           (External NAT)                 │    │
│  └─────────────────────────────────────────┘    │
│           ↓           ↓           ↓              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  Node 1  │  │  Node 2  │  │    DC    │      │
│  │  (VM)    │  │  (VM)    │  │   (VM)   │      │
│  │          │  │          │  │          │      │
│  │ Hyper-V  │  │ Hyper-V  │  │   AD     │      │
│  │ Enabled  │  │ Enabled  │  │   DNS    │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│       ↓              ↓              ↓            │
│  ┌─────────────────────────────────────────┐    │
│  │      Azure Local Cluster Storage         │    │
│  │         (Storage Spaces Direct)          │    │
│  └─────────────────────────────────────────┘    │
└───────────────────────────────────────────────────┘
```

### Nested VM Configuration

**Cluster Nodes (Minimum 2)**:
- **vCPUs**: 4-8 per node
- **RAM**: 32-64 GB per node
- **Storage**: 100-500 GB per node
- **Network**: MAC spoofing enabled
- **Features**: Nested virtualization extensions exposed

**Domain Controller**:
- **vCPUs**: 2
- **RAM**: 4-8 GB
- **Storage**: 60 GB
- **Roles**: Active Directory, DNS

## Azure Government Considerations

### Endpoint Configuration

All Azure services use Government-specific endpoints:

```powershell
# Resource Manager
https://management.usgovcloudapi.net

# Azure AD Authentication
https://login.microsoftonline.us

# Azure Arc
https://gbl.his.arc.azure.us

# Storage
https://*.blob.core.usgovcloudapi.net

# Key Vault
https://*.vault.usgovcloudapi.net
```

### Compliance Integration

- **FedRAMP High**: Compliant infrastructure
- **DoD IL2-IL5**: Appropriate for DoD workloads
- **CJIS**: Criminal justice data
- **ITAR**: Export-controlled data

### Network Isolation

- All data stays within US sovereign boundaries
- Physically separate from commercial Azure
- No cross-region data replication to commercial cloud

## Deployment Flow

```
┌─────────────────┐
│  Prerequisites  │
│  - Azure CLI    │
│  - Bicep        │
│  - PowerShell   │
│  - Key Vault    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Deploy Bicep   │
│  Templates      │
│  - VNet/NSG     │
│  - Host VM      │
│  - Monitoring   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  VM Extensions  │
│  - Install      │
│    Hyper-V      │
│  - Restart      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Configure      │
│  Host           │
│  - vSwitch      │
│  - Storage      │
│  - Arc Agent    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Create Nested  │
│  VMs            │
│  - Cluster      │
│    Nodes        │
│  - Domain       │
│    Controller   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Deploy Azure   │
│  Local Cluster  │
│  - Validation   │
│  - Registration │
│  - Management   │
└─────────────────┘
```

## Security Architecture

### Authentication & Authorization

1. **Azure AD Integration**: All authentication via Azure Government AD
2. **RBAC**: Role-based access control for all resources
3. **Service Principals**: Automated deployments and Arc registration
4. **Key Vault**: Secure credential storage

### Network Security

1. **NSG Rules**: Restrict inbound/outbound traffic
2. **Azure Bastion**: Secure RDP without public exposure
3. **Private Endpoints**: Internal communication where possible
4. **TLS/SSL**: Encrypted communication for all services

### Data Protection

1. **Encryption at Rest**: All storage encrypted
2. **Encryption in Transit**: TLS 1.2+ for all connections
3. **Audit Logging**: All operations logged to Log Analytics
4. **Backup**: Regular backups of critical VMs and configurations

## Scalability & Performance

### Vertical Scaling

- **VM Size**: Scale up to larger E-series or D-series VMs
- **Storage**: Add additional data disks as needed
- **Memory**: Increase RAM for more/larger nested VMs

### Monitoring & Optimization

- **Performance Metrics**: CPU, memory, disk, network
- **Resource Utilization**: Identify bottlenecks
- **Cost Optimization**: Right-size resources based on usage

## Disaster Recovery

### Backup Strategy

1. **VM Backups**: Azure Backup for host VM
2. **Configuration Exports**: Bicep templates in source control
3. **Data Exports**: Regular exports of nested VM configurations

### Recovery Procedures

1. **Redeploy Infrastructure**: Use Bicep templates
2. **Restore Host VM**: From Azure Backup
3. **Recreate Nested VMs**: From configuration exports
4. **Rejoin Arc**: Re-register with Azure Arc

## Cost Optimization

### Key Cost Drivers

1. **Compute**: Host VM (largest component)
2. **Storage**: Premium SSD disks
3. **Networking**: Data egress charges
4. **Bastion**: If deployed (hourly charge)

### Cost Reduction Strategies

1. **Deallocate VMs**: When not in use
2. **Reserved Instances**: For long-term use
3. **Right-sizing**: Choose appropriate VM sizes
4. **Storage Tiers**: Use Standard SSD where appropriate

## References

- [Azure Local Architecture](https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements)
- [Nested Virtualization](https://learn.microsoft.com/en-us/azure/virtual-machines/nested-virtualization)
- [Azure Arc Overview](https://learn.microsoft.com/en-us/azure/azure-arc/overview)
- [Azure Government Architecture](https://learn.microsoft.com/en-us/azure/azure-government/documentation-government-plan-design)

---

**Document Version**: 1.0  
**Last Updated**: October 2025
