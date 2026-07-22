# 发布目录拷贝（跨 DST mod 项目可复用）
# 使用黑名单机制将项目文件拷贝到 dist/ 文件夹。

function Copy-ToDist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string]$DistPath = 'dist',
        [string[]]$Blacklist = @(
            'dist',
            'tools',
            'temp',
            '.git',
            '.gitignore',
            '.gitattributes',
            '.vscode',
            '.vs',
            '.idea',
            'docs',
            'animSource',
            'imageSource',
            'shaderSource',
            'soundSource',
            'out',
            '.VSCodeCounter',
            'ITEM_DESIGN.md',
            'CHANGELOG.md',
            '*.code-workspace'
        )
    )

    $distFullPath = Join-Path $ProjectRoot $DistPath

    # 清空并重建 dist
    if (Test-Path $distFullPath) {
        Remove-Item -Path $distFullPath -Recurse -Force
        Write-Host "[完成]  已清空现有 dist/ 目录"
    }
    New-Item -Path $distFullPath -ItemType Directory | Out-Null
    Write-Host "[完成]  已创建 dist/ 目录"

    # 获取项目根目录下所有内容
    $items = Get-ChildItem -Path $ProjectRoot -Force | Where-Object {
        $name = $_.Name
        foreach ($pattern in $Blacklist) {
            if ($pattern -match '[\*\?]') {
                if ($name -like $pattern) { return $false }
            }
            else {
                if ($name -eq $pattern) { return $false }
            }
        }
        return $true
    }

    # 逐项拷贝
    $count = 0
    foreach ($item in $items) {
        $source = $item.FullName
        $target = Join-Path $distFullPath $item.Name

        if ($item.PSIsContainer) {
            Copy-Item -Path $source -Destination $target -Recurse -Force
        }
        else {
            Copy-Item -Path $source -Destination $target -Force
        }
        $count++
    }

    Write-Host "[完成]  已拷贝 $count 个项目到 dist/"
}
