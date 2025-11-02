# ============================================================================
# BUILD.PS1 - Build the Stellar Duels Smart Contract
# ============================================================================
# This script compiles the Rust contract to WebAssembly (WASM)
# ============================================================================

Write-Host "🔨 Building Stellar Duels Smart Contract..." -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "Cargo.toml")) {
    Write-Host "❌ Error: Cargo.toml not found. Run this script from the project root." -ForegroundColor Red
    exit 1
}

# Build the contract for WASM target
Write-Host "📦 Compiling contract to WASM..." -ForegroundColor Yellow
stellar contract build

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📄 WASM file location:" -ForegroundColor Cyan
    Write-Host "   target/wasm32-unknown-unknown/release/stellar_duels.wasm"
    Write-Host ""
    Write-Host "📊 File size:" -ForegroundColor Cyan
    $wasmPath = "target/wasm32-unknown-unknown/release/stellar_duels.wasm"
    if (Test-Path $wasmPath) {
        $size = (Get-Item $wasmPath).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        Write-Host "   $sizeKB KB"
    }
    Write-Host ""
    Write-Host "🚀 Next step: Deploy the contract with:" -ForegroundColor Yellow
    Write-Host "   .\scripts\deploy.ps1" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "❌ Build failed. Check the errors above." -ForegroundColor Red
    exit 1
}
