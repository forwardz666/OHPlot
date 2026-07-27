# Generate an explicit GSL source list (sources.cmake) from each module's
# Makefile.am *_la_SOURCES, mirroring the official autotools build.  The
# previous GLOB-based CMakeLists compiled #include-only template fragments
# (fft/c_init.c etc.) which cannot build standalone.
param(
    [string]$GslRoot = 'C:\Users\Forwardz\scidavis-build\deps\gsl\gsl-2.8'
)

$modules = @(
    'blas','block','bspline','bst','cdf','cheb','combination','complex',
    'deriv','dht','diff','eigen','err','fft','filter','fit','histogram',
    'ieee-utils','integration','interpolation','linalg','matrix','min',
    'monte','movstat','multifit','multifit_nlinear','multilarge',
    'multilarge_nlinear','multimin','multiroots','ode-initval2',
    'permutation','poly','randist','rng','roots','rstat','siman','sort',
    'spblas','splinalg','spmatrix','specfunc','statistics','sum','sys',
    'vector','wavelet','utils','version.c'
)

$out = New-Object System.Collections.Generic.List[string]
foreach ($mod in $modules) {
    if ($mod -eq 'version.c') { $out.Add('version.c'); continue }
    $am = Join-Path $GslRoot "$mod\Makefile.am"
    if (-not (Test-Path $am)) { Write-Warning "missing $am"; continue }
    $text = Get-Content $am -Raw
    # join continuation lines
    $text = $text -replace "\\\r?\n", ' '
    foreach ($line in ($text -split "\r?\n")) {
        if ($line -match '^[A-Za-z0-9_]+_la_SOURCES\s*=\s*(.+)$') {
            foreach ($f in ($Matches[1] -split '\s+')) {
                if ($f -match '\.c$') { $out.Add("$mod/$f") }
            }
        }
    }
}

$dst = Join-Path $GslRoot 'sources.cmake'
$lines = @('set(GSL_SRCS')
foreach ($f in $out) { $lines += "  `${GSL_ROOT}/$f" }
$lines += ')'
Set-Content -Path $dst -Value ($lines -join "`n") -NoNewline
Write-Host "wrote $dst with $($out.Count) sources"
