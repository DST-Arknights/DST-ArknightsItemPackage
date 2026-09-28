# Git 操作（跨 DST mod 项目可复用）
# 暂存文件、提交 release 信息、创建版本 tag。

function Invoke-GitChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    $output = & git @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$ErrorMessage（git $($Arguments -join ' ')，退出码: $exitCode）"
    }

    return $output
}

function Test-GitRepositoryReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Push-Location $ProjectRoot
    try {
        $gitDirOutput = @(Invoke-GitChecked -Arguments @('rev-parse', '--git-dir') -ErrorMessage '无法读取 Git 仓库信息')
        $gitDir = $gitDirOutput[-1].Trim()
        if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
            $gitDir = Join-Path $ProjectRoot $gitDir
        }

        $indexLock = Join-Path $gitDir 'index.lock'
        if (Test-Path -LiteralPath $indexLock) {
            throw "检测到 Git 锁文件: $indexLock`n请先确认没有其他 Git 进程正在运行；若为崩溃遗留锁，请手动删除后重新发布。"
        }

        Invoke-GitChecked -Arguments @('status', '--porcelain=v1') -ErrorMessage 'Git 仓库状态检查失败' | Out-Null
        Write-Host "[就绪]  Git 仓库可写"
    }
    finally {
        Pop-Location
    }
}

function Publish-GitCommit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string[]]$Files
    )

    Push-Location $ProjectRoot
    try {
        # 暂存文件。PowerShell 5.1 的 $ErrorActionPreference 不会把原生命令非 0 退出码变成异常，
        # 因此所有 Git 命令都必须显式检查退出码，避免部分文件暂存失败后仍继续提交/打 tag。
        foreach ($file in $Files) {
            $fullPath = Join-Path $ProjectRoot $file
            if (Test-Path $fullPath) {
                Invoke-GitChecked -Arguments @('add', '--', $file) -ErrorMessage "git add 失败: $file" | Out-Null
                Write-Host "[完成]  git add $file"
            }
            else {
                Write-Warning "[警告]  文件不存在，跳过 git add: $file"
            }
        }

        # 检查是否有暂存的变更
        $staged = @(Invoke-GitChecked -Arguments @('diff', '--cached', '--name-only') -ErrorMessage '读取暂存区失败')
        if ($staged.Count -eq 0) {
            throw "没有暂存的发布变更，终止提交与打 tag，避免产生假成功的发布结果。"
        }

        # 提交
        $commitMsg = "release: $Version"
        Invoke-GitChecked -Arguments @('commit', '-m', $commitMsg) -ErrorMessage 'git commit 失败'
        Write-Host "[完成]  git commit -m '$commitMsg'"

        # 检查 tag 是否已存在
        $existingTag = @(Invoke-GitChecked -Arguments @('tag', '-l', $Version) -ErrorMessage '读取 Git tag 失败')
        if ($existingTag.Count -gt 0) {
            Write-Warning "[警告]  Tag '$Version' 已存在，正在删除并重新创建..."
            Invoke-GitChecked -Arguments @('tag', '-d', $Version) -ErrorMessage "删除 Git tag '$Version' 失败" | Out-Null
        }

        # 创建 tag
        Invoke-GitChecked -Arguments @('tag', $Version) -ErrorMessage "创建 Git tag '$Version' 失败" | Out-Null
        Write-Host "[完成]  git tag $Version"
    }
    finally {
        Pop-Location
    }
}
