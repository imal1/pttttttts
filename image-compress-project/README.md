# Image Compress Project

A simple and effective batch image compressor for JPG/JPEG/PNG files on Windows.

## Setup

No extra dependency is required. It uses built-in PowerShell + .NET APIs.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File .\compress-images.ps1 `
  -InputFolder "c:\Users\chjcz\Pictures\ptttttts\10.18 婚礼原片" `
  -OutputFolder "c:\Users\chjcz\Pictures\ptttttts\10.18 婚礼原片_压缩" `
  -Quality 78 `
  -MaxSide 2560
```

- `Quality`: JPEG quality (1-100), lower means smaller files.
- `MaxSide`: resize longer side to this value (0 means no resize).
- Source files are never overwritten.
