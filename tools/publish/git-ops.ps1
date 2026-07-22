# Git 操作（跨 DST mod 项目可复用）
# 暂存文件、提交 release 信息、创建版本 tag。

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
        # 暂存文件
        foreach ($file in $Files) {
            $fullPath = Join-Path $ProjectRoot $file
            if (Test-Path $fullPath) {
                git add $file
                Write-Host "[完成]  git add $file"
            }
            else {
                Write-Warning "[警告]  文件不存在，跳过 git add: $file"
            }
        }

        # 检查是否有暂存的变更
        $staged = git diff --cached --name-only 2>$null
        if (-not $staged) {
            Write-Warning "[跳过]  没有暂存的变更，跳过提交"
            return
        }

        # 提交
        $commitMsg = "release: $Version"
        git commit -m $commitMsg
        if ($LASTEXITCODE -ne 0) {
            throw "git commit 失败（退出码: $LASTEXITCODE）"
        }
        Write-Host "[完成]  git commit -m '$commitMsg'"

        # 检查 tag 是否已存在
        $existingTag = git tag -l $Version 2>$null
        if ($existingTag) {
            Write-Warning "[警告]  Tag '$Version' 已存在，正在删除并重新创建..."
            git tag -d $Version
        }

        # 创建 tag
        git tag $Version
        if ($LASTEXITCODE -ne 0) {
            throw "git tag 失败（退出码: $LASTEXITCODE）"
        }
        Write-Host "[完成]  git tag $Version"
    }
    finally {
        Pop-Location
    }
}
