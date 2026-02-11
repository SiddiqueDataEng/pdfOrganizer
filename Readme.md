# OrganizeFiles.ps1 - Smart Document Organizer

A powerful PowerShell script that automatically organizes your PDF, ODF (ODT/ODS/ODP), and EPUB documents into neatly structured folders with automatic README generation.

## 📋 Features

- **Multi-format Support**: Organizes PDF, ODT, ODS, ODP, and EPUB files
- **Smart Organization**: Creates folders named after each document and moves files into them
- **Duplicate Handling**: Automatically resolves filename collisions with numeric suffixes
- **README Generation**: Creates beautiful documentation for each organized folder
- **Detailed Logging**: Comprehensive logging of all operations
- **Collision Detection**: Skips already organized files to prevent duplicates
- **Cross-platform**: Works on Windows, macOS, and Linux (with PowerShell Core)

## 🚀 Quick Start

### One-time Run
```powershell
# Navigate to your documents folder
cd C:\Users\YourName\Documents

# Run the organizer
powershell -ExecutionPolicy Bypass -File .\OrganizeFiles.ps1

