# Build script for Windows Bun development container
# IMPORTANT: Must use --isolation=process for adequate memory (9.7GB paging file)
# Hyper-V isolation only provides 1.7GB which is insufficient for Zig compilation

param(
    [string]$Tag = "bun-dev:windows-latest"
)

Write-Host "Building Windows Bun development container..." -ForegroundColor Green
Write-Host "Using process isolation for optimal memory allocation" -ForegroundColor Yellow

docker build `
    --isolation=process `
    --memory 16g `
    -f Dockerfile.windows `
    -t $Tag `
    .

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild successful! Created image: $Tag" -ForegroundColor Green
    Write-Host "`nTo run the container:" -ForegroundColor Cyan
    Write-Host "  docker run --isolation=process --memory 16g -it $Tag" -ForegroundColor White
    Write-Host "`nTo run with mounted source:" -ForegroundColor Cyan
    Write-Host "  docker run --isolation=process --memory 16g -v `${PWD}:C:\workspace\cwd -it $Tag" -ForegroundColor White
} else {
    Write-Host "`nBuild failed!" -ForegroundColor Red
    exit 1
}
