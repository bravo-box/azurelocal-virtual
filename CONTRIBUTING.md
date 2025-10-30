# Contributing to Azure Local Virtual

Thank you for your interest in contributing to the Azure Local Virtual project! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please be respectful and constructive in all interactions.

## How to Contribute

Contributions can be made in several ways:

1. **Bug Reports**: Report issues you encounter
2. **Feature Requests**: Suggest new features or improvements
3. **Documentation**: Improve or add documentation
4. **Code**: Submit bug fixes or new features
5. **Testing**: Test deployments and provide feedback

## Development Setup

### Prerequisites

1. **Azure Government Subscription**: Required for testing deployments
2. **Development Tools**:
   - Azure CLI (latest version)
   - Bicep CLI (latest version)
   - PowerShell 7.0 or later
   - Git
   - VS Code (recommended)

3. **VS Code Extensions** (recommended):
   - Bicep (ms-azuretools.vscode-bicep)
   - Azure Account (ms-vscode.azure-account)
   - PowerShell (ms-vscode.powershell)

### Local Setup

```bash
# Clone the repository
git clone https://github.com/bravo-box/azurelocal-virtual.git
cd azurelocal-virtual

# Install Bicep
az bicep install

# Verify setup
az bicep version
pwsh --version
```

## Coding Standards

### Bicep Templates

1. **Naming Conventions**:
   - Use camelCase for parameters: `vmName`, `virtualNetworkName`
   - Use descriptive names for resources
   - Use consistent prefixes for related resources

2. **Documentation**:
   - Add `@description()` to all parameters
   - Include comments for complex logic
   - Document allowed values with `@allowed()`

3. **Best Practices**:
   - Use parameters for configurable values
   - Validate input with decorators (`@minValue`, `@maxValue`, etc.)
   - Use modules for reusable components
   - Enable linter and fix all warnings

Example:
```bicep
@description('Name of the virtual machine')
@minLength(1)
@maxLength(64)
param vmName string

@description('Size of the VM')
@allowed([
  'Standard_E32s_v5'
  'Standard_E48s_v5'
])
param vmSize string = 'Standard_E32s_v5'
```

### PowerShell Scripts

1. **Structure**:
   - Use `[CmdletBinding()]` for advanced functions
   - Include comment-based help
   - Use approved verbs (Get-, Set-, New-, etc.)

2. **Parameters**:
   - Use proper parameter attributes
   - Validate input with `[ValidateSet()]`, `[ValidateRange()]`, etc.
   - Use meaningful parameter names

3. **Error Handling**:
   - Use `try/catch` blocks
   - Set `$ErrorActionPreference = 'Stop'` appropriately
   - Provide meaningful error messages

Example:
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER ParameterName
    Description of parameter
.EXAMPLE
    Example usage
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ParameterName
)

$ErrorActionPreference = 'Stop'

try {
    # Code here
}
catch {
    Write-Error "Error: $_"
    exit 1
}
```

### Documentation

1. **Markdown Files**:
   - Use proper heading hierarchy
   - Include code examples
   - Add tables for comparisons
   - Link to related documentation

2. **Comments**:
   - Explain "why", not "what"
   - Update comments when code changes
   - Use clear, concise language

## Testing Guidelines

### Pre-Submission Testing

Before submitting a pull request:

1. **Validate Bicep Templates**:
```bash
az bicep build --file bicep/main.bicep
az bicep build --file bicep/host/host.bicep
az bicep build --file bicep/mgmt/management.bicep
```

2. **Test PowerShell Scripts**:
```powershell
# Syntax validation
$null = [System.Management.Automation.PSParser]::Tokenize(
    (Get-Content .\scripts\Deploy-AzLocalVirtual.ps1 -Raw), 
    [ref]$null
)

# PSScriptAnalyzer (if available)
Invoke-ScriptAnalyzer -Path .\scripts\ -Recurse
```

3. **Test Deployment** (if possible):
```bash
# Deploy to test environment
az deployment group create \
    --resource-group "Test-RG" \
    --template-file bicep/main.bicep \
    --parameters @bicep/main.parameters.gov.json \
    --what-if
```

### What to Test

- [ ] Bicep templates compile without errors
- [ ] Parameter files are valid JSON
- [ ] PowerShell scripts run without syntax errors
- [ ] Documentation renders correctly
- [ ] Links in documentation work
- [ ] Code follows style guidelines

## Pull Request Process

### Before Submitting

1. **Create a Branch**:
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number
```

2. **Make Changes**:
   - Follow coding standards
   - Update documentation
   - Add/update tests if applicable

3. **Commit Changes**:
```bash
git add .
git commit -m "Description of changes"
```

### Commit Message Guidelines

Use clear, descriptive commit messages:

```
Add support for custom VM sizes

- Add new parameter for custom VM sizes
- Update documentation with examples
- Add validation for nested virtualization support
```

Format:
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description (if needed)
- List specific changes

### Submitting the Pull Request

1. **Push to GitHub**:
```bash
git push origin feature/your-feature-name
```

2. **Create Pull Request**:
   - Go to GitHub repository
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR template
   - Add reviewers if known

3. **PR Description Should Include**:
   - Summary of changes
   - Motivation/context
   - Testing performed
   - Related issues (if any)
   - Screenshots (for UI changes)

### PR Review Process

1. **Automated Checks**: Wait for CI/CD to pass
2. **Code Review**: Address reviewer feedback
3. **Updates**: Make requested changes
4. **Approval**: Wait for maintainer approval
5. **Merge**: Maintainer will merge when ready

## Reporting Issues

### Before Creating an Issue

1. **Search Existing Issues**: Check if already reported
2. **Verify the Problem**: Ensure it's reproducible
3. **Gather Information**: Collect relevant details

### Issue Template

When creating an issue, include:

```markdown
**Description**
Brief description of the issue

**Environment**
- OS: [e.g., Windows 11, Ubuntu 22.04]
- Azure CLI version: [e.g., 2.52.0]
- Bicep version: [e.g., 0.22.6]
- PowerShell version: [e.g., 7.3.6]

**Steps to Reproduce**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Error Messages**
```
Paste error messages here
```

**Additional Context**
Any other relevant information
```

## Types of Contributions

### Bug Fixes

- Fix deployment issues
- Correct documentation errors
- Resolve configuration problems
- Address security vulnerabilities

### Features

- Add new Azure Government regions
- Support additional VM sizes
- Integrate new Azure services
- Enhance monitoring capabilities

### Documentation

- Improve clarity
- Add examples
- Fix typos
- Update outdated information
- Translate to other languages

### Testing

- Test in different regions
- Validate with various VM sizes
- Test different configurations
- Report results

## Style Guide

### Bicep

- Use 2 spaces for indentation
- Maximum line length: 120 characters
- Group related resources
- Add blank lines between resources

### PowerShell

- Use 4 spaces for indentation
- Maximum line length: 115 characters
- Use PascalCase for function names
- Use camelCase for variables

### Markdown

- Use ATX-style headers (`#`)
- Maximum line length: 120 characters
- Use fenced code blocks with language
- Add blank line before and after code blocks

## Questions?

If you have questions:

1. Check existing documentation
2. Search closed issues
3. Ask in a new issue with label `question`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes (for significant contributions)
- Project documentation (for major features)

---

Thank you for contributing to Azure Local Virtual!
