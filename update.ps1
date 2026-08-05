$RepoName = "velvet-static"
$RepoUrl = "https://github.com/SteveP999/velvet-static.git"
$LogPath = Join-Path $PSScriptRoot "update-log.txt"

function Write-Both($Text) {
    Write-Host $Text
    Add-Content -Path $LogPath -Value $Text
}

function Check-Git($Step) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE"
    }
}

Set-Content -Path $LogPath -Value @(
"==========================================",
"HTR Update - $RepoName",
"==========================================",
"Running from: $PSScriptRoot",
""
)

try {
    Set-Location $PSScriptRoot

    Write-Both "Checking Git..."
    git --version 2>&1 | Tee-Object -FilePath $LogPath -Append
    Check-Git "Git check"

    if (-not (Test-Path ".git")) {
        Write-Both "No .git folder found. Initializing repo..."
        git init 2>&1 | Tee-Object -FilePath $LogPath -Append
        Check-Git "git init"

        git branch -M main 2>&1 | Tee-Object -FilePath $LogPath -Append
        Check-Git "git branch"

        git remote add origin $RepoUrl 2>&1 | Tee-Object -FilePath $LogPath -Append
        Check-Git "git remote add"
    } else {
        Write-Both "Existing .git folder found."

        git branch -M main 2>&1 | Tee-Object -FilePath $LogPath -Append
        Check-Git "git branch"

        $remote = ""
        try { $remote = git remote get-url origin } catch { $remote = "" }

        if ([string]::IsNullOrWhiteSpace($remote)) {
            Write-Both "No origin remote found. Adding origin..."
            git remote add origin $RepoUrl 2>&1 | Tee-Object -FilePath $LogPath -Append
            Check-Git "git remote add"
        } elseif ($remote.Trim() -ne $RepoUrl) {
            Write-Both "Origin remote is wrong. Replacing it."
            git remote set-url origin $RepoUrl 2>&1 | Tee-Object -FilePath $LogPath -Append
            Check-Git "git remote set-url"
        }
    }

    Write-Both ""
    Write-Both "Fetching remote..."
    git fetch origin main 2>&1 | Tee-Object -FilePath $LogPath -Append
    Check-Git "git fetch"

    Write-Both ""
    Write-Both "Syncing remote before commit..."
    # Remove locally-created CNAME if GitHub already has one to avoid merge conflict
    if (Test-Path "CNAME") {{ Remove-Item "CNAME" -Force }}
    git pull origin main --allow-unrelated-histories --no-rebase -X ours 2>&1 | Tee-Object -FilePath $LogPath -Append
    Check-Git "git pull"

    Write-Both ""
    Write-Both "Making update-log.txt local-only going forward..."
    Set-Content -Path ".gitignore" -Value "update-log.txt"

    Write-Both ""
    Write-Both "Staging files..."
    git add -A 2>&1 | Tee-Object -FilePath $LogPath -Append
    Check-Git "git add"

    Write-Both ""
    Write-Both "Git status:"
    git status 2>&1 | Tee-Object -FilePath $LogPath -Append

    $changes = git status --porcelain
    if ($changes) {
        Write-Both ""
        $msg = Read-Host "Commit message (Enter = update artist site)"
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "update artist site" }

        Write-Both "Committing..."
        git commit -m $msg 2>&1 | Tee-Object -FilePath $LogPath -Append
        Check-Git "git commit"
    } else {
        Write-Both "No changes to commit."
    }

    Write-Both ""
    Write-Both "Pushing to GitHub..."
    git push -u origin main 2>&1 | Tee-Object -FilePath $LogPath -Append
    Check-Git "git push"

    Write-Both ""
    Write-Both "SUCCESS: $RepoName pushed to GitHub."
}
catch {
    Write-Both ""
    Write-Both "ERROR:"
    Write-Both $_.Exception.Message
    Write-Both ""
    Write-Both "Push/build did NOT complete successfully."
    Write-Both "See update-log.txt in this folder."
}
finally {
    Write-Host ""
    Write-Host "Returning to HTR-MENU..."
}
