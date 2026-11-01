[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository = 'dmcdark/Wand-Enhancer',
    [ValidateRange(2, 1000)]
    [int]$Keep = 2,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$json = gh api --paginate --slurp "repos/$Repository/releases?per_page=100"
if ($LASTEXITCODE -ne 0) {
    throw 'Could not list releases; nothing was deleted.'
}

$releases = @($json | ConvertFrom-Json | ForEach-Object { $_ } | ForEach-Object { $_ })
# Both the tag format and build marker belong to this workflow; official releases are excluded.
$automatic = @($releases | Where-Object {
    -not $_.draft -and $_.tag_name -match '^auto-build-\d{8}T\d{6}Z-\d+-\d+$' -and
    $_.body -match '<!-- auto-build-sha: [0-9a-f]{40} -->' -and
    @($_.assets | Where-Object { $_.name -eq 'WandEnhancer.exe' -and $_.state -eq 'uploaded' -and $_.size -gt 0 }).Count -gt 0
} | Sort-Object published_at -Descending)

foreach ($release in ($automatic | Select-Object -First $Keep)) {
    Write-Host "Keep: $($release.tag_name)"
}

foreach ($release in ($automatic | Select-Object -Skip $Keep)) {
    if (-not $Apply) {
        Write-Host "Would delete release and tag: $($release.tag_name) (use -Apply to delete)"
        continue
    }

    if ($PSCmdlet.ShouldProcess("$Repository/$($release.tag_name)", 'Delete automatic release, assets, and tag')) {
        gh release delete $release.tag_name --repo $Repository --yes --cleanup-tag
        if ($LASTEXITCODE -ne 0) {
            throw "Cleanup failed for $($release.tag_name); stopping further deletions."
        }
    }
}
